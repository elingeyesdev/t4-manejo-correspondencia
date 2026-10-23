<?php

namespace Tests\Postgres;

use App\Models\Catalog;
use App\Models\Unit;
use App\Models\User;
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
        $gate = sys_get_temp_dir().'/correspondencia-race-'.Str::uuid();
        mkdir($gate);
        $workers = [];
        try {
            for ($i = 0; $i < 2; $i++) {
                $process = proc_open([PHP_BINARY, base_path('tests/Support/RegisterWorker.php'), (string) $actor->id, base64_encode(json_encode($input)), $gate],
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
            $this->assertSame($results[0]['id'], $results[1]['id']);
            $this->assertSame(1, count(array_filter($results, fn ($r) => $r['created'])));
            foreach (['documents', 'route_sheets', 'movements', 'requests', 'audits'] as $table) {
                $this->assertDatabaseCount($table, 1);
            }
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
