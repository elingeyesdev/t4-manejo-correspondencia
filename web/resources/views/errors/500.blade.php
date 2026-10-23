@extends('layout')
@section('title','No se pudo completar la operación')
@section('content')<section class="card">
<span class="pill">500</span>
<h1>No se pudo completar la operación</h1>
<p>Comprueba el listado antes de reintentar. Si el problema continúa, informa al administrador.</p>
<a class="button" href="{{ route('documents.index') }}">Volver a documentos</a>
</section>@endsection
