<?php

namespace Tests\Feature;

use App\Models\Catalog;
use App\Models\Document;
use App\Models\Movement;
use App\Models\Unit;
use App\Models\User;
use App\Services\RegisterDocument;
use App\Services\RouteSheetWorkflow;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Laravel\Sanctum\Sanctum;
use RuntimeException;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Tests\TestCase;

class RouteSheetResponseTest extends TestCase
{
    use RefreshDatabase;

    private User $origin;

    private User $recipient;

    private Document $document;

    private RouteSheetWorkflow $workflow;

    private array $intent;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();

        $originUnit = Unit::firstOrFail();
        $destination = Unit::create([
            'institution_id' => $originUnit->institution_id,
            'code' => 'JURIDICA',
            'name' => 'Asesoría Jurídica',
            'enabled' => true,
        ]);
        $this->origin = User::factory()->create(['unit_id' => $originUnit->id, 'role' => 'recepcion', 'enabled' => true]);
        $this->recipient = User::factory()->create(['unit_id' => $destination->id, 'role' => 'funcionario', 'enabled' => true]);
        $this->intent = [
            'remitente' => 'Asesoría Jurídica',
            'asunto' => 'Respuesta a la solicitud',
            'fecha' => '2026-11-11',
            'tipo_id' => Catalog::where('kind', 'tipo')->firstOrFail()->id,
            'prioridad_id' => Catalog::where('kind', 'prioridad')->firstOrFail()->id,
            'version' => 3,
            'request_key' => (string) Str::uuid(),
        ];
        [$this->document] = app(RegisterDocument::class)->execute(
            $this->origin,
            array_replace($this->intent, ['asunto' => 'Solicitud original', 'unidad_id' => $originUnit->id]),
        );
        $this->workflow = app(RouteSheetWorkflow::class);
        $this->workflow->derive($this->origin, $this->document->sheet->id, [
            'destino_unidad_id' => $destination->id,
            'motivo' => 'Revisión jurídica',
            'version' => 1,
            'request_key' => (string) Str::uuid(),
        ]);
        $this->workflow->receive($this->recipient, $this->document->sheet->id, [
            'version' => 2,
            'request_key' => (string) Str::uuid(),
        ]);
    }

    public function test_response_is_linked_and_retry_returns_the_same_document_and_movement(): void
    {
        [$payload, $created] = $this->workflow->respond($this->recipient, $this->document->id, $this->intent);

        $response = $this->document->responses()->sole();
        $this->assertTrue($created);
        $this->assertNotSame($this->document->id, $response->id);
        $this->assertSame($this->document->id, $response->original->id);
        $this->assertSame($this->recipient->unit_id, $response->unit_id);
        $this->assertSame($response->id, $payload['respuesta_id']);
        $this->assertSame('RECIBIDA', $payload['hoja']['estado']);
        $this->assertSame(4, $payload['hoja']['version']);
        $this->assertDatabaseHas('movements', [
            'id' => $payload['movimiento']['id'],
            'route_sheet_id' => $this->document->sheet->id,
            'actor_id' => $this->recipient->id,
            'action' => 'RESPUESTA',
            'reason' => 'Respuesta vinculada: '.$response->code,
            'sheet_version' => 4,
        ]);
        $this->assertSame(
            [$payload, false],
            $this->workflow->respond($this->recipient, $this->document->id, $this->intent),
        );
        $this->assertSame(1, $this->document->responses()->count());
        $this->assertSame(1, $this->document->sheet->movements()->where('action', 'RESPUESTA')->count());
    }

    public function test_invalid_catalog_creates_no_response(): void
    {
        $this->expectException(ValidationException::class);

        try {
            $this->workflow->respond(
                $this->recipient,
                $this->document->id,
                array_replace($this->intent, ['tipo_id' => $this->intent['prioridad_id']]),
            );
        } finally {
            $this->assertNoResponseWasSaved();
        }
    }

    public function test_authorized_users_can_follow_document_links_and_read_shared_history(): void
    {
        [$result] = $this->workflow->respond($this->recipient, $this->document->id, $this->intent);
        $response = $this->document->responses()->sole();
        $originalPath = '/api/documentos/'.$this->document->id;
        $responsePath = '/api/documentos/'.$response->id;

        Sanctum::actingAs($this->recipient);
        $this->getJson($originalPath)->assertOk()->assertJsonPath('respuestas.0.id', $response->id);
        $this->getJson($responsePath)->assertOk()
            ->assertJsonPath('id', $response->id)
            ->assertJsonPath('documento_original.id', $this->document->id)
            ->assertJsonPath('hoja.id', $this->document->sheet->id)
            ->assertJsonPath('acciones_permitidas', []);
        $this->getJson('/api/documentos')->assertOk()
            ->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $this->document->id);

        $this->document->sheet()->update(['state' => 'CERRADA']);
        Sanctum::actingAs($this->origin);
        $this->getJson('/api/correspondencia/guia/'.$response->guide)->assertOk()
            ->assertJsonPath('id', $response->id)->assertJsonPath('estado', 'CERRADA');
        $this->getJson($responsePath.'/historial')->assertOk()
            ->assertJsonPath('hoja.id', $this->document->sheet->id)
            ->assertJsonPath('data.3.id', $result['movimiento']['id']);

        $this->withoutVite()->actingAs($this->origin, 'web');
        $this->get(route('documents.show', $this->document->id))
            ->assertOk()->assertSee(route('documents.show', $response->id));
        $this->get(route('documents.show', $response->id))
            ->assertOk()->assertSee('Documento original')
            ->assertSee(route('documents.show', $this->document->id))
            ->assertSee('RESPUESTA')->assertDontSee('route-attend');
    }

    public function test_response_does_not_grant_access_to_colleagues_without_original_access(): void
    {
        $this->workflow->respond($this->recipient, $this->document->id, $this->intent);
        $response = $this->document->responses()->sole();
        $colleague = User::factory()->create([
            'unit_id' => $this->recipient->unit_id,
            'role' => 'funcionario',
            'enabled' => true,
        ]);

        Sanctum::actingAs($colleague);
        $this->getJson('/api/documentos/'.$response->id)->assertNotFound();
        $this->getJson('/api/documentos/'.$response->id.'/historial')->assertNotFound();
        $this->getJson('/api/correspondencia/guia/'.$response->guide)->assertNotFound();
        $this->getJson('/api/documentos/'.$response->id.'/adjuntos')->assertNotFound();
        $this->actingAs($colleague, 'web')->get(route('documents.show', $response->id))->assertNotFound();
    }

    public function test_api_registers_response_with_current_unit_and_replays_the_same_result(): void
    {
        Sanctum::actingAs($this->recipient);
        $url = '/api/documentos/'.$this->document->id.'/respuestas';
        $data = array_replace($this->intent, ['unidad_id' => $this->origin->unit_id]);
        $headers = ['Idempotency-Key' => $data['request_key']];
        unset($data['request_key']);

        $result = $this->postJson($url, $data, $headers)->assertCreated()
            ->assertJsonPath('hoja.version', 4)
            ->assertJsonPath('movimiento.accion', 'RESPUESTA')->json();
        $this->postJson($url, $data, $headers)->assertOk()->assertExactJson($result);
        $this->postJson($url, array_replace($data, ['asunto' => 'Otra respuesta']), $headers)
            ->assertConflict()->assertJsonPath('codigo', 'CLAVE_REUTILIZADA');
        $this->assertSame($this->recipient->unit_id, $this->document->responses()->sole()->unit_id);
    }

    public function test_api_rejects_invalid_catalogs_and_users_who_are_not_responsible(): void
    {
        $url = '/api/documentos/'.$this->document->id.'/respuestas';
        $this->postJson($url, $this->intent)->assertUnauthorized()->assertJsonPath('codigo', 'SESION_REQUERIDA');

        Sanctum::actingAs($this->origin);
        $this->postJson($url, $this->intent)->assertForbidden()->assertJsonPath('codigo', 'ACCION_NO_PERMITIDA');

        Sanctum::actingAs($this->recipient);
        $invalid = array_replace($this->intent, ['tipo_id' => $this->intent['prioridad_id']]);
        $this->postJson($url, $invalid)->assertUnprocessable()
            ->assertJsonPath('codigo', 'VALIDACION_FALLIDA')->assertJsonValidationErrors('tipo_id');
        $this->assertNoResponseWasSaved();
    }

    public function test_web_form_preserves_a_draft_on_version_conflict_and_links_the_response(): void
    {
        $this->withoutVite()->actingAs($this->origin, 'web');
        $detail = route('documents.show', $this->document->id);
        $url = route('documents.responses.store', $this->document->id);
        $this->get($detail)->assertOk()->assertDontSee('route-respond');

        $this->actingAs($this->recipient, 'web');
        $this->get($detail)->assertOk()->assertSee('route-respond')->assertSee($url);

        $draft = $this->intent + ['_form' => 'route-respond'];
        $this->from($detail)->post($url, array_replace($draft, ['version' => 2]))
            ->assertRedirect($detail)->assertSessionHasErrors('recorrido')
            ->assertSessionHasInput('asunto', $draft['asunto']);
        $this->assertNoResponseWasSaved();

        $this->from($detail)->post($url, $draft)
            ->assertRedirect($detail)->assertSessionHas('status', 'Respuesta vinculada.');
        $response = $this->document->responses()->sole();
        $this->get($detail)->assertOk()->assertSee(route('documents.show', $response->id))
            ->assertSee('"statusMessage":'.json_encode('Respuesta vinculada.'));
        $this->get(route('documents.show', $response->id))->assertOk()->assertDontSee('route-respond');
    }

    public function test_original_unit_can_read_but_cannot_register_a_response(): void
    {
        $this->expectException(HttpException::class);
        $this->expectExceptionMessage('ACCION_NO_PERMITIDA');

        try {
            $this->workflow->respond($this->origin, $this->document->id, $this->intent);
        } finally {
            $this->assertNoResponseWasSaved();
        }
    }

    public function test_movement_failure_rolls_back_the_linked_document_and_version(): void
    {
        Event::listen('eloquent.creating: '.Movement::class, fn () => throw new RuntimeException('Fallo de historial simulado'));
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Fallo de historial simulado');

        try {
            $this->workflow->respond($this->recipient, $this->document->id, $this->intent);
        } finally {
            $this->assertNoResponseWasSaved();
        }
    }

    public function test_web_closes_a_linked_expedient_only_after_confirmation_and_preserves_consultation(): void
    {
        $this->withoutVite()->actingAs($this->recipient, 'web');
        $detail = route('documents.show', $this->document->id);
        $responseUrl = route('documents.responses.store', $this->document->id);
        $closeUrl = route('route-sheets.close', $this->document->sheet->id);

        $this->post($responseUrl, $this->intent)->assertRedirect($detail);
        $response = $this->document->responses()->sole();
        $this->get($detail)->assertOk()->assertSee('route-close')->assertSee('Confirmo el cierre');

        $closure = [
            '_form' => 'route-close',
            'version' => 4,
            'request_key' => (string) Str::uuid(),
            'motivo' => 'Respuesta remitida al solicitante.',
        ];
        $this->from($detail)->post($closeUrl, $closure)
            ->assertRedirect($detail)->assertSessionHasErrors('confirmar');
        $this->get($detail)->assertOk()->assertSee('"statusMessage":null');
        $this->assertDatabaseHas('route_sheets', ['id' => $this->document->sheet->id, 'version' => 4, 'state' => 'RECIBIDA']);

        $this->post($closeUrl, $closure + ['confirmar' => '1'])
            ->assertRedirect($detail)->assertSessionHas('status', 'Expediente cerrado.');
        $this->get($detail)->assertOk()->assertSee('CERRADA')
            ->assertSee('"statusMessage":'.json_encode('Expediente cerrado.'))
            ->assertSee(route('documents.show', $response->id))
            ->assertDontSee('route-close')->assertDontSee('route-respond')->assertDontSee('route-attend');
        $this->get(route('documents.show', $response->id))
            ->assertOk()->assertSee('CERRADA')->assertSee(route('documents.show', $this->document->id));
        $this->assertDatabaseHas('movements', [
            'route_sheet_id' => $this->document->sheet->id,
            'action' => 'CIERRE',
            'reason' => $closure['motivo'],
            'sheet_version' => 5,
        ]);

        Sanctum::actingAs($this->recipient);
        $fresh = array_replace($this->intent, ['version' => 5, 'request_key' => (string) Str::uuid()]);
        $this->postJson('/api/documentos/'.$this->document->id.'/respuestas', $fresh)
            ->assertConflict()->assertJsonPath('codigo', 'ESTADO_INCOMPATIBLE');
        $this->postJson('/api/hojas/'.$this->document->sheet->id.'/atenciones', $fresh + ['observacion' => 'Otro cambio'])
            ->assertConflict()->assertJsonPath('codigo', 'ESTADO_INCOMPATIBLE');
        $this->assertSame(1, $this->document->responses()->count());
        $this->assertSame(5, $this->document->sheet->fresh()->version);
    }

    public function test_closing_without_response_is_idempotent_even_with_a_new_key(): void
    {
        Sanctum::actingAs($this->recipient);
        $url = '/api/hojas/'.$this->document->sheet->id.'/cierre';
        $body = ['version' => 3, 'motivo' => str_repeat('á', 500)];
        $headers = ['Idempotency-Key' => (string) Str::uuid()];
        $this->postJson($url, array_replace($body, ['motivo' => str_repeat('á', 501)]), $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('motivo');
        $this->postJson($url, array_replace($body, ['motivo' => " \t\r\n"]), $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('motivo');
        $this->postJson($url, array_replace($body, ['version' => 2]), $headers)
            ->assertConflict()->assertJsonPath('codigo', 'VERSION_DESACTUALIZADA');

        $result = $this->postJson($url, $body, $headers)->assertOk()
            ->assertJsonPath('hoja.estado', 'CERRADA')
            ->assertJsonPath('hoja.version', 4)
            ->assertJsonPath('hoja.responsable_id', $this->recipient->id)
            ->assertJsonPath('movimiento.motivo', $body['motivo'])->json();
        $this->postJson($url, $body, $headers)->assertOk()->assertExactJson($result);

        $newHeaders = ['Idempotency-Key' => (string) Str::uuid()];
        $newBody = array_replace($body, ['motivo' => 'Segundo intento con otro motivo']);
        $this->postJson($url, $newBody, $newHeaders)->assertOk()->assertExactJson($result);
        $this->postJson($url, $body, $newHeaders)
            ->assertConflict()->assertJsonPath('codigo', 'CLAVE_REUTILIZADA');
        $this->assertSame(1, $this->document->sheet->movements()->where('action', 'CIERRE')->count());
        $this->assertSame(0, $this->document->responses()->count());

        Sanctum::actingAs($this->origin);
        $this->postJson($url, $body, $headers)->assertForbidden()->assertJsonPath('codigo', 'ACCION_NO_PERMITIDA');
        $this->getJson('/api/documentos/'.$this->document->id)->assertOk()
            ->assertJsonPath('estado', 'CERRADA')->assertJsonPath('acciones_permitidas', []);
    }

    public function test_pending_reception_cannot_be_closed(): void
    {
        $sheet = $this->document->sheet;
        $this->workflow->derive($this->recipient, $sheet->id, [
            'destino_unidad_id' => $this->origin->unit_id,
            'motivo' => 'Nueva derivación',
            'version' => 3,
            'request_key' => (string) Str::uuid(),
        ]);

        Sanctum::actingAs($this->recipient);
        $this->postJson('/api/hojas/'.$sheet->id.'/cierre', [
            'motivo' => 'Intento de cierre',
            'version' => 4,
            'request_key' => (string) Str::uuid(),
        ])->assertConflict()->assertJsonPath('codigo', 'ESTADO_INCOMPATIBLE');
        $this->assertDatabaseHas('route_sheets', ['id' => $sheet->id, 'state' => 'PENDIENTE_RECEPCION', 'version' => 4]);
        $this->assertDatabaseMissing('movements', ['route_sheet_id' => $sheet->id, 'action' => 'CIERRE']);
    }

    public function test_closure_rolls_back_when_its_movement_cannot_be_saved(): void
    {
        $sheet = $this->document->sheet;
        Event::listen('eloquent.creating: '.Movement::class, fn () => throw new RuntimeException('Fallo de cierre simulado'));
        Sanctum::actingAs($this->recipient);
        $this->postJson('/api/hojas/'.$sheet->id.'/cierre', [
            'motivo' => 'Intento de cierre',
            'version' => 3,
            'request_key' => (string) Str::uuid(),
        ])->assertServerError();
        $this->assertDatabaseHas('route_sheets', ['id' => $sheet->id, 'state' => 'RECIBIDA', 'version' => 3]);
        $this->assertDatabaseMissing('requests', ['document_id' => $this->document->id, 'operation' => 'cierre']);
        $this->assertDatabaseMissing('movements', ['route_sheet_id' => $sheet->id, 'action' => 'CIERRE']);
    }

    private function assertNoResponseWasSaved(): void
    {
        $this->assertSame(0, $this->document->responses()->count());
        $this->assertSame(3, $this->document->sheet->fresh()->version);
        $this->assertDatabaseMissing('movements', ['route_sheet_id' => $this->document->sheet->id, 'action' => 'RESPUESTA']);
        $this->assertDatabaseMissing('requests', ['document_id' => $this->document->id, 'operation' => 'respuesta']);
    }
}
