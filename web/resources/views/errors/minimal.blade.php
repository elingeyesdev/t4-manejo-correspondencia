@extends('layout')
@section('content')
    <section class="note-section">
        <span class="note-state">@yield('code')</span>
        <h1 class="mt-2">@yield('title')</h1>
        <p class="mt-3">@yield('message')</p>
        <a class="btn btn-outline-secondary" href="{{ auth()->check() ? route('documents.index') : route('login') }}">
            {{ auth()->check() ? 'Volver a documentos' : 'Ir a acceso' }}
        </a>
    </section>
@endsection
