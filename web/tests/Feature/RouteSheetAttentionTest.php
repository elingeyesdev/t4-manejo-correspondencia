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
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use RuntimeException;
use Tests\TestCase;

class RouteSheetAttentionTest extends TestCase
{
    use RefreshDatabase;

    private Document $document;

    private User $operator;

    private User $official;

    private string $reference;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();

        $origin = Unit::firstOrFail();
        $destination = Unit::create([
            'institution_id' => $origin->institution_id,
            'code' => 'ATENCION',
            'name' => 'Asesoría de prueba',
            'enabled' => true,
        ]);
        $this->operator = User::factory()->create(['role' => 'recepcion', 'unit_id' => $origin->id, 'enabled' => true]);
        $this->official = User::factory()->create(['role' => 'funcionario', 'unit_id' => $destination->id, 'enabled' => true]);
        [$this->document] = app(RegisterDocument::class)->execute($this->operator, [
            'remitente' => 'Persona ficticia',
            'asunto' => 'Prueba de atención',
            'fecha' => '2026-11-10',
            'tipo_id' => Catalog::where('kind', 'tipo')->firstOrFail()->id,
            'prioridad_id' => Catalog::where('kind', 'prioridad')->firstOrFail()->id,
            'unidad_id' => $origin->id,
            'request_key' => (string) Str::uuid(),
        ]);
        $this->reference = $this->document->sheet->id;
        app(RouteSheetWorkflow::class)->derive($this->operator, $this->reference, [
            'destino_unidad_id' => $destination->id,
            'motivo' => 'Revisión de la solicitud',
            'version' => 1,
            'request_key' => (string) Str::uuid(),
        ]);
    }

    public function test_attention_and_correction_are_visible_in_history_and_retries_keep_original_result(): void
    {
        $this->receive();
        Sanctum::actingAs($this->official);
        $key = (string) Str::uuid();
        $body = ['version' => 3, 'observacion' => " \tSe revisó la solicitud.\r\n"];
        $this->freezeTime();
        $first = $this->postJson($this->apiUrl(), $body, ['Idempotency-Key' => $key])
            ->assertCreated()
            ->assertJsonPath('documento_id', $this->document->id)
            ->assertJsonPath('hoja.estado', 'EN_ATENCION')
            ->assertJsonPath('hoja.version', 4)
            ->assertJsonPath('hoja.responsable_id', $this->official->id)
            ->assertJsonPath('hoja.unidad_vigente_id', $this->official->unit_id)
            ->assertJsonPath('hoja.destino_pendiente_id', null)
            ->assertJsonPath('movimiento.accion', 'ATENCION')
            ->assertJsonPath('movimiento.actor_id', $this->official->id)
            ->assertJsonPath('movimiento.unidad_origen_id', $this->official->unit_id)
            ->assertJsonPath('movimiento.unidad_destino_id', $this->official->unit_id)
            ->assertJsonPath('movimiento.fecha', now()->toISOString())->json();

        $this->postAttention(4, 'Se corrigió la referencia.')->assertCreated()->assertJsonPath('hoja.version', 5);
        $this->postJson($this->apiUrl(), ['version' => 3, 'observacion' => 'Se revisó la solicitud.'], ['Idempotency-Key' => $key])
            ->assertOk()->assertExactJson($first);
        $this->postJson($this->apiUrl(), ['version' => 3, 'observacion' => 'Otro texto'], ['Idempotency-Key' => $key])
            ->assertConflict()->assertJsonPath('codigo', 'CLAVE_REUTILIZADA');
        $this->postAttention(4, 'Versión anterior')->assertConflict()->assertJsonPath('codigo', 'VERSION_DESACTUALIZADA');

        $this->getJson('/api/hojas/'.$this->reference)->assertOk()
            ->assertJsonPath('acciones_permitidas', ['derivar', 'atender'])
            ->assertJsonPath('movimientos.3.reason', 'Se revisó la solicitud.')
            ->assertJsonPath('movimientos.4.reason', 'Se corrigió la referencia.');
        $this->getJson('/api/documentos/'.$this->document->id.'/historial')->assertOk()
            ->assertJsonPath('total', 5)
            ->assertJsonPath('data.3.id', $first['movimiento']['id'])
            ->assertJsonPath('data.3.actor.id', $this->official->id)
            ->assertJsonPath('data.3.motivo', 'Se revisó la solicitud.');
    }

    public function test_incompatible_states_and_unauthorized_actors_leave_no_attention(): void
    {
        $this->postAttention(2, 'Atención')->assertUnauthorized()->assertJsonPath('codigo', 'SESION_REQUERIDA');
        Sanctum::actingAs($this->operator);
        $this->postAttention(2, 'Todavía pendiente')->assertConflict()->assertJsonPath('codigo', 'ESTADO_INCOMPATIBLE');

        $this->receive();
        $this->postAttention(3, 'Solo consulta')->assertForbidden()->assertJsonPath('codigo', 'ACCION_NO_PERMITIDA');
        $colleague = User::factory()->create(['role' => 'funcionario', 'unit_id' => $this->official->unit_id, 'enabled' => true]);
        Sanctum::actingAs($colleague);
        $this->postAttention(3, 'Sin asignación')->assertNotFound()->assertJsonPath('codigo', 'RECURSO_NO_DISPONIBLE');

        $this->document->sheet()->update(['state' => 'CERRADA']);
        Sanctum::actingAs($this->official);
        $this->postAttention(3, 'Ya cerrada')->assertConflict()->assertJsonPath('codigo', 'ESTADO_INCOMPATIBLE');
        $this->assertDatabaseMissing('movements', ['route_sheet_id' => $this->reference, 'action' => 'ATENCION']);
        $this->assertDatabaseHas('route_sheets', ['id' => $this->reference, 'state' => 'CERRADA', 'version' => 3]);
    }

    public function test_observation_limits_and_rollback_on_failed_history_write(): void
    {
        $this->receive();
        Sanctum::actingAs($this->official);
        $this->postAttention(3, " \r\t\n")->assertUnprocessable()->assertJsonValidationErrors('observacion');
        $this->postAttention(3, str_repeat('📄', 2001))->assertUnprocessable()
            ->assertJsonPath('codigo', 'VALIDACION_FALLIDA')->assertJsonValidationErrors('observacion');
        $maximum = "\u{00A0}".str_repeat('📄', 1999);
        $this->postAttention(3, " \t".$maximum."\r\n")->assertCreated();
        $this->assertDatabaseHas('movements', ['route_sheet_id' => $this->reference, 'reason' => $maximum]);

        Event::listen('eloquent.creating: '.Movement::class, fn () => throw new RuntimeException('Fallo de historial simulado'));
        $failedKey = (string) Str::uuid();
        $this->postJson($this->apiUrl(), ['version' => 4, 'observacion' => 'Intento fallido'], ['Idempotency-Key' => $failedKey])
            ->assertServerError();
        $this->assertDatabaseHas('route_sheets', ['id' => $this->reference, 'state' => 'EN_ATENCION', 'version' => 4]);
        $this->assertDatabaseMissing('requests', ['operation' => 'atencion', 'actor_id' => $this->official->id, 'key' => $failedKey]);
        $this->assertSame(1, $this->document->sheet->movements()->where('action', 'ATENCION')->count());
    }

    public function test_web_form_shows_attention_and_photo_retry_is_separate(): void
    {
        $this->receive();
        $this->withoutVite()->actingAs($this->official);
        $detail = route('documents.show', $this->document->id);
        $this->get($detail)->assertOk()->assertSee('route-attend')->assertSee('route-derive');
        $this->from($detail)->post(route('route-sheets.attend', $this->reference), [
            '_form' => 'route-attend',
            'version' => 3,
            'observacion' => 'Atención desde el detalle.',
            'request_key' => (string) Str::uuid(),
        ])->assertRedirect($detail)->assertSessionHas('status', 'Atención registrada.');
        $this->get($detail)->assertOk()->assertSee('EN_ATENCION')->assertSee(json_encode('Atención desde el detalle.'));

        config(['attachments.active_key_version' => 'v1', 'attachments.keys' => ['v1' => 'base64:'.base64_encode(random_bytes(32))]]);
        Storage::fake(config('attachments.disk'));
        Sanctum::actingAs($this->official);
        $attachments = '/api/documentos/'.$this->document->id.'/adjuntos';
        $this->postJson($attachments, ['archivo' => UploadedFile::fake()->createWithContent('invalido.txt', 'Prueba')])
            ->assertUnprocessable();
        $this->assertDatabaseCount('attachments', 0);

        $photo = fn () => UploadedFile::fake()->createWithContent('evidencia.png', base64_decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a/2cAAAAASUVORK5CYII='
        ));
        $id = $this->postJson($attachments, ['archivo' => $photo()])->assertCreated()->json('id');
        $this->assertDatabaseCount('attachments', 1);
        $this->assertSame(1, $this->document->sheet->movements()->where('action', 'ATENCION')->count());

        $this->document->sheet()->update(['state' => 'CERRADA']);
        $this->postJson($attachments, ['archivo' => $photo()])->assertForbidden();
        $this->get($attachments.'/'.$id.'/descarga')->assertOk();
        $this->assertDatabaseHas('attachments', ['id' => $id, 'document_id' => $this->document->id]);
    }

    private function receive(): void
    {
        app(RouteSheetWorkflow::class)->receive($this->official, $this->reference, [
            'version' => 2,
            'request_key' => (string) Str::uuid(),
        ]);
    }

    private function apiUrl(): string
    {
        return '/api/hojas/'.$this->reference.'/atenciones';
    }

    private function postAttention(int $version, string $observation)
    {
        return $this->postJson($this->apiUrl(), [
            'version' => $version,
            'observacion' => $observation,
        ], ['Idempotency-Key' => (string) Str::uuid()]);
    }
}
