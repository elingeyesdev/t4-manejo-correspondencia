@extends('layout')
@section('title', 'Administración')
@section('content')
    <div class="page-heading">
        <h1 >Configuración institucional</h1>
        <p class="text-secondary m-0">Gestiona unidades, catálogos y usuarios. Deshabilitar conserva las referencias históricas.</p>
    </div>
    <section class="note-section wide-section">
        <h2 >Unidades</h2>
        <div class="admin-list">
            @foreach($units as $unit)
                <details class="admin-item" @if(old('_form') === 'unit-'.$unit->id) open @endif>
                    <summary class="form-label">{{ $unit->code }} · {{ $unit->name }} · {{ $unit->enabled ? 'Habilitada' : 'Deshabilitada' }}</summary>
                    <div class="mt-3 mb-2 note-form">@include('partials.unit', ['item' => $unit])</div>
                </details>
            @endforeach
            <details class="admin-item" @if(old('_form') === 'unit-new') open @endif>
                <summary class="form-label">Agregar unidad</summary>
                <div class="mt-3 mb-2 note-form">@include('partials.unit', ['item' => null])</div>
            </details>
        </div>
    </section>

    <section class="note-section wide-section">
        <h2 >Tipos y prioridades</h2>
        <div class="admin-list">
            @foreach($catalogs as $catalog)
                <details class="admin-item" @if(old('_form') === 'catalog-'.$catalog->id) open @endif>
                    <summary class="form-label">{{ $catalog->kind }} · {{ $catalog->name }} · {{ $catalog->enabled ? 'Habilitado' : 'Deshabilitado' }}</summary>
                    <div class="mt-3 mb-2 note-form">@include('partials.catalog', ['item' => $catalog])</div>
                </details>
            @endforeach
            <details class="admin-item" @if(old('_form') === 'catalog-new') open @endif>
                <summary class="form-label">Agregar catálogo</summary>
                <div class="mt-3 mb-2 note-form">@include('partials.catalog', ['item' => null])</div>
            </details>
        </div>
    </section>

    <section class="note-section wide-section">
        <h2 >Usuarios y permisos</h2>
        <div class="admin-list">
            @foreach($users as $account)
                <details class="admin-item" @if(old('_form') === 'user-'.$account->id) open @endif>
                    <summary class="form-label">{{ $account->name }} · {{ $account->role }} · {{ $account->enabled ? 'Habilitado' : 'Deshabilitado' }}</summary>
                    <div class="mt-3 mb-2 note-form">@include('partials.user', ['item' => $account])</div>
                </details>
            @endforeach
            <details class="admin-item" @if(old('_form') === 'user-new') open @endif>
                <summary class="form-label">Agregar usuario</summary>
                <div class="mt-3 mb-2 note-form">@include('partials.user', ['item' => null])</div>
            </details>
        </div>
    </section>
@endsection
