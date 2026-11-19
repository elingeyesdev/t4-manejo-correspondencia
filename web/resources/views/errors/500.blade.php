@extends('layout')
@section('title','No se pudo completar la operación')
@section('content')<section class="note-section">
<span class="note-state">500</span>
<h1>No se pudo completar la operación</h1>
<p>Comprueba el listado antes de reintentar. Si el problema continúa, informa al administrador.</p>
<a class="btn btn-outline-secondary" href="{{ route('documents.index') }}">Volver a documentos</a>
</section>@endsection
