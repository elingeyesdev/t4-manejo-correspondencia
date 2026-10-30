<?php

namespace Tests\Feature;

use App\Models\Catalog;
use App\Models\Unit;
use App\Models\User;
use App\Services\RegisterDocument;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class SakaiViewsTest extends TestCase
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

    private function props(string $html, string $attribute = 'data-props'): array
    {
        $this->assertSame(1, preg_match('/'.preg_quote($attribute, '/').'="([^"]*)"/', $html, $matches));

        return json_decode(html_entity_decode($matches[1], ENT_QUOTES | ENT_HTML5, 'UTF-8'), true, 512, JSON_THROW_ON_ERROR);
    }

    public function test_layout_passes_registration_permission_for_each_role(): void
    {
        foreach (['funcionario' => false, 'recepcion' => true, 'administrador' => true] as $role => $allowed) {
            $response = $this->actingAs($this->account($role))->get('/documentos')->assertOk();
            $context = $this->props($response->getContent(), 'data-context');
            $this->assertSame($allowed, $context['canRegister']);
            $this->assertSame($role === 'administrador', $context['isAdmin']);
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
        $props = $this->props($response->getContent());
        $this->assertSame($key, $props['hidden']['request_key']);
        $this->assertSame('Asunto conservado', $props['initial']['asunto']);
        $unitField = collect($props['fields'])->firstWhere('name', 'unidad_id');
        $this->assertSame([(string) $operator->unit_id], array_column($unitField['options'], 'value'));
    }

    public function test_detail_serializes_untrusted_text_without_executable_markup(): void
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
        $props = $this->props($response->getContent());
        $this->assertSame($subject, $props['document']['subject']);
        $this->assertSame($document->sheet->code, $props['sheet']['code']);
        $this->assertCount(1, $props['movements']);
        $response->assertDontSee('<script>alert(1)</script>', false);
    }

    public function test_admin_restores_only_submitted_form_and_never_passwords(): void
    {
        $admin = $this->account('administrador');
        $response = $this->actingAs($admin)->withSession(['_old_input' => [
            '_form' => 'unit-new', 'code' => 'NUEVA', 'name' => 'Unidad conservada',
            'enabled' => '1', 'password' => 'NoDebeExponerse123', 'password_confirmation' => 'NoDebeExponerse123',
        ]])->get('/administracion')->assertOk();
        preg_match_all('/data-props="([^"]*)"/', $response->getContent(), $matches);
        $forms = collect($matches[1])->map(fn ($json) => json_decode(html_entity_decode($json, ENT_QUOTES | ENT_HTML5, 'UTF-8'), true, 512, JSON_THROW_ON_ERROR));
        $this->assertSame('Unidad conservada', $forms->firstWhere('formKey', 'unit-new')['initial']['name']);
        $this->assertSame($admin->name, $forms->firstWhere('formKey', 'user-'.$admin->id)['initial']['name']);
        foreach ($forms as $form) {
            $this->assertArrayNotHasKey('password', $form['initial']);
            $this->assertArrayNotHasKey('password_confirmation', $form['initial']);
        }
        $response->assertDontSee('NoDebeExponerse123');
    }
}
