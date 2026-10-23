@extends('layout')
@section('title','Documentos')
@section('content')<div class="top">
<div>
<span class="pill">BANDEJA DOCUMENTAL</span>
<h1>Correspondencia registrada</h1>
<p class="muted">Documentos dentro de tu alcance de acceso · {{ $documents->total() }} registros</p>
</div>
@if(auth()->user()->canRegister())<a class="button" href="{{ route('documents.create') }}">Registrar correspondencia</a>@endif</div>
<section class="card table-wrap">@if($documents->isEmpty())<h2>Aún no hay documentos</h2>
<p class="muted">Los documentos autorizados para tu unidad aparecerán aquí.</p>@else
<table>
<thead>
<tr>
<th>Documento / guía</th>
<th>Asunto y remitente</th>
<th>Unidad / estado</th>
<th>Consulta</th>
</tr>
</thead>
<tbody>
@foreach($documents as $doc)<tr>
<td class="code">{{ $doc->code }}<br>
<small>{{ $doc->guide }}</small>
</td>
<td>
<strong>{{ $doc->subject }}</strong>
<br>
<span class="muted">{{ $doc->sender }}</span>
</td>
<td>{{ $doc->unit->name }}<br>
<span class="pill">{{ $doc->sheet->state }}</span>
</td>
<td>
<a href="{{ route('documents.show',$doc->id) }}">Ver detalle</a>
</td>
</tr>@endforeach
</tbody>
</table>
<div class="pagination">@if($documents->previousPageUrl())<a href="{{ $documents->previousPageUrl() }}">Anterior</a>@endif<span>Página {{ $documents->currentPage() }} de {{ $documents->lastPage() }}</span>@if($documents->nextPageUrl())<a href="{{ $documents->nextPageUrl() }}">Siguiente</a>@endif</div>@endif</section>@endsection
