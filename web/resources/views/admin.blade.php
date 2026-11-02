@extends('layout')
@section('title', 'Administración')
@section('content')
    <div class="mb-6">
        <h1 class="text-3xl font-semibold mb-2">Configuración institucional</h1>
        <p class="text-muted-color m-0">Gestiona unidades, catálogos y usuarios. Deshabilitar conserva las referencias históricas.</p>
    </div>
    <section class="card">
        <h2 class="text-xl font-semibold mt-0 mb-5">Unidades</h2>
        <div class="flex flex-col gap-3">
            @foreach($units as $unit)
                <details class="border border-surface rounded-border p-4" @if(old('_form') === 'unit-'.$unit->id) open @endif>
                    <summary class="cursor-pointer font-medium">{{ $unit->code }} · {{ $unit->name }} · {{ $unit->enabled ? 'Habilitada' : 'Deshabilitada' }}</summary>
                    <div class="mt-6">@include('partials.unit', ['item' => $unit])</div>
                </details>
            @endforeach
            <details class="border border-surface rounded-border p-4" @if(old('_form') === 'unit-new') open @endif>
                <summary class="cursor-pointer font-medium text-primary">Agregar unidad</summary>
                <div class="mt-6">@include('partials.unit', ['item' => null])</div>
            </details>
        </div>
    </section>

    <section class="card">
        <h2 class="text-xl font-semibold mt-0 mb-5">Tipos y prioridades</h2>
        <div class="flex flex-col gap-3">
            @foreach($catalogs as $catalog)
                <details class="border border-surface rounded-border p-4" @if(old('_form') === 'catalog-'.$catalog->id) open @endif>
                    <summary class="cursor-pointer font-medium">{{ $catalog->kind }} · {{ $catalog->name }} · {{ $catalog->enabled ? 'Habilitado' : 'Deshabilitado' }}</summary>
                    <div class="mt-6">@include('partials.catalog', ['item' => $catalog])</div>
                </details>
            @endforeach
            <details class="border border-surface rounded-border p-4" @if(old('_form') === 'catalog-new') open @endif>
                <summary class="cursor-pointer font-medium text-primary">Agregar catálogo</summary>
                <div class="mt-6">@include('partials.catalog', ['item' => null])</div>
            </details>
        </div>
    </section>

    <section class="card">
        <h2 class="text-xl font-semibold mt-0 mb-5">Usuarios y permisos</h2>
        <div class="flex flex-col gap-3">
            @foreach($users as $account)
                <details class="border border-surface rounded-border p-4" @if(old('_form') === 'user-'.$account->id) open @endif>
                    <summary class="cursor-pointer font-medium">{{ $account->name }} · {{ $account->role }} · {{ $account->enabled ? 'Habilitado' : 'Deshabilitado' }}</summary>
                    <div class="mt-6">@include('partials.user', ['item' => $account])</div>
                </details>
            @endforeach
            <details class="border border-surface rounded-border p-4" @if(old('_form') === 'user-new') open @endif>
                <summary class="cursor-pointer font-medium text-primary">Agregar usuario</summary>
                <div class="mt-6">@include('partials.user', ['item' => null])</div>
            </details>
        </div>
    </section>
@endsection
