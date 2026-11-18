<?php

namespace Tests\Feature;

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

        $institution = DB::table('institutions')->insertGetId(['code' => 'DEMO', 'name' => 'Instituci├│n ficticia']);
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
        $this->get(route('notes.show', $note->id))->assertOk()->assertSee('Emitir Nota Interna');
        $action = ['version' => $note->version, 'request_key' => (string) Str::uuid()];
        $this->post(route('notes.emit', $note->id), $action)->assertRedirect();
        $first = DB::table('internal_notes')->first();
        $this->post(route('notes.emit', $note->id), $action)->assertRedirect();
        $this->get(route('notes.index'))->assertOk()->assertSee($first->cite);
        $this->assertDatabaseHas('internal_notes', ['id' => $note->id, 'cite' => $first->cite, 'state' => 'pendiente_recepcion']);
        $this->assertDatabaseHas('note_workflow_instances', ['note_id' => $note->id, 'instance_key' => '100']);
        Http::assertSentCount(1);
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
            self::ENGINE.'/user-tasks/201' => Http::response(['state' => 'CREATED']),
            self::ENGINE.'/user-tasks/202' => Http::response(['state' => 'CREATED']),
            self::ENGINE.'/user-tasks/201/completion' => Http::response(null, 204),
            self::ENGINE.'/user-tasks/202/completion' => Http::response(null, 204),
        ]);

        Sanctum::actingAs($this->author);
        $draft = $this->postJson('/api/notas-internas', $this->draft([$via1->id, $via2->id]))
            ->assertCreated()->assertJsonPath('estado', 'borrador');
        $uri = '/api/notas-internas/'.$draft->json('id');
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
        $step = $this->postJson($uri.'/conformidades', ['version' => $sent->json('version')], $via1Key)->assertOk();
        $this->postJson($uri.'/conformidades', ['version' => $sent->json('version')], $via1Key)->assertOk()
            ->assertJsonPath('version', $step->json('version'));

        Sanctum::actingAs($via2);
        $this->postJson($uri.'/conformidades', ['version' => $step->json('version')], $this->key())
            ->assertOk()->assertJsonPath('estado', 'pendiente_recepcion')->assertJsonCount(3, 'movimientos_nota');

        Sanctum::actingAs($this->recipient);
        $this->getJson('/api/notas-internas?bandeja=por_recibir')->assertOk()->assertJsonPath('meta.total', 1);
        Sanctum::actingAs($this->copy);
        $this->getJson('/api/notas-internas?bandeja=copias')->assertOk()->assertJsonPath('meta.total', 1);
        $this->getJson($uri)->assertOk()->assertJsonPath('acciones_permitidas', []);
        $this->postJson($uri.'/conformidades', ['version' => 1], $this->key())->assertForbidden();
        Sanctum::actingAs($this->outsider);
        $this->getJson($uri)->assertNotFound();
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
