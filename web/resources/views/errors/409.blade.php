@extends('layout')
@section('title','Solicitud en conflicto')
@section('content')<section class="card">
<span class="pill">409</span>
<h1>Solicitud en conflicto</h1>
<p>La clave de solicitud ya fue utilizada con otros datos. Comprueba el registro antes de reintentar.</p>
<a class="button" href="{{ route('documents.index') }}">Volver a documentos</a>
</section>@endsection
