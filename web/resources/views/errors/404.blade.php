@extends('layout')
@section('title','Registro no disponible')
@section('content')<section class="card">
<span class="pill">404</span>
<h1>Registro no disponible</h1>
<p>El registro no existe o no está disponible para tu cuenta.</p>
<a class="button" href="{{ route('documents.index') }}">Volver a documentos</a>
</section>@endsection
