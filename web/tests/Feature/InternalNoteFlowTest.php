<?php

namespace Tests\Feature;

use App\Models\InternalNoteSignature;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class InternalNoteFlowTest extends TestCase
{
    private const ENGINE = 'http://camunda.test/v2';

    private const SIGNATURE = [[[100, 200], [300, 400]]];

    private User $author;

    private User $recipient;

    private User $copy;

    private User $outsider;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'app.key' => 'base64:'.base64_encode(str_repeat('t', 32)),
            'database.default' => 'sqlite',
            'database.connections.sqlite.database' => ':memory:',
            'database.connections.sqlite.url' => null,
            'camunda.url' => self::ENGINE,
        ]);
        DB::purge('sqlite');
        $this->artisan('migrate', ['--force' => true])->assertSuccessful();

        $institution = DB::table('institutions')->insertGetId(['code' => 'DEMO', 'name' => 'Institución ficticia']);
        $unit = fn (string $code): Unit => Unit::create(['institution_id' => $institution, 'code' => $code, 'name' => 'Unidad '.$code]);
        $this->author = $this->account($unit('ALFA'));
        $this->recipient = $this->account($unit('BETA'));
        $this->copy = $this->account($unit('GAMMA'));
        $this->outsider = $this->account($unit('DELTA'));

        Http::preventStrayRequests();
    }

    public function test_web_saves_and_emits_directly_with_one_cite_and_one_process(): void
    {
        Http::fake([self::ENGINE.'/process-instances' => Http::response(['processInstanceKey' => '100'])]);
        $this->actingAs($this->author)->get(route('notes.create'))->assertOk()->assertSee('Guardar borrador');
        $create = $this->post(route('notes.store'), $this->draft());
        $create->assertRedirect();
        $note = DB::table('internal_notes')->first();
        $show = route('notes.show', $note->id);
        $this->get($show)->assertOk()->assertSee('Enviar a firma')->assertDontSee('Emitir Nota Interna');
        $action = ['version' => $note->version, 'request_key' => (string) Str::uuid()];
        $this->from($show)->post(route('notes.emit', $note->id), $action)
            ->assertRedirect($show)->assertSessionHasErrors('firma');
        $this->post(route('notes.request-signature', $note->id), ['version' => $note->version])->assertRedirect($show);
        $this->get($show)->assertOk()->assertSee('Pendiente de firma')->assertSee('Firmar borrador');
        $this->post(route('notes.sign', $note->id), $action + ['firma' => json_encode(self::SIGNATURE)])->assertRedirect($show);
        $this->get($show)->assertOk()->assertSee('Borrador firmado')->assertSee('Emitir Nota Interna');
        $this->post(route('notes.emit', $note->id), $action)->assertRedirect();
        $first = DB::table('internal_notes')->first();
        $this->post(route('notes.emit', $note->id), $action)->assertRedirect();
        $this->get(route('notes.index'))->assertOk()->assertSee($first->cite);
        $this->assertDatabaseHas('internal_notes', ['id' => $note->id, 'cite' => $first->cite, 'state' => 'pendiente_recepcion']);
        $this->assertDatabaseHas('note_workflow_instances', ['note_id' => $note->id, 'instance_key' => '100']);
        Http::assertSentCount(1);
    }

    public function test_web_draft_shows_saved_reviewers_and_rejects_duplicates(): void
    {
        $first = $this->account($this->author->unit);
        $second = $this->account($this->author->unit);
        $this->actingAs($this->author)->post(route('notes.store'), $this->draft([$first->id, $second->id]))
            ->assertRedirect();
        $note = DB::table('internal_notes')->first();
        $edit = route('notes.edit', $note->id);

        $form = $this->get($edit)->assertOk()
            ->assertSee('value="'.$second->id.'" selected', false);
        $this->assertMatchesRegularExpression('/<details class="reviewers-details"\s+open\s*>/', $form->getContent());

        $invalid = $this->draft([$first->id, $first->id]) + [
            'version' => $note->version,
        ];
        $this->from($edit)->patch(route('notes.update', $note->id), $invalid)
            ->assertRedirect($edit)->assertSessionHasErrors('vias_usuario_ids.1');
        $this->assertDatabaseHas('internal_note_participants', [
            'note_id' => $note->id, 'user_id' => $second->id, 'role' => 'via', 'position' => 2,
        ]);
    }

    public function test_via_advances_in_order_and_cc_has_read_only_visibility_after_delivery(): void
    {
        $via1 = $this->account($this->author->unit);
        $via2 = $this->account($this->author->unit);
        Http::fake([
            self::ENGINE.'/process-instances' => Http::response(['processInstanceKey' => '200']),
            self::ENGINE.'/user-tasks/search' => Http::sequence()
                ->push(['items' => [['userTaskKey' => '201']]])
                ->push(['items' => [['userTaskKey' => '202']]]),
            self::ENGINE.'/user-tasks/201' => Http::sequence()->push(['state' => 'CREATED'])->push(['state' => 'COMPLETED']),
            self::ENGINE.'/user-tasks/202' => Http::response(['state' => 'CREATED']),
            self::ENGINE.'/user-tasks/201/completion' => Http::response(null, 504),
            self::ENGINE.'/user-tasks/202/completion' => Http::response(null, 204),
        ]);

        Sanctum::actingAs($this->author);
        $draft = $this->postJson('/api/notas-internas', $this->draft([$via1->id, $via2->id]))
            ->assertCreated()->assertJsonPath('estado', 'borrador');
        $uri = '/api/notas-internas/'.$draft->json('id');
        $this->signDraft($uri, $draft->json('version'));
        $sent = $this->postJson($uri.'/emision', ['version' => $draft->json('version')], $this->key())
            ->assertOk()->assertJsonPath('estado', 'pendiente_revision');
        Http::assertSent(fn (Request $request): bool => $request->url() === self::ENGINE.'/process-instances'
            && $request['variables']['revisores'] === [(string) $via1->id, (string) $via2->id]);

        foreach ([$via2, $this->recipient, $this->copy, $this->outsider] as $actor) {
            Sanctum::actingAs($actor);
            $this->getJson($uri)->assertNotFound();
        }

        Sanctum::actingAs($via1);
        $this->getJson('/api/notas-internas?bandeja=por_revisar')->assertOk()->assertJsonPath('meta.total', 1);
        $via1Key = $this->key();
        $via1Action = ['version' => $sent->json('version'), 'firma' => self::SIGNATURE];
        $this->postJson($uri.'/conformidades', ['version' => $sent->json('version')], $via1Key)
            ->assertUnprocessable()->assertJsonValidationErrors('firma');
        $this->postJson($uri.'/conformidades', $via1Action, $via1Key)->assertAccepted()
            ->assertJsonPath('version', $sent->json('version'))->assertJsonCount(1, 'movimientos_nota');

        Sanctum::actingAs($via2);
        $this->postJson($uri.'/conformidades', $via1Action, $this->key())->assertNotFound();
        Sanctum::actingAs($via1);
        $this->postJson($uri.'/conformidades', array_replace($via1Action, ['firma' => [[[10, 20], [30, 40]]]]), $via1Key)->assertConflict();
        $step = $this->postJson($uri.'/conformidades', $via1Action, $via1Key)->assertOk();
        $this->postJson($uri.'/conformidades', $via1Action, $via1Key)->assertOk()
            ->assertJsonPath('version', $step->json('version'));

        Sanctum::actingAs($via2);
        $this->postJson($uri.'/conformidades', ['version' => $step->json('version'), 'firma' => self::SIGNATURE], $this->key())
            ->assertOk()->assertJsonPath('estado', 'pendiente_recepcion')->assertJsonCount(3, 'movimientos_nota');
        $this->assertDatabaseCount('internal_note_signatures', 3);
        foreach ([$via1->id => $sent->json('version'), $via2->id => $step->json('version')] as $reviewer => $version) {
            $this->assertDatabaseHas('internal_note_signatures', [
                'note_id' => $draft->json('id'), 'action' => 'conformidad_via', 'user_id' => $reviewer, 'note_version' => $version,
            ]);
        }
        Http::assertSentCount(8);

        Sanctum::actingAs($this->recipient);
        $this->getJson('/api/notas-internas?bandeja=por_recibir')->assertOk()->assertJsonPath('meta.total', 1);
        Sanctum::actingAs($this->copy);
        $this->getJson('/api/notas-internas?bandeja=copias')->assertOk()->assertJsonPath('meta.total', 1);
        $this->getJson($uri)->assertOk()->assertJsonPath('acciones_permitidas', []);
        $this->postJson($uri.'/conformidades', ['version' => 1], $this->key())->assertForbidden();
        Sanctum::actingAs($this->outsider);
        $this->getJson($uri)->assertNotFound();
    }

    public function test_only_the_author_can_sign_the_requested_version_and_edits_require_a_new_signature(): void
    {
        Http::fake([self::ENGINE.'/process-instances' => Http::response(['processInstanceKey' => '501'])]);
        Sanctum::actingAs($this->author);
        $draft = $this->postJson('/api/notas-internas', $this->draft())->assertCreated();
        $id = $draft->json('id');
        $uri = '/api/notas-internas/'.$id;
        $action = ['version' => $draft->json('version')];
        $signature = $action + ['firma' => self::SIGNATURE];
        $key = $this->key();
        $tray = '/api/notas-internas?bandeja=por_firmar';

        $this->getJson($tray)->assertOk()->assertJsonPath('meta.total', 0);
        $this->postJson($uri.'/emision', $action, $this->key())->assertUnprocessable()->assertJsonValidationErrors('firma');
        $this->postJson($uri.'/firmas', $signature, $key)->assertConflict();
        $this->postJson($uri.'/solicitud-firma', $action)->assertOk()->assertJsonPath('estado_firma', 'pendiente');
        $this->getJson($tray)->assertOk()->assertJsonPath('data.0.id', $id)->assertJsonPath('meta.total', 1);

        Sanctum::actingAs($this->recipient);
        $this->getJson($tray)->assertOk()->assertJsonPath('meta.total', 0);
        $this->postJson($uri.'/firmas', $signature, $key)->assertNotFound();

        Sanctum::actingAs($this->author);
        $this->postJson($uri.'/firmas', $action + ['firma' => [[[0, 0], [0, 0]]]], $key)
            ->assertUnprocessable()->assertJsonValidationErrors('firma');
        $this->postJson($uri.'/firmas', $signature, $key)->assertOk()->assertJsonPath('estado_firma', 'firmada')
            ->assertJsonPath('acciones_permitidas', ['editar_borrador', 'emitir'])->assertJsonMissingPath('firma');
        $this->postJson($uri.'/firmas', $signature, $key)->assertOk();
        $this->getJson($tray)->assertOk()->assertJsonPath('meta.total', 0);
        $this->assertDatabaseCount('internal_note_signatures', 1);
        $stored = InternalNoteSignature::firstOrFail();
        $this->assertSame(self::SIGNATURE, $stored->strokes);
        $this->assertNotSame(json_encode(self::SIGNATURE), $stored->getRawOriginal('strokes'));
        $this->assertSame($this->author->id, $stored->user_id);
        $this->assertSame($this->author->unit_id, $stored->unit_id);
        $this->assertNotNull($stored->signed_at);

        $this->patchJson($uri, $this->draft() + $action)->assertOk()->assertJsonPath('estado_firma', 'firmada');
        $edited = $this->patchJson($uri, array_replace($this->draft(), ['cuerpo' => 'Contenido corregido']) + $action)
            ->assertOk()->assertJsonPath('estado_firma', 'sin_solicitar');
        $this->postJson($uri.'/emision', $action, $this->key())->assertConflict();
        $this->postJson($uri.'/emision', ['version' => $edited->json('version')], $this->key())
            ->assertUnprocessable()->assertJsonValidationErrors('firma');
        Http::assertNothingSent();
        $this->signDraft($uri, $edited->json('version'));
        $this->postJson($uri.'/emision', ['version' => $edited->json('version')], $this->key())
            ->assertOk()->assertJsonPath('estado', 'pendiente_recepcion');
        Http::assertSentCount(1);
    }

    public function test_note_receipt_and_route_sheet_are_confirmed_once_by_camunda(): void
    {
        Http::fake([
            self::ENGINE.'/process-instances' => Http::response(['processInstanceKey' => '300']),
            self::ENGINE.'/user-tasks/search' => Http::sequence()
                ->push(['items' => [['userTaskKey' => '301']]])
                ->push(['items' => [['userTaskKey' => '302']]])
                ->push(['items' => [['userTaskKey' => '303']]])
                ->push(['items' => [['userTaskKey' => '304']]])
                ->push(['items' => [['userTaskKey' => '304']]])
                ->push(['items' => [['userTaskKey' => '305']]]),
            self::ENGINE.'/user-tasks/301' => Http::sequence()->push(['state' => 'CREATED'])->push(['state' => 'COMPLETED']),
            self::ENGINE.'/user-tasks/301/completion' => Http::response(null, 504),
            self::ENGINE.'/user-tasks/302' => Http::sequence()->push(['state' => 'CREATED'])->push(['state' => 'COMPLETED']),
            self::ENGINE.'/user-tasks/302/completion' => Http::response(null, 504),
            self::ENGINE.'/user-tasks/303' => Http::response(['state' => 'CREATED']),
            self::ENGINE.'/user-tasks/303/completion' => Http::response(null, 204),
            self::ENGINE.'/user-tasks/304' => Http::response(['state' => 'CREATED']),
            self::ENGINE.'/user-tasks/304/completion' => Http::response(null, 204),
            self::ENGINE.'/user-tasks/305' => Http::response(['state' => 'CREATED']),
            self::ENGINE.'/user-tasks/305/completion' => Http::response(null, 204),
        ]);

        Sanctum::actingAs($this->author);
        $draft = $this->postJson('/api/notas-internas', $this->draft())->assertCreated();
        $uri = '/api/notas-internas/'.$draft->json('id');
        $this->signDraft($uri, $draft->json('version'));
        $emitted = $this->postJson($uri.'/emision', ['version' => $draft->json('version')], $this->key())->assertOk();
        $payload = ['version' => $emitted->json('version')];

        Sanctum::actingAs($this->copy);
        $this->postJson($uri.'/recepciones', $payload, $this->key())->assertForbidden();
        $this->actingAs($this->recipient, 'web')->get(route('notes.show', $draft->json('id')))
            ->assertOk()->assertSee('Confirmar recepción');
        Sanctum::actingAs($this->recipient);
        $key = $this->key();
        $this->getJson($uri)->assertJsonPath('acciones_permitidas', ['confirmar_primera_recepcion']);
        $this->postJson($uri.'/recepciones', $payload, $key)->assertAccepted()->assertJsonPath('hoja_id', null);
        $this->assertDatabaseCount('route_sheets', 0);
        $this->postJson($uri.'/recepciones', $payload, $this->key())->assertConflict();
        $receipt = $this->postJson($uri.'/recepciones', $payload, $key)->assertOk()
            ->assertJsonPath('estado', 'recibida')->assertJsonPath('cite', $emitted->json('cite'));
        $sheet = $receipt->json('hoja_id');
        $document = $receipt->json('documento_id');
        $this->postJson($uri.'/recepciones', $payload, $key)->assertOk()->assertJsonPath('hoja_id', $sheet);
        $this->assertDatabaseCount('route_sheets', 1);
        $this->assertDatabaseHas('documents', [
            'id' => $document, 'code' => $emitted->json('cite'), 'subject' => $draft->json('asunto'), 'sender' => $this->author->name,
        ]);
        $this->assertDatabaseCount('movements', 1);
        $this->actingAs($this->recipient, 'web')->get(route('notes.show', $draft->json('id')))
            ->assertOk()->assertSee('Abrir hoja de ruta');
        Sanctum::actingAs($this->recipient);

        $route = '/api/hojas/'.$sheet;
        $derivation = ['version' => 1, 'destino_unidad_id' => $this->outsider->unit_id, 'motivo' => 'Revisar el inventario'];
        $deriveKey = $this->key();
        $this->postJson($route.'/derivaciones', $derivation, $deriveKey)->assertServiceUnavailable();
        $this->assertDatabaseCount('movements', 1);
        $this->postJson($route.'/derivaciones', $derivation, $this->key())->assertConflict();
        $this->postJson($route.'/derivaciones', $derivation, $deriveKey)->assertCreated();
        $this->postJson($route.'/derivaciones', $derivation, $deriveKey)->assertOk();
        $this->getJson($uri)->assertJsonPath('unidad_actual.id', $this->recipient->unit_id)
            ->assertJsonPath('destino_pendiente.id', $this->outsider->unit_id);
        $this->postJson($route.'/recepciones', ['version' => 2], $this->key())->assertForbidden();

        Sanctum::actingAs($this->outsider);
        $this->getJson('/api/notas-internas?bandeja=por_recibir')->assertOk()->assertJsonPath('meta.total', 1);
        $this->postJson($route.'/recepciones', ['version' => 2], $this->key())->assertCreated();
        $this->postJson($route.'/atenciones', ['version' => 3, 'observacion' => 'Inventario revisado'], $this->key())->assertCreated();
        $this->postJson('/api/documentos/'.$document.'/respuestas', [
            'version' => 4, 'remitente' => 'Unidad Delta', 'asunto' => 'Resultado de prueba', 'fecha' => '2026-11-18',
            'tipo_id' => DB::table('catalogs')->where('kind', 'tipo')->value('id'),
            'prioridad_id' => DB::table('catalogs')->where('kind', 'prioridad')->value('id'),
        ], $this->key())->assertCreated();
        $closure = ['version' => 5, 'motivo' => 'Expediente atendido'];
        $closeKey = $this->key();
        $this->postJson($route.'/cierre', $closure, $closeKey)->assertServiceUnavailable();
        $this->postJson($route.'/cierre', $closure, $closeKey)->assertOk();
        $this->getJson($uri)->assertOk()->assertJsonPath('estado', 'cerrada')->assertJsonPath('acciones_permitidas', []);
        $this->assertDatabaseCount('movements', 6);

        Sanctum::actingAs($this->copy);
        $this->getJson('/api/notas-internas?bandeja=copias')->assertOk()->assertJsonPath('meta.total', 1);
        $this->getJson($uri)->assertOk()->assertJsonPath('estado', 'cerrada')->assertJsonPath('acciones_permitidas', []);
        Http::assertSent(fn (Request $request): bool => $request->url() === self::ENGINE.'/user-tasks/302/completion'
            && $request['variables']->decisionRecorrido === 'derivar');
        Http::assertSent(fn (Request $request): bool => $request->url() === self::ENGINE.'/user-tasks/305/completion'
            && $request['variables']->decisionRecorrido === 'cerrar');
    }

    public function test_first_receipt_recovers_when_the_recipient_changes_unit_during_confirmation(): void
    {
        $destination = $this->recipient->unit;
        $replacement = $this->account($destination);
        Http::fake([
            self::ENGINE.'/process-instances' => Http::response(['processInstanceKey' => '400']),
            self::ENGINE.'/user-tasks/search' => Http::response(['items' => [['userTaskKey' => '401']]]),
            self::ENGINE.'/user-tasks/401' => Http::sequence()->push(['state' => 'CREATED'])->push(['state' => 'COMPLETED']),
            self::ENGINE.'/user-tasks/401/completion' => function () {
                User::whereKey($this->recipient->id)->update(['unit_id' => $this->outsider->unit_id]);

                return Http::response(null, 204);
            },
        ]);

        Sanctum::actingAs($this->author);
        $draft = $this->postJson('/api/notas-internas', $this->draft())->assertCreated();
        $note = '/api/notas-internas/'.$draft->json('id');
        $this->signDraft($note, $draft->json('version'));
        $emitted = $this->postJson($note.'/emision', ['version' => $draft->json('version')], $this->key())->assertOk();
        $payload = ['version' => $emitted->json('version')];

        Sanctum::actingAs($this->recipient);
        $this->postJson($note.'/recepciones', $payload, $this->key())->assertForbidden();
        $this->assertDatabaseCount('documents', 0);
        $this->assertDatabaseCount('route_sheets', 0);
        $this->assertDatabaseCount('movements', 0);
        $this->assertDatabaseHas('internal_notes', [
            'id' => $draft->json('id'),
            'state' => 'pendiente_recepcion',
            'receipt_actor_id' => null,
            'receipt_task_key' => '401',
        ]);

        Sanctum::actingAs($replacement);
        $this->getJson('/api/notas-internas?bandeja=por_recibir')->assertOk()->assertJsonPath('meta.total', 1);
        $key = $this->key();
        $receipt = $this->postJson($note.'/recepciones', $payload, $key)
            ->assertOk()->assertJsonPath('estado', 'recibida')->assertJsonPath('cite', $emitted->json('cite'));
        $this->postJson($note.'/recepciones', $payload, $key)
            ->assertOk()->assertJsonPath('hoja_id', $receipt->json('hoja_id'));
        $this->assertDatabaseHas('route_sheets', [
            'id' => $receipt->json('hoja_id'),
            'responsible_id' => $replacement->id,
            'current_unit_id' => $destination->id,
        ]);
        $this->assertDatabaseCount('route_sheets', 1);
        $this->assertDatabaseCount('movements', 1);
        Http::assertSentCount(5);
    }

    private function signDraft(string $uri, int $version): void
    {
        $this->postJson($uri.'/solicitud-firma', ['version' => $version])->assertOk();
        $this->postJson($uri.'/firmas', ['version' => $version, 'firma' => self::SIGNATURE], $this->key())->assertOk();
    }

    private function account(Unit $unit): User
    {
        return User::factory()->create(['unit_id' => $unit->id, 'role' => 'funcionario', 'enabled' => true]);
    }

    private function draft(array $via = []): array
    {
        return [
            'asunto' => 'Inventario de prueba',
            'referencia' => 'Referencia ficticia',
            'cuerpo' => 'Solicitud con datos ficticios.',
            'destinatario_unidad_id' => $this->recipient->unit_id,
            'vias_usuario_ids' => $via,
            'cc_usuario_ids' => [$this->copy->id],
        ];
    }

    private function key(): array
    {
        return ['Idempotency-Key' => (string) Str::uuid()];
    }
}
