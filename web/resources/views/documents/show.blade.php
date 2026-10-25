@extends('layout')
@section('title','Detalle de correspondencia')
@section('content')<span class="pill">{{ $payload['estado'] }}</span>
<h1>{{ $document->subject }}</h1>
<p class="muted">Documento y hoja de ruta vinculados · Información autorizada</p>
<div class="grid">
<section class="card">
<h2>Documento</h2>
<p class="code">{{ $document->code }}</p>
<p>
<strong>Remitente:</strong> {{ $document->sender }}<br>
<strong>Fecha:</strong> {{ $document->received_on->format('d/m/Y') }}<br>
<strong>Unidad:</strong> {{ $document->unit->name }}<br>
<strong>Tipo:</strong> {{ $document->type->name }}<br>
<strong>Prioridad:</strong> {{ $document->priority->name }}</p>
<strong>Guía de consulta</strong>
<p class="code">{{ $document->guide }}</p>
</section>
<section class="card">
<h2>Hoja de ruta</h2>
<p class="code">{{ $payload['hoja']['codigo'] }}</p>
<p>
<strong>Responsable:</strong> {{ \App\Models\User::find($payload['hoja']['responsable_id'])->name }}<br>
<strong>Estado:</strong> {{ $payload['estado'] }}<br>
<strong>Versión:</strong> {{ $payload['hoja']['version'] }}</p>
<p class="muted">Los identificadores se conservan durante todo el recorrido.</p>
</section>
</div>
<section class="card">
<h2>Historial inicial</h2>
<div class="table-wrap">
<table>
<thead>
<tr>
<th>Acción</th>
<th>Actor</th>
<th>Fecha y hora · Bolivia</th>
<th>Estado</th>
</tr>
</thead>
<tbody>@foreach($document->sheet->movements as $event)<tr>
<td>{{ $event->action }}</td>
<td>{{ \App\Models\User::find($event->actor_id)->name }}</td>
<td>{{ $event->occurred_at->timezone('America/La_Paz')->format('d/m/Y H:i:s') }}</td>
<td>{{ $event->resulting_state }}</td>
</tr>@endforeach</tbody>
</table>
</div>
</section>
<a href="{{ route('documents.index') }}">Volver a documentos</a>@endsection
