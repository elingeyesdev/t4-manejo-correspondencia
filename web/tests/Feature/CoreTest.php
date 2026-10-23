<?php

namespace Tests\Feature;

use App\Models\Catalog;
use App\Models\Document;
use App\Models\Movement;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CoreTest extends TestCase
{
    use RefreshDatabase;

    private User $operator;

    private User $admin;

    private Unit $unit;

    private Unit $other;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
        $this->unit = Unit::first();
        $this->other = Unit::create(['institution_id' => $this->unit->institution_id, 'code' => 'OTRA', 'name' => 'Otra unidad']);
        $this->operator = $this->account('recepcion', $this->unit);
        $this->admin = $this->account('administrador', $this->unit);
    }

    private function account(string $role, Unit $unit): User
    {
        return User::factory()->create(['role' => $role, 'unit_id' => $unit->id, 'enabled' => true, 'password' => 'PruebaSegura12345']);
    }

    private function payload(): array
    {
        return ['remitente' => 'Institución de prueba', 'asunto' => 'Solicitud de informe', 'fecha' => '2026-10-23',
            'tipo_id' => Catalog::where('kind', 'tipo')->first()->id, 'prioridad_id' => Catalog::where('kind', 'prioridad')->first()->id,
            'unidad_id' => $this->unit->id, 'request_key' => (string) Str::uuid()];
    }

    private function api(User $user): void
    {
        Sanctum::actingAs($user);
    }

    public function test_guest_cannot_access_web_or_api(): void
    {
        $this->get('/documentos')->assertRedirect('/acceso');
        $this->getJson('/api/documentos')->assertUnauthorized();
        $this->postJson('/api/documentos', $this->payload())->assertUnauthorized();
    }

    public function test_valid_and_invalid_web_login_and_logout(): void
    {
        $this->post('/acceso', ['email' => $this->operator->email, 'password' => 'incorrecta'])->assertSessionHasErrors('email');
        $this->assertGuest();
        $this->post('/acceso', ['email' => $this->operator->email, 'password' => 'PruebaSegura12345'])->assertRedirect('/documentos');
        $this->assertAuthenticatedAs($this->operator);
        $this->post('/salir')->assertRedirect('/acceso');
        $this->assertGuest();
    }

    public function test_disabled_user_cannot_login(): void
    {
        $this->operator->update(['enabled' => false]);
        $this->post('/acceso', ['email' => $this->operator->email, 'password' => 'PruebaSegura12345'])->assertSessionHasErrors('email');
        $this->assertGuest();
    }

    public function test_inactive_unit_blocks_login_and_existing_token(): void
    {
        $token = $this->operator->createToken('prueba')->plainTextToken;
        $this->unit->update(['enabled' => false]);
        $this->withToken($token)->getJson('/api/documentos')->assertForbidden();
    }

    public function test_session_version_change_requires_new_login(): void
    {
        $this->actingAs($this->operator)->withSession(['auth_version' => 0])->get('/documentos')->assertForbidden();
        $this->assertGuest();
    }

    public function test_token_is_revocable_and_password_not_exposed(): void
    {
        $response = $this->postJson('/api/sesiones', ['email' => $this->operator->email, 'password' => 'PruebaSegura12345', 'device_name' => 'Android prueba'])->assertOk();
        $this->assertArrayNotHasKey('password', $response->json('user'));
        $token = $response->json('token');
        $this->withToken($token)->getJson('/api/documentos')->assertOk();
        $this->withToken($token)->deleteJson('/api/sesiones/actual')->assertNoContent();
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_document_sheet_and_movement_are_created_with_separate_ids(): void
    {
        $this->api($this->operator);
        $result = $this->postJson('/api/documentos', $this->payload())->assertCreated()->assertJsonPath('estado', 'REGISTRADA');
        $this->assertNotSame($result->json('id'), $result->json('hoja.id'));
        $this->assertNotSame($result->json('codigo'), $result->json('hoja.codigo'));
        $this->assertDatabaseCount('documents', 1);
        $this->assertDatabaseCount('route_sheets', 1);
        $this->assertDatabaseCount('movements', 1);
        $this->assertSame($this->operator->id, $result->json('movimientos.0.actor_id'));
        $this->assertStringEndsWith('Z', $result->json('fechaUltimoMovimiento'));
    }

    public function test_idempotent_retry_preserves_the_original_record_even_after_catalog_disabled(): void
    {
        $this->api($this->operator);
        $input = $this->payload();
        $first = $this->postJson('/api/documentos', $input)->assertCreated()->json('id');
        Catalog::find($input['tipo_id'])->update(['enabled' => false]);
        $this->postJson('/api/documentos', $input)->assertOk()->assertJsonPath('id', $first);
        $this->assertDatabaseCount('documents', 1);
        $this->assertDatabaseCount('movements', 1);
    }

    public function test_reusing_key_with_other_data_returns_conflict(): void
    {
        $this->api($this->operator);
        $input = $this->payload();
        $this->postJson('/api/documentos', $input)->assertCreated();
        $input['asunto'] = 'Otro asunto';
        $this->postJson('/api/documentos', $input)->assertConflict();
        $this->assertDatabaseCount('documents', 1);
    }

    public function test_invalid_fields_create_nothing(): void
    {
        $this->api($this->operator);
        $this->postJson('/api/documentos', array_merge($this->payload(), ['asunto' => ' ', 'fecha' => '2026-02-30']))->assertUnprocessable()->assertJsonValidationErrors(['asunto', 'fecha']);
        $this->assertDatabaseCount('documents', 0);
    }

    public function test_wrong_catalog_kind_or_disabled_catalog_is_rejected(): void
    {
        $this->api($this->operator);
        $input = $this->payload();
        $this->postJson('/api/documentos', array_merge($input, ['tipo_id' => $input['prioridad_id']]))->assertUnprocessable();
        Catalog::find($input['tipo_id'])->update(['enabled' => false]);
        $this->postJson('/api/documentos', $input)->assertUnprocessable();
        $this->assertDatabaseCount('documents', 0);
    }

    public function test_operator_cannot_register_or_read_another_unit(): void
    {
        $this->api($this->admin);
        $input = $this->payload();
        $input['unidad_id'] = $this->other->id;
        $created = $this->postJson('/api/documentos', $input)->assertCreated();
        $this->api($this->operator);
        $this->getJson('/api/documentos/'.$created->json('id'))->assertNotFound();
        $this->getJson('/api/correspondencia/guia/'.$created->json('guia'))->assertNotFound();
        $this->getJson('/api/documentos')->assertJsonPath('total', 0);
        $input['request_key'] = (string) Str::uuid();
        $this->postJson('/api/documentos', $input)->assertForbidden();
    }

    public function test_funcionario_cannot_register_or_administer(): void
    {
        $this->api($this->account('funcionario', $this->unit));
        $this->postJson('/api/documentos', $this->payload())->assertForbidden();
        $this->getJson('/api/administracion')->assertForbidden();
        $this->postJson('/api/unidades', ['code' => 'NUEVA', 'name' => 'Nueva', 'enabled' => true])->assertForbidden();
    }

    public function test_guide_endpoint_returns_real_record_and_identifiable_missing_error(): void
    {
        $this->api($this->operator);
        $created = $this->postJson('/api/documentos', $this->payload())->assertCreated();
        $this->getJson('/api/correspondencia/guia/'.strtolower($created->json('guia')))->assertOk()->assertJsonPath('id', $created->json('id'));
        $this->getJson('/api/correspondencia/guia/INEXISTENTE')->assertNotFound()->assertJsonPath('codigo', 'GUIA_NO_ENCONTRADA');
    }

    public function test_transaction_rolls_back_when_initial_movement_fails(): void
    {
        $this->api($this->operator);
        Movement::creating(fn () => throw new \RuntimeException('Fallo de almacenamiento de prueba'));
        try {
            $this->postJson('/api/documentos', $this->payload())->assertStatus(500);
        } finally {
            Movement::flushEventListeners();
        }
        foreach (['documents', 'route_sheets', 'movements', 'requests', 'audits'] as $table) {
            $this->assertDatabaseCount($table, 0);
        }
    }

    public function test_admin_catalog_uniqueness_and_disable_preserves_document(): void
    {
        $this->api($this->admin);
        $input = $this->payload();
        $this->postJson('/api/documentos', $input)->assertCreated();
        $catalog = Catalog::find($input['tipo_id']);
        $this->postJson('/api/catalogos', ['kind' => 'tipo', 'code' => $catalog->code, 'name' => 'Duplicado', 'enabled' => true])->assertUnprocessable();
        $this->putJson('/api/catalogos/'.$catalog->id, ['kind' => 'tipo', 'code' => $catalog->code, 'name' => $catalog->name, 'enabled' => false])->assertOk();
        $this->assertDatabaseCount('documents', 1);
        $this->getJson('/api/documentos')->assertOk()->assertJsonPath('data.0.tipo.enabled', false);
    }

    public function test_unit_code_and_name_are_unique(): void
    {
        $this->api($this->admin);
        $this->postJson('/api/unidades', ['code' => $this->unit->code, 'name' => 'Otro nombre', 'enabled' => true])->assertUnprocessable();
        $this->postJson('/api/unidades', ['code' => 'NUEVA', 'name' => $this->unit->name, 'enabled' => true])->assertUnprocessable();
        $this->postJson('/api/unidades', ['code' => 'NUEVA', 'name' => 'Nueva unidad', 'enabled' => true])->assertOk();
    }

    public function test_disabling_user_revokes_tokens_but_preserves_movements(): void
    {
        $this->api($this->operator);
        $this->postJson('/api/documentos', $this->payload())->assertCreated();
        $this->operator->createToken('android');
        $this->api($this->admin);
        $this->putJson('/api/usuarios/'.$this->operator->id, ['name' => $this->operator->name, 'email' => $this->operator->email, 'unit_id' => $this->unit->id, 'role' => 'recepcion', 'enabled' => false])->assertOk();
        $this->assertDatabaseCount('personal_access_tokens', 0);
        $this->assertDatabaseCount('movements', 1);
        $this->assertFalse($this->operator->fresh()->enabled);
    }

    public function test_cannot_assign_disabled_unit_or_remove_own_administration(): void
    {
        $this->other->update(['enabled' => false]);
        $this->api($this->admin);
        $this->postJson('/api/usuarios', ['name' => 'Nuevo', 'email' => 'nuevo@example.test', 'role' => 'recepcion', 'unit_id' => $this->other->id, 'enabled' => true, 'password' => 'PruebaSegura12345', 'password_confirmation' => 'PruebaSegura12345'])->assertUnprocessable();
        $this->putJson('/api/usuarios/'.$this->admin->id, ['name' => $this->admin->name, 'email' => $this->admin->email, 'role' => 'funcionario', 'unit_id' => $this->unit->id, 'enabled' => true])->assertUnprocessable();
    }

    public function test_views_render_and_escape_untrusted_document_data(): void
    {
        $this->get('/acceso')->assertOk();
        $this->actingAs($this->admin)->get('/administracion')->assertOk();
        $this->get('/documentos/nuevo')->assertOk();
        $input = $this->payload();
        $input['asunto'] = '<script>alert(1)</script>';
        $this->post('/documentos', $input)->assertRedirect();
        $doc = Document::first();
        $this->get('/documentos/'.$doc->id)->assertOk()->assertSee('&lt;script&gt;', false)->assertDontSee('<script>alert(1)</script>', false);
        $this->get('/documentos')->assertOk();
    }
}
