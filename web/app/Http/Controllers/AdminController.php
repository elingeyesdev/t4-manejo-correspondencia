<?php

namespace App\Http\Controllers;

use App\Models\Catalog;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class AdminController extends Controller
{
    private function check(Request $r): void
    {
        abort_unless($r->user()->isAdmin(), 403);
    }

    public function index(Request $r)
    {
        $this->check($r);
        $data = ['units' => Unit::orderBy('name')->get(), 'catalogs' => Catalog::orderBy('kind')->orderBy('name')->get(), 'users' => User::with('unit')->orderBy('name')->get()];

        return $r->is('api/*') ? response()->json($data) : view('admin', $data);
    }

    public function unit(Request $r, ?int $id = null)
    {
        $this->check($r);
        $unit = $id ? Unit::findOrFail($id) : new Unit;
        $institution = DB::table('institutions')->value('id');
        $data = $r->validate(['code' => ['required', 'string', 'max:30', 'regex:/^[A-Z0-9_-]+$/', Rule::unique('units')->where('institution_id', $institution)->ignore($id)],
            'name' => ['required', 'string', 'max:150', Rule::unique('units')->where('institution_id', $institution)->ignore($id)], 'enabled' => 'required|boolean']);
        DB::transaction(function () use ($unit, $data, $institution, $r) {
            // No se permite deshabilitar la unidad del administrador que realiza la operación.
            abort_if($unit->exists && $unit->id === $r->user()->unit_id && ! $data['enabled'], 422, 'No puede deshabilitar su propia unidad.');
            $unit->fill($data + ['institution_id' => $institution])->save();
            $this->audit($r, 'unidad.guardar', (string) $unit->id);
        });

        return $this->saved($r, $unit);
    }

    public function catalog(Request $r, ?int $id = null)
    {
        $this->check($r);
        $catalog = $id ? Catalog::findOrFail($id) : new Catalog;
        $kind = $catalog->exists ? $catalog->kind : $r->input('kind');
        $data = $r->validate(['kind' => ['required', Rule::in([$kind]), Rule::in(['tipo', 'prioridad'])],
            'code' => ['required', 'string', 'max:30', 'regex:/^[A-Z0-9_-]+$/', Rule::unique('catalogs')->where('kind', $kind)->ignore($id)],
            'name' => ['required', 'string', 'max:150', Rule::unique('catalogs')->where('kind', $kind)->ignore($id)], 'enabled' => 'required|boolean']);
        DB::transaction(function () use ($catalog, $data, $r) {
            $catalog->fill($data)->save();
            $this->audit($r, 'catalogo.guardar', (string) $catalog->id);
        });

        return $this->saved($r, $catalog);
    }

    public function user(Request $r, ?int $id = null)
    {
        $this->check($r);
        $user = $id ? User::findOrFail($id) : new User;
        $data = $r->validate(['name' => 'required|string|max:150', 'email' => ['required', 'email', 'max:255', Rule::unique('users')->ignore($id)],
            'unit_id' => ['required', 'integer', Rule::exists('units', 'id')->where('enabled', true)],
            'role' => ['required', Rule::in(['administrador', 'recepcion', 'funcionario'])], 'enabled' => 'required|boolean',
            'password' => [$user->exists ? 'nullable' : 'required', 'confirmed', Password::min(12)->letters()->numbers()]]);
        abort_if($user->exists && $user->id === $r->user()->id && (! $data['enabled'] || $data['role'] !== 'administrador'), 422, 'No puede retirar su propio acceso administrativo.');
        if (empty($data['password'])) {
            unset($data['password']);
        }
        DB::transaction(function () use ($user, $data, $r) {
            if ($user->exists) {
                $user->auth_version++;
                $user->tokens()->delete();
            }
            $user->fill($data)->save();
            $this->audit($r, 'usuario.guardar', (string) $user->id);
            if ($user->id === $r->user()->id && $r->hasSession()) {
                $r->session()->put('auth_version', $user->auth_version);
            }
        });

        return $this->saved($r, $user);
    }

    private function audit(Request $r, string $action, string $id): void
    {
        DB::table('audits')->insert(['actor_id' => $r->user()->id, 'action' => $action, 'resource' => $id, 'occurred_at' => now()]);
    }

    private function saved(Request $r, $model)
    {
        return $r->is('api/*') ? response()->json($model) : redirect()->route('admin')->with('status','Cambios guardados.');
    }
}
