@extends('layout')
@section('title','Acceso no autorizado')
@section('content')<section class="card">
<span class="pill">403</span>
<h1>Acceso no autorizado</h1>
<p>Tu cuenta no tiene permiso para esta operación. Verifica tu sesión y consulta al administrador.</p>
<a class="button" href="{{ route('documents.index') }}">Volver a documentos</a>
</section>@endsection
