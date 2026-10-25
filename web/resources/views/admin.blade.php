@extends('layout')
@section('title','Administración')
@section('content')<span class="pill">ADMINISTRACIÓN</span>
<h1>Configuración institucional</h1>
<p class="muted">Gestiona unidades, catálogos y usuarios. Deshabilitar conserva las referencias históricas.</p>
<section class="card">
<h2>Unidades</h2>@foreach($units as $unit)<details>
<summary>{{ $unit->code }} · {{ $unit->name }} · {{ $unit->enabled?'Habilitada':'Deshabilitada' }}</summary>@include('partials.unit',['item'=>$unit])</details>@endforeach<details>
<summary>Agregar unidad</summary>@include('partials.unit',['item'=>null])</details>
</section>
<section class="card">
<h2>Tipos y prioridades</h2>@foreach($catalogs as $catalog)<details>
<summary>{{ $catalog->kind }} · {{ $catalog->name }} · {{ $catalog->enabled?'Habilitado':'Deshabilitado' }}</summary>@include('partials.catalog',['item'=>$catalog])</details>@endforeach<details>
<summary>Agregar catálogo</summary>@include('partials.catalog',['item'=>null])</details>
</section>
<section class="card">
<h2>Usuarios y permisos</h2>@foreach($users as $account)<details>
<summary>{{ $account->name }} · {{ $account->role }} · {{ $account->enabled?'Habilitado':'Deshabilitado' }}</summary>@include('partials.user',['item'=>$account])</details>@endforeach<details>
<summary>Agregar usuario</summary>@include('partials.user',['item'=>null])</details>
</section>@endsection
