<?php

namespace Tests\Feature;

use App\Models\Catalog;
use App\Models\Document;
use App\Models\Unit;
use App\Models\User;
use App\Services\RegisterDocument;
use App\Services\RouteSheetQr;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RouteSheetQrTest extends TestCase
{
    use RefreshDatabase;

    private User $operator;

    private Document $document;

    private string $reference;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed();

        $this->operator = User::factory()->create([
            'role' => 'recepcion',
            'unit_id' => Unit::firstOrFail()->id,
            'enabled' => true,
        ]);

        [$this->document] = app(RegisterDocument::class)->execute(
            $this->operator,
            [
                'remitente' => 'Prueba QR',
                'asunto' => 'Consulta de hoja de ruta',
                'fecha' => '2026-11-02',
                'tipo_id' => Catalog::where('kind', 'tipo')->firstOrFail()->id,
                'prioridad_id' => Catalog::where('kind', 'prioridad')->firstOrFail()->id,
                'unidad_id' => $this->operator->unit_id,
                'request_key' => (string) Str::uuid(),
            ]
        );

        $this->reference = $this->document->sheet->id;
    }

    private function apiUrl(): string
    {
        return '/api/hojas/'.$this->reference;
    }

    public function test_reference_does_not_grant_guest_access(): void
    {
        $this->getJson($this->apiUrl())->assertUnauthorized();
        $this->postJson($this->apiUrl().'/recepciones')
            ->assertUnauthorized()->assertJsonPath('codigo', 'SESION_REQUERIDA');

        $this->get('/hojas/'.$this->reference)
            ->assertRedirect(route('login'));
    }

    public function test_consultation_returns_correct_document_without_changes(): void
    {
        $before = $this->document->sheet->fresh()->getAttributes();

        $counts = [];
        foreach (['movements', 'audits', 'requests'] as $table) {
            $counts[$table] = DB::table($table)->count();
        }

        Sanctum::actingAs($this->operator);

        $this->getJson($this->apiUrl())
            ->assertOk()
            ->assertJsonPath('id', $this->document->id)
            ->assertJsonPath('hoja.id', $this->reference)
            ->assertJsonPath('estado', 'REGISTRADA');

        $this->actingAs($this->operator)
            ->get('/hojas/'.$this->reference)
            ->assertRedirect(route('documents.show', $this->document->id));

        $this->assertSame(
            $before,
            $this->document->sheet->fresh()->getAttributes()
        );

        foreach ($counts as $table => $count) {
            $this->assertDatabaseCount($table, $count);
        }
    }

    public function test_other_unit_cannot_consult_the_reference(): void
    {
        $unit = Unit::create([
            'institution_id' => $this->operator->unit->institution_id,
            'code' => 'OTRA',
            'name' => 'Otra unidad',
            'enabled' => true,
        ]);

        $other = User::factory()->create([
            'role' => 'recepcion',
            'unit_id' => $unit->id,
            'enabled' => true,
        ]);

        Sanctum::actingAs($other);

        $this->getJson($this->apiUrl())->assertNotFound();

        $this->actingAs($other)
            ->get('/hojas/'.$this->reference)
            ->assertNotFound();
    }

    public function test_official_can_consult_own_unit(): void
    {
        $official = User::factory()->create([
            'role' => 'funcionario',
            'unit_id' => $this->operator->unit_id,
            'enabled' => true,
        ]);

        Sanctum::actingAs($official);

        $this->getJson($this->apiUrl())
            ->assertOk()
            ->assertJsonPath('hoja.id', $this->reference);
    }

    public function test_destination_officials_can_consult_only_while_pending_or_responsible(): void
    {
        $destination = Unit::create([
            'institution_id' => $this->operator->unit->institution_id,
            'code' => 'JURIDICA',
            'name' => 'Asesoría Jurídica',
            'enabled' => true,
        ]);

        [$recipient, $colleague] = User::factory()->count(2)->create([
            'role' => 'funcionario',
            'unit_id' => $destination->id,
            'enabled' => true,
        ])->all();

        Sanctum::actingAs($this->operator);
        $this->getJson($this->apiUrl().'/destinos')->assertOk()
            ->assertJsonFragment(['id' => $destination->id, 'nombre' => $destination->name]);

        $data = [
            'destino_unidad_id' => $destination->id,
            'motivo' => 'Revisión jurídica',
            'version' => 1,
            'request_key' => (string) Str::uuid(),
        ];

        $url = $this->apiUrl().'/derivaciones';
        $this->postJson($url, array_replace($data, ['motivo' => str_repeat('á', 501)]))
            ->assertUnprocessable()
            ->assertJsonPath('codigo', 'VALIDACION_FALLIDA')
            ->assertJsonValidationErrors('motivo');

        $first = $this->postJson($url, $data)->assertCreated()
            ->assertJsonPath('movimiento.accion', 'DERIVACION')->json();
        $this->postJson($url, $data)->assertOk()->assertExactJson($first);
        $this->postJson($url, array_replace($data, ['motivo' => 'Motivo distinto']))
            ->assertConflict()->assertJsonPath('codigo', 'CLAVE_REUTILIZADA');
        $this->assertDatabaseHas('route_sheets', [
            'id' => $this->reference,
            'state' => 'PENDIENTE_RECEPCION',
            'version' => 2,
            'responsible_id' => $this->operator->id,
            'current_unit_id' => $this->operator->unit_id,
            'pending_unit_id' => $destination->id,
        ]);
        $this->assertSame(1, $this->document->sheet->movements()->where('action', 'DERIVACION')->count());

        Sanctum::actingAs($recipient);
        $this->getJson($this->apiUrl())
            ->assertOk()
            ->assertJsonPath('estado', 'PENDIENTE_RECEPCION')
            ->assertJsonPath('hoja.responsable_id', $this->operator->id)
            ->assertJsonPath('hoja.responsable.nombre', $this->operator->name)
            ->assertJsonPath('hoja.unidad_vigente.id', $this->operator->unit_id)
            ->assertJsonPath('acciones_permitidas', ['recibir'])
            ->assertJsonPath('movimientos.0.action', 'REGISTRO')
            ->assertJsonPath('movimientos.1.action', 'DERIVACION');

        $reception = [
            'version' => 2,
            'request_key' => (string) Str::uuid(),
        ];

        $url = $this->apiUrl().'/recepciones';
        Sanctum::actingAs($this->operator);
        $this->postJson($url, $reception)->assertForbidden()->assertJsonPath('codigo', 'ACCION_NO_PERMITIDA');

        Sanctum::actingAs($recipient);
        $received = $this->postJson($url, $reception)->assertCreated()
            ->assertJsonPath('movimiento.accion', 'RECEPCION')->json();
        $this->postJson($url, $reception)->assertOk()->assertExactJson($received);
        $this->postJson($url, array_replace($reception, ['request_key' => (string) Str::uuid()]))
            ->assertConflict()->assertJsonPath('codigo', 'VERSION_DESACTUALIZADA');
        $this->assertDatabaseHas('route_sheets', [
            'id' => $this->reference,
            'state' => 'RECIBIDA',
            'responsible_id' => $recipient->id,
            'current_unit_id' => $destination->id,
            'pending_unit_id' => null,
            'version' => 3,
        ]);
        $this->assertSame(1, $this->document->sheet->movements()->where('action', 'RECEPCION')->count());

        $this->getJson($this->apiUrl())->assertOk();

        Sanctum::actingAs($colleague);
        $this->getJson($this->apiUrl())->assertNotFound();
        $this->postJson($url, $reception)->assertNotFound()->assertJsonPath('codigo', 'RECURSO_NO_DISPONIBLE');
    }

    public function test_web_can_derive_and_confirm_from_document_detail(): void
    {
        $destination = Unit::create([
            'institution_id' => $this->operator->unit->institution_id,
            'code' => 'JURIDICA',
            'name' => 'Asesoría Jurídica',
            'enabled' => true,
        ]);
        $recipient = User::factory()->create([
            'role' => 'funcionario',
            'unit_id' => $destination->id,
            'enabled' => true,
        ]);

        $detail = route('documents.show', $this->document->id);
        $this->actingAs($this->operator)->get($detail)
            ->assertOk()->assertSee('route-derive')->assertDontSee('route-receive');

        $this->post(route('route-sheets.derive', $this->reference), [
            'destino_unidad_id' => $destination->id,
            'motivo' => 'Revisión jurídica',
            'version' => 1,
            'request_key' => (string) Str::uuid(),
        ])->assertRedirect($detail)->assertSessionHas('status', 'Hoja derivada.');

        $this->actingAs($recipient)->get($detail)
            ->assertOk()->assertSee('route-receive')->assertDontSee('route-derive');

        $this->post(route('route-sheets.receive', $this->reference), [
            'version' => 2,
            'request_key' => (string) Str::uuid(),
        ])->assertRedirect($detail)->assertSessionHas('status', 'Recepción confirmada.');

        $this->get($detail)->assertOk()->assertViewHas('payload', fn (array $payload) => $payload['estado'] === 'RECIBIDA' && $payload['hoja']['unidad_vigente']['nombre'] === $destination->name);
    }

    public function test_missing_or_malformed_reference_is_rejected(): void
    {
        Sanctum::actingAs($this->operator);

        foreach ([(string) Str::uuid(), 'referencia-invalida'] as $reference) {
            $this->getJson('/api/hojas/'.$reference)->assertNotFound();

            $this->actingAs($this->operator)
                ->get('/hojas/'.$reference)
                ->assertNotFound();
        }
    }

    public function test_disabled_account_cannot_consult(): void
    {
        $this->operator->update(['enabled' => false]);

        Sanctum::actingAs($this->operator);

        $this->getJson($this->apiUrl())->assertForbidden();
    }

    public function test_qr_content_is_the_sheet_consultation_url(): void
    {
        $service = app(RouteSheetQr::class);
        $sheet = $this->document->sheet;

        $this->assertSame(
            route('route-sheets.show', ['reference' => $sheet->id]),
            $service->content($sheet)
        );

        $this->assertNull(
            parse_url($service->content($sheet), PHP_URL_QUERY)
        );
    }

    public function test_authorized_user_receives_svg_without_changing_sheet(): void
    {
        $before = $this->document->sheet->fresh()->getAttributes();
        $movements = DB::table('movements')->count();

        Sanctum::actingAs($this->operator);

        $response = $this->getJson($this->apiUrl().'/qr.svg')
            ->assertOk()
            ->assertHeader('Content-Type', 'image/svg+xml')
            ->assertHeader('X-Content-Type-Options', 'nosniff');

        $svg = new \DOMDocument;

        $this->assertTrue(
            $svg->loadXML($response->getContent(), LIBXML_NONET)
        );

        $this->assertSame('svg', $svg->documentElement->localName);
        $this->assertSame(
            'http://www.w3.org/2000/svg',
            $svg->documentElement->namespaceURI
        );

        $this->assertGreaterThan(
            0,
            $svg->getElementsByTagName('path')->length
                + $svg->getElementsByTagName('rect')->length
        );

        $this->actingAs($this->operator)
            ->get('/hojas/'.$this->reference.'/qr.svg')
            ->assertOk()
            ->assertHeader('Content-Type', 'image/svg+xml');

        $this->assertSame(
            $before,
            $this->document->sheet->fresh()->getAttributes()
        );

        $this->assertDatabaseCount('movements', $movements);
    }

    public function test_qr_image_requires_authentication(): void
    {
        $this->getJson($this->apiUrl().'/qr.svg')
            ->assertUnauthorized();

        $this->get('/hojas/'.$this->reference.'/qr.svg')
            ->assertRedirect(route('login'));
    }

    public function test_other_unit_cannot_generate_qr(): void
    {
        $unit = Unit::create([
            'institution_id' => $this->operator->unit->institution_id,
            'code' => 'OTRA',
            'name' => 'Otra unidad',
            'enabled' => true,
        ]);

        $other = User::factory()->create([
            'role' => 'funcionario',
            'unit_id' => $unit->id,
            'enabled' => true,
        ]);

        Sanctum::actingAs($other);

        $this->getJson($this->apiUrl().'/qr.svg')->assertNotFound();

        $this->actingAs($other)
            ->get('/hojas/'.$this->reference.'/qr.svg')
            ->assertNotFound();
    }

    public function test_document_detail_includes_protected_qr_url(): void
    {
        $this->actingAs($this->operator)
            ->get(route('documents.show', $this->document->id))
            ->assertOk()
            ->assertSee(
                route('route-sheets.qr', ['reference' => $this->reference]),
                false
            );
    }
}
