@extends('layout')
@section('title','La sesión venció')
@section('content')<section class="note-section">
<span class="note-state">419</span>
<h1>La sesión venció</h1>
<p>Vuelve a iniciar sesión y verifica el listado antes de repetir un registro.</p>
<a class="btn btn-outline-secondary" href="{{ route('documents.index') }}">Volver a documentos</a>
</section>@endsection
