<?php

namespace Tests\Postgres;

use App\Models\Catalog;
use App\Models\Unit;
use App\Models\User;
use App\Services\RegisterDocument;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class ConcurrencyTest extends TestCase
{
    use DatabaseMigrations;

    public function test_concurrent_same_key_returns_one_record_and_one_movement(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            $this->markTestSkipped('Requiere PostgreSQL.');
        }
        $this->assertSame('correspondencia_test', DB::connection()->getDatabaseName());
        $this->seed();
        $unit = Unit::first();
        $actor = User::factory()->create(['role' => 'recepcion', 'unit_id' => $unit->id, 'enabled' => true]);
        $input = ['remitente' => 'Prueba concurrente', 'asunto' => 'Solicitud repetida', 'fecha' => '2026-10-23',
            'tipo_id' => Catalog::where('kind', 'tipo')->first()->id, 'prioridad_id' => Catalog::where('kind', 'prioridad')->first()->id,
            'unidad_id' => $unit->id, 'request_key' => (string) Str::uuid()];
        $results = $this->runWorkers('RegisterWorker.php', [[$actor->id, $input], [$actor->id, $input]]);
        $this->assertSame($results[0]['id'], $results[1]['id']);
        $this->assertSame(1, count(array_filter($results, fn ($r) => $r['created'])));
        foreach (['documents', 'route_sheets', 'movements', 'requests', 'audits'] as $table) {
            $this->assertDatabaseCount($table, 1);
        }
    }

    public function test_concurrent_derivation_and_reception_each_create_one_movement(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            $this->markTestSkipped('Requiere PostgreSQL.');
        }
        $this->assertSame('correspondencia_test', DB::connection()->getDatabaseName());
        $this->seed();

        $origin = Unit::firstOrFail();
        $destination = Unit::create([
            'institution_id' => $origin->institution_id,
            'code' => 'JURIDICA',
            'name' => 'Asesoría Jurídica',
            'enabled' => true,
        ]);
        $actor = User::factory()->create(['role' => 'recepcion', 'unit_id' => $origin->id, 'enabled' => true]);
        $recipients = User::factory()->count(2)->create([
            'role' => 'funcionario', 'unit_id' => $destination->id, 'enabled' => true,
        ]);
        [$document] = app(RegisterDocument::class)->execute($actor, [
            'remitente' => 'Prueba concurrente', 'asunto' => 'Hoja de ruta', 'fecha' => '2026-11-10',
            'tipo_id' => Catalog::where('kind', 'tipo')->firstOrFail()->id,
            'prioridad_id' => Catalog::where('kind', 'prioridad')->firstOrFail()->id,
            'unidad_id' => $origin->id, 'request_key' => (string) Str::uuid(),
        ]);
        $sheet = $document->sheet;

        $derivations = $this->runWorkers('RouteSheetWorker.php', array_map(
            fn () => [$actor->id, [
                'operation' => 'derive', 'sheet_id' => $sheet->id,
                'data' => ['version' => 1, 'request_key' => (string) Str::uuid(),
                    'motivo' => 'Revisión jurídica', 'destino_unidad_id' => $destination->id],
            ]],
            [1, 2],
        ));

        $this->assertEqualsCanonicalizing([201, 409], array_column($derivations, 'status'));
        $this->assertDatabaseHas('route_sheets', [
            'id' => $sheet->id, 'state' => 'PENDIENTE_RECEPCION', 'version' => 2,
            'responsible_id' => $actor->id, 'current_unit_id' => $origin->id, 'pending_unit_id' => $destination->id,
        ]);

        $receipts = $this->runWorkers('RouteSheetWorker.php', $recipients->map(
            fn (User $recipient) => [$recipient->id, [
                'operation' => 'receive', 'sheet_id' => $sheet->id,
                'data' => ['version' => 2, 'request_key' => (string) Str::uuid()],
            ]],
        )->all());

        $this->assertEqualsCanonicalizing([201, 404], array_column($receipts, 'status'));
        $winner = collect($receipts)->firstWhere('status', 201);
        $this->assertDatabaseHas('route_sheets', [
            'id' => $sheet->id, 'state' => 'RECIBIDA', 'version' => 3,
            'responsible_id' => $winner['responsible_id'],
            'current_unit_id' => $destination->id, 'pending_unit_id' => null,
        ]);
        $this->assertSame(
            ['REGISTRO', 'DERIVACION', 'RECEPCION'],
            $sheet->movements()->pluck('action')->all(),
        );
        $this->assertDatabaseCount('requests', 3);
    }

    private function runWorkers(string $worker, array $attempts): array
    {
        $gate = sys_get_temp_dir().'/correspondencia-race-'.Str::uuid();
        mkdir($gate);
        $workers = [];
        try {
            foreach ($attempts as [$actorId, $data]) {
                $process = proc_open([PHP_BINARY, base_path('tests/Support/'.$worker), (string) $actorId, base64_encode(json_encode($data, JSON_THROW_ON_ERROR)), $gate],
                    [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, base_path());
                $this->assertIsResource($process);
                fclose($pipes[0]);
                $workers[] = [$process, $pipes];
            }
            $deadline = microtime(true) + 12;
            while (count(glob($gate.'/ready-*')) < 2 && microtime(true) < $deadline) {
                usleep(10000);
            }
            $this->assertCount(2, glob($gate.'/ready-*'), 'Ambos procesos deben estar listos antes de competir.');
            file_put_contents($gate.'/go', 'go');
            $results = [];
            foreach ($workers as [$process,$pipes]) {
                $stdout = stream_get_contents($pipes[1]);
                $stderr = stream_get_contents($pipes[2]);
                fclose($pipes[1]);
                fclose($pipes[2]);
                $this->assertSame(0, proc_close($process), $stderr);
                $results[] = json_decode($stdout, true, 512, JSON_THROW_ON_ERROR);
            }
            $workers = [];

            return $results;
        } finally {
            foreach ($workers as [$process,$pipes]) {
                if (is_resource($process)) {
                    proc_terminate($process);
                    proc_close($process);
                }
            }
            foreach (glob($gate.'/*') as $file) {
                unlink($file);
            } rmdir($gate);
        }
    }
}
