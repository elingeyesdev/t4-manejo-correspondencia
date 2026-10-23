@extends('layout')
@section('title','Nuevo registro')
@section('content')<span class="pill">RECEPCIÓN</span>
<h1>Registrar correspondencia</h1>
<p class="muted">Se crearán el documento y su hoja de ruta en una sola operación.</p>
<form method="post" action="{{ route('documents.store') }}" class="card">@csrf<input type="hidden" name="request_key" value="{{ old('request_key',$requestKey) }}">
<div class="grid">
<div class="field">
<label for="remitente">Remitente</label>
<input id="remitente" name="remitente" maxlength="150" required value="{{ old('remitente') }}">
</div>
<div class="field">
<label for="fecha">Fecha de recepción</label>
<input id="fecha" name="fecha" type="date" required value="{{ old('fecha',now('America/La_Paz')->format('Y-m-d')) }}">
</div>
</div>
<div class="field">
<label for="asunto">Asunto</label>
<textarea id="asunto" name="asunto" maxlength="500" required rows="3">{{ old('asunto') }}</textarea>
</div>
<div class="grid">
<div class="field">
<label for="tipo_id">Tipo de documento</label>
<select name="tipo_id" id="tipo_id" required>
<option value="">Selecciona un tipo</option>@foreach($types as $item)<option value="{{ $item->id }}" @selected(old('tipo_id')==$item->id)>{{ $item->name }}</option>@endforeach</select>
</div>
<div class="field">
<label for="prioridad_id">Prioridad</label>
<select name="prioridad_id" id="prioridad_id" required>
<option value="">Selecciona una prioridad</option>@foreach($priorities as $item)<option value="{{ $item->id }}" @selected(old('prioridad_id')==$item->id)>{{ $item->name }}</option>@endforeach</select>
</div>
</div>
<div class="field">
<label for="unidad_id">Unidad de registro</label>
<select name="unidad_id" id="unidad_id" required>
<option value="">Selecciona una unidad</option>@foreach($units as $item)<option value="{{ $item->id }}" @selected(old('unidad_id')==$item->id)>{{ $item->name }}</option>@endforeach</select>
<small class="muted">El responsable inicial es el usuario que registra. La derivación a otra unidad corresponde al siguiente recorrido.</small>
</div>
<button>Guardar documento y hoja</button> <a class="button secondary" href="{{ route('documents.index') }}">Volver</a>
</form>@endsection
