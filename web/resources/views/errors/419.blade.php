@extends('layout')
@section('title','La sesión venció')
@section('content')<section class="card">
<span class="pill">419</span>
<h1>La sesión venció</h1>
<p>Vuelve a iniciar sesión y verifica el listado antes de repetir un registro.</p>
<a class="button" href="{{ route('documents.index') }}">Volver a documentos</a>
</section>@endsection
