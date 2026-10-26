<?php

namespace Tests\Feature;

use App\Models\Catalog;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ConfiguracionMovilTest extends TestCase
{
    use RefreshDatabase;

    public function test_guest_cannot_read_registration_options(): void
    {
        $this->getJson('/api/configuracion-registro')->assertUnauthorized();
    }

    public function test_reception_only_gets_own_unit_and_enabled_catalogs(): void
    {
        $this->seed();
        $unit = Unit::first();
        $other = Unit::create(['institution_id' => $unit->institution_id, 'code' => 'OTRA', 'name' => 'Otra unidad']);
        Catalog::create(['kind' => 'tipo', 'code' => 'INACTIVO', 'name' => 'Inactivo', 'enabled' => false]);
        Sanctum::actingAs(User::factory()->create(['role' => 'recepcion', 'unit_id' => $unit->id, 'enabled' => true]));
        $this->getJson('/api/configuracion-registro')->assertOk()
            ->assertJsonCount(1, 'unidades')->assertJsonPath('unidades.0.id', $unit->id)
            ->assertJsonCount(2, 'tipos')->assertJsonCount(2, 'prioridades')
            ->assertJsonMissing(['name' => $other->name])
            ->assertJsonMissing(['name' => 'Inactivo']);
    }

    public function test_official_cannot_read_registration_options_and_admin_can(): void
    {
        $this->seed();
        $unit = Unit::first();
        Unit::create(['institution_id' => $unit->institution_id, 'code' => 'OTRA', 'name' => 'Otra unidad']);
        Sanctum::actingAs(User::factory()->create(['role' => 'funcionario', 'unit_id' => $unit->id, 'enabled' => true]));
        $this->getJson('/api/configuracion-registro')->assertForbidden();
        Sanctum::actingAs(User::factory()->create(['role' => 'administrador', 'unit_id' => $unit->id, 'enabled' => true]));
        $this->getJson('/api/configuracion-registro')->assertOk()->assertJsonCount(2, 'unidades');
    }
}
