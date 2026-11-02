<?php

namespace Tests\Feature;

use App\Models\Catalog;
use App\Models\Document;
use App\Models\Unit;
use App\Models\User;
use App\Services\RegisterDocument;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DocumentHistoryTest extends TestCase
{
    use RefreshDatabase;

    private User $operator;

    private Document $document;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed();

        $unit = Unit::firstOrFail();

        $this->operator = User::factory()->create([
            'role' => 'recepcion',
            'unit_id' => $unit->id,
            'enabled' => true,
        ]);

        [$this->document] = app(RegisterDocument::class)->execute(
            $this->operator,
            [
                'remitente' => 'Institución de prueba',
                'asunto' => 'Consulta del historial',
                'fecha' => now()->toDateString(),
                'tipo_id' => Catalog::where('kind', 'tipo')->firstOrFail()->id,
                'prioridad_id' => Catalog::where('kind', 'prioridad')->firstOrFail()->id,
                'unidad_id' => $unit->id,
                'request_key' => (string) Str::uuid(),
            ]
        );
    }

    private function url(): string
    {
        return '/api/documentos/'.$this->document->id.'/historial';
    }

    private function snapshot(): array
    {
        $snapshot = [];

        foreach (['documents', 'route_sheets', 'movements', 'audits', 'requests'] as $table) {
            $snapshot[$table] = DB::table($table)
                ->get()
                ->map(fn ($row) => (array) $row)
                ->all();
        }

        return $snapshot;
    }

    public function test_guest_cannot_read_history(): void
    {
        $this->getJson($this->url())->assertUnauthorized();
    }

    public function test_returns_real_registration_without_changing_records(): void
    {
        Sanctum::actingAs($this->operator);

        $before = $this->snapshot();
        $sheet = $this->document->sheet;
        $movement = $sheet->movements()->firstOrFail();

        $response = $this->getJson($this->url())
            ->assertOk()
            ->assertJsonPath('documento_id', $this->document->id)
            ->assertJsonPath('hoja.id', $sheet->id)
            ->assertJsonPath('hoja.estado', 'REGISTRADA')
            ->assertJsonPath('total', 1)
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $movement->id)
            ->assertJsonPath('data.0.accion', 'REGISTRO')
            ->assertJsonPath('data.0.actor.id', $this->operator->id)
            ->assertJsonPath('data.0.actor.nombre', $this->operator->name)
            ->assertJsonPath('data.0.unidad_origen.id', $this->operator->unit_id)
            ->assertJsonPath('data.0.unidad_destino.nombre', $this->operator->unit->name)
            ->assertJsonPath('data.0.fecha', $movement->occurred_at->toISOString())
            ->assertJsonPath('data.0.estado_resultante', 'REGISTRADA')
            ->assertJsonMissingPath('data.0.actor.password')
            ->assertJsonMissingPath('data.0.actor.email');

        $this->assertStringContainsString(
            'no-store',
            $response->headers->get('Cache-Control')
        );

        $this->assertSame($before, $this->snapshot());
    }

    public function test_official_can_read_history_from_own_unit(): void
    {
        $official = User::factory()->create([
            'role' => 'funcionario',
            'unit_id' => $this->operator->unit_id,
            'enabled' => true,
        ]);

        Sanctum::actingAs($official);

        $this->getJson($this->url())
            ->assertOk()
            ->assertJsonPath('total', 1);
    }

    public function test_user_from_another_unit_cannot_read_history(): void
    {
        $otherUnit = Unit::create([
            'institution_id' => $this->operator->unit->institution_id,
            'code' => 'OTRA-HIST',
            'name' => 'Otra unidad de prueba',
            'enabled' => true,
        ]);

        $otherUser = User::factory()->create([
            'role' => 'funcionario',
            'unit_id' => $otherUnit->id,
            'enabled' => true,
        ]);

        Sanctum::actingAs($otherUser);

        $this->getJson($this->url())->assertNotFound();
    }

    public function test_web_uses_same_history_as_api_without_changes(): void
    {
        Sanctum::actingAs($this->operator);

        $before = $this->snapshot();

        $history = $this->getJson($this->url())
            ->assertOk()
            ->json();

        $this->actingAs($this->operator, 'web')
            ->get('/documentos/'.$this->document->id)
            ->assertOk()
            ->assertViewIs('documents.show')
            ->assertViewHas('history', fn (array $value) => $value === $history)
            ->assertSee('document-detail');

        $this->assertSame($before, $this->snapshot());
    }

    public function test_document_without_movements_returns_empty_history(): void
    {
        Sanctum::actingAs($this->operator);

        // Solo elimina datos de la base aislada de esta prueba.
        $this->document->sheet->movements()->delete();

        $this->getJson($this->url())
            ->assertOk()
            ->assertJsonPath('documento_id', $this->document->id)
            ->assertJsonPath('total', 0)
            ->assertJsonPath('data', []);

        $this->actingAs($this->operator, 'web')
            ->get('/documentos/'.$this->document->id)
            ->assertOk()
            ->assertViewHas('history', fn (array $value) => $value['data'] === []);
    }

    public function test_missing_or_malformed_document_is_not_found(): void
    {
        Sanctum::actingAs($this->operator);

        $this->getJson(
            '/api/documentos/'.Str::uuid().'/historial'
        )->assertNotFound();

        $this->getJson(
            '/api/documentos/identificador-invalido/historial'
        )->assertNotFound();
    }

    public function test_disabled_account_cannot_read_history(): void
    {
        $this->operator->update(['enabled' => false]);

        Sanctum::actingAs($this->operator->fresh());

        $this->getJson($this->url())->assertForbidden();
    }

    public function test_disabled_unit_cannot_read_history(): void
    {
        $this->operator->unit->update(['enabled' => false]);

        Sanctum::actingAs($this->operator->fresh());

        $this->getJson($this->url())->assertForbidden();
    }

    public function test_web_requires_authentication_and_document_access(): void
    {
        $webUrl = '/documentos/'.$this->document->id;

        $this->get($webUrl)->assertRedirect('/acceso');

        $otherUnit = Unit::create([
            'institution_id' => $this->operator->unit->institution_id,
            'code' => 'WEB-HIST',
            'name' => 'Otra unidad para consulta web',
            'enabled' => true,
        ]);

        $otherUser = User::factory()->create([
            'role' => 'funcionario',
            'unit_id' => $otherUnit->id,
            'enabled' => true,
        ]);

        $this->actingAs($otherUser, 'web')
            ->get($webUrl)
            ->assertNotFound();
    }

    public function test_history_is_ordered_by_date_then_id(): void
    {
        Sanctum::actingAs($this->operator);

        $initial = $this->document->sheet->movements()->firstOrFail();

        $initial->update([
            'occurred_at' => '2026-11-02 10:00:00',
        ]);

        $firstId = '00000000-0000-4000-8000-000000000001';
        $secondId = '00000000-0000-4000-8000-000000000002';

        // Movimientos sintéticos únicamente en la base aislada de pruebas.
        // Se insertan en orden inverso para comprobar el desempate.
        foreach ([$secondId, $firstId] as $id) {
            $movement = $initial->replicate();
            $movement->id = $id;
            $movement->occurred_at = '2026-11-02 11:00:00';
            $movement->save();
        }

        $before = $this->snapshot();
        $expectedIds = [$initial->id, $firstId, $secondId];

        $response = $this->getJson($this->url())
            ->assertOk()
            ->assertJsonPath('total', 3);

        $this->assertSame(
            $expectedIds,
            array_column($response->json('data'), 'id')
        );

        $this->actingAs($this->operator, 'web')
            ->get('/documentos/'.$this->document->id)
            ->assertOk()
            ->assertViewHas(
                'history',
                fn (array $history) => array_column($history['data'], 'id') === $expectedIds
            );

        $this->assertSame($before, $this->snapshot());
    }

    public function test_web_passes_unit_names_to_the_component(): void
    {
        $response = $this->actingAs($this->operator, 'web')
            ->get('/documentos/'.$this->document->id)
            ->assertOk();

        $this->assertSame(
            1,
            preg_match(
                '/id="document-detail"[^>]*data-props="([^"]*)"/',
                $response->getContent(),
                $matches
            )
        );

        $props = json_decode(
            html_entity_decode($matches[1], ENT_QUOTES, 'UTF-8'),
            true,
            512,
            JSON_THROW_ON_ERROR
        );

        $unitName = $this->operator->unit->name;

        $this->assertSame($unitName, $props['movements'][0]['originUnit']);
        $this->assertSame($unitName, $props['movements'][0]['destinationUnit']);
        $this->assertSame('REGISTRO', $props['movements'][0]['action']);
        $this->assertSame('—', $props['movements'][0]['reason']);
    }
}
