<?php

namespace Tests\Feature;

use App\Models\Catalog;
use App\Models\Unit;
use App\Models\User;
use App\Services\RegisterDocument;
use DOMDocument;
use DOMXPath;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class InstitutionalViewsTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
    }

    private function account(string $role = 'recepcion'): User
    {
        return User::factory()->create([
            'role' => $role, 'unit_id' => Unit::firstOrFail()->id, 'enabled' => true,
        ]);
    }

    private function dom(string $html): DOMXPath
    {
        $document = new DOMDocument;
        @$document->loadHTML('<?xml encoding="UTF-8">'.$html);

        return new DOMXPath($document);
    }

    public function test_web_uses_the_shared_template_from_login_through_administration(): void
    {
        $this->get('/acceso')->assertOk()->assertSee('css/institutional.css')->assertSee('name="password"', false);
        $administrator = $this->account('administrador');
        $this->actingAs($administrator);
        foreach (['/documentos', '/documentos/nuevo', '/notas-internas', '/notas-internas/nueva', '/administracion', '/sin-registro'] as $path) {
            $response = $this->get($path)->assertStatus($path === '/sin-registro' ? 404 : 200);
            $response->assertSee('css/institutional.css')->assertSee('Bandera de Santa Cruz')->assertDontSee('sakai-app');
            $response->assertSee('Cerrar sesión');
            $dom = $this->dom($response->getContent());
            $this->assertSame($administrator->name.' · '.$administrator->unit->name, $dom->evaluate('normalize-space(//nav//p[contains(@class, "site-account")])'));
            $this->assertSame(1, $dom->query('//nav//form[@method="post" and @action="'.route('logout').'"]')->length);
        }
        $this->post('/notas-internas/nueva')->assertStatus(405)->assertSee('css/institutional.css');
    }

    public function test_layout_renders_registration_and_administration_by_role(): void
    {
        foreach (['funcionario' => false, 'recepcion' => true, 'administrador' => true] as $role => $allowed) {
            $response = $this->actingAs($this->account($role))->get('/documentos')->assertOk();
            $dom = $this->dom($response->getContent());
            $this->assertSame($allowed, $dom->query('//a[@href="'.route('documents.create').'"]')->length > 0);
            $this->assertSame($role === 'administrador', $dom->query('//a[@href="'.route('admin').'"]')->length > 0);
        }
    }

    public function test_registration_preserves_old_values_and_request_key_and_restricts_units(): void
    {
        $operator = $this->account();
        Unit::create(['institution_id' => $operator->unit->institution_id, 'code' => 'OTRA', 'name' => 'Otra unidad']);
        $key = (string) Str::uuid();
        $response = $this->actingAs($operator)->withSession(['_old_input' => [
            'remitente' => 'Remitente conservado', 'asunto' => 'Asunto conservado',
            'fecha' => '2026-10-29', 'request_key' => $key,
        ]])->get('/documentos/nuevo')->assertOk();
        $dom = $this->dom($response->getContent());
        $this->assertSame($key, $dom->evaluate('string(//input[@name="request_key"]/@value)'));
        $this->assertSame('Asunto conservado', $dom->evaluate('string(//textarea[@name="asunto"])'));
        $this->assertSame(1, $dom->query('//select[@name="unidad_id"]/option[@value!=""]')->length);
        $this->assertSame((string) $operator->unit_id, $dom->evaluate('string(//select[@name="unidad_id"]/option[@value!=""]/@value)'));
    }

    public function test_detail_renders_untrusted_text_without_executable_markup(): void
    {
        $operator = $this->account();
        $subject = '<script>alert(1)</script> {{ 7 * 7 }}';
        [$document] = app(RegisterDocument::class)->execute($operator, [
            'remitente' => 'Remitente de prueba', 'asunto' => $subject, 'fecha' => '2026-10-29',
            'tipo_id' => Catalog::where('kind', 'tipo')->firstOrFail()->id,
            'prioridad_id' => Catalog::where('kind', 'prioridad')->firstOrFail()->id,
            'unidad_id' => $operator->unit_id, 'request_key' => (string) Str::uuid(),
        ]);
        $response = $this->actingAs($operator)->get('/documentos/'.$document->id)->assertOk();
        $response->assertSee($subject)->assertSee('Vista previa del documento')
            ->assertDontSee($document->sheet->code)->assertDontSee($document->guide)
            ->assertSee('css/institutional.css')
            ->assertDontSee('<script>alert(1)</script>', false);
        $this->assertSame(1, $this->dom($response->getContent())->query('//table[contains(@class, "movement-table")]/tbody/tr')->length);

        $this->get('/documentos')->assertOk()->assertSee('Vista previa')->assertSee('Abrir documento')
            ->assertDontSee($document->code)->assertDontSee($document->guide);
    }

    public function test_admin_restores_only_submitted_form_and_never_passwords(): void
    {
        $admin = $this->account('administrador');
        $response = $this->actingAs($admin)->withSession(['_old_input' => [
            '_form' => 'unit-new', 'code' => 'NUEVA', 'name' => 'Unidad conservada',
            'enabled' => '1', 'password' => 'NoDebeExponerse123', 'password_confirmation' => 'NoDebeExponerse123',
        ]])->get('/administracion')->assertOk();
        $dom = $this->dom($response->getContent());
        $this->assertSame('Unidad conservada', $dom->evaluate('string(//input[@id="unit-new-name"]/@value)'));
        $this->assertSame($admin->name, $dom->evaluate('string(//input[@id="user-'.$admin->id.'-name"]/@value)'));
        $this->assertSame(0, $dom->query('//input[@type="password" and @value!=""]')->length);
        $response->assertDontSee('NoDebeExponerse123');
    }

    public function test_admin_code_inputs_preserve_ranges_and_escape_only_literal_hyphen(): void
    {
        $response = $this->actingAs($this->account('administrador'))->get('/administracion')->assertOk();
        $dom = $this->dom($response->getContent());

        foreach (['unit-', 'catalog-'] as $prefix) {
            $inputs = $dom->query('//input[@name="code" and starts-with(@id, "'.$prefix.'")]');
            $this->assertGreaterThanOrEqual(2, $inputs->length);
            foreach ($inputs as $input) {
                $this->assertSame('[A-Z0-9_\-]+', $input->getAttribute('pattern'), $input->getAttribute('id'));
            }
        }
    }
}
