@extends('layout')
@section('title','Registro no disponible')
@section('content')<section class="note-section">
<span class="note-state">404</span>
<h1>Registro no disponible</h1>
<p>El registro no existe o no está disponible para tu cuenta.</p>
<a class="btn btn-outline-secondary" href="{{ route('documents.index') }}">Volver a documentos</a>
</section>@endsection
