@extends('layout')
@section('title','Solicitud en conflicto')
@section('content')<section class="note-section">
<span class="note-state">409</span>
<h1>Solicitud en conflicto</h1>
<p>La clave de solicitud ya fue utilizada con otros datos. Comprueba el registro antes de reintentar.</p>
<a class="btn btn-outline-secondary" href="{{ route('documents.index') }}">Volver a documentos</a>
</section>@endsection
