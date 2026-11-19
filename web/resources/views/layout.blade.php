<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>@yield('title', 'Correspondencia') · Gestión documental</title>
    <link rel="stylesheet" href="{{ asset('vendor/bootstrap-5.3.8/bootstrap.min.css') }}">
    <link rel="stylesheet" href="{{ asset('css/institutional.css') }}">
    <script src="{{ asset('js/institutional.js') }}" defer></script>
</head>
<body>
    <a class="visually-hidden-focusable skip-link" href="#contenido">Saltar al contenido</a>
    <nav class="navbar navbar-expand site-navbar" aria-label="Navegación principal">
        <div class="container site-navbar-inner">
            <a class="navbar-brand" href="{{ route(auth()->check() ? 'documents.index' : 'login') }}">
                <span class="sc-flag" role="img" aria-label="Bandera de Santa Cruz"></span>
                <span>Correspondencia institucional</span>
            </a>
            @auth
                <ul class="navbar-nav">
                    <li class="nav-item"><a @class(['nav-link', 'active' => request()->routeIs('documents.*', 'route-sheets.*')]) @if (request()->routeIs('documents.*', 'route-sheets.*')) aria-current="true" @endif href="{{ route('documents.index') }}">Documentos</a></li>
                    <li class="nav-item"><a @class(['nav-link', 'active' => request()->routeIs('notes.*')]) @if (request()->routeIs('notes.*')) aria-current="true" @endif href="{{ route('notes.index') }}">Nota Interna</a></li>
                    @if (auth()->user()->canRegister())
                        <li class="nav-item"><a class="nav-link" href="{{ route('documents.create') }}">Registrar</a></li>
                    @endif
                    @if (auth()->user()->isAdmin())
                        <li class="nav-item"><a @class(['nav-link', 'active' => request()->routeIs('admin')]) @if (request()->routeIs('admin')) aria-current="page" @endif href="{{ route('admin') }}">Administración</a></li>
                    @endif
                    <li class="nav-item">
                        <form method="post" action="{{ route('logout') }}">
                            @csrf
                            <button type="submit" class="btn btn-link nav-link" aria-label="Cerrar sesión de {{ auth()->user()->name }}">Cerrar sesión</button>
                        </form>
                    </li>
                </ul>
                <p class="site-account small text-body-secondary mb-0 text-break">
                    {{ auth()->user()->name }}@if (auth()->user()->unit) · {{ auth()->user()->unit->name }}@endif
                </p>
            @endauth
        </div>
    </nav>
    <main class="container institutional-main" id="contenido" tabindex="-1">
        @if (session('status'))
            <div id="operation-status" class="alert notice-success" role="status">{{ session('status') }}</div>
        @endif
        @if (isset($errors) && $errors->any())
            <div class="alert notice-error" role="alert">
                <strong>Revisa los datos del formulario</strong>
                <ul class="mb-0">
                    @foreach ($errors->all() as $error)
                        <li>{{ $error }}</li>
                    @endforeach
                </ul>
            </div>
        @endif
        @yield('content')
    </main>
</body>
</html>
