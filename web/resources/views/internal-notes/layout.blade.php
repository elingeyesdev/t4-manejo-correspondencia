<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('title') · Correspondencia</title>
    <link rel="stylesheet" href="{{ asset('vendor/bootstrap-5.3.8/bootstrap.min.css') }}">
    <link rel="stylesheet" href="{{ asset('css/internal-notes.css') }}">
</head>
<body>
    <a class="visually-hidden-focusable skip-link" href="#contenido">Saltar al contenido</a>

    <nav class="navbar navbar-expand site-navbar" aria-label="Navegación principal">
        <div class="container site-navbar-inner">
            <a class="navbar-brand" href="{{ route('documents.index') }}">
                <span class="sc-flag" role="img" aria-label="Bandera de Santa Cruz"></span>
                <span>Correspondencia institucional</span>
            </a>
            <ul class="navbar-nav">
                <li class="nav-item"><a class="nav-link" href="{{ route('documents.index') }}">Documentos</a></li>
                <li class="nav-item"><a class="nav-link active" aria-current="true" href="{{ route('notes.index') }}">Nota Interna</a></li>
            </ul>
        </div>
    </nav>

    <main class="container notes-main" id="contenido" tabindex="-1">
        @if (session('status'))
            <div class="alert notice-success" role="status">{{ session('status') }}</div>
        @endif
        @if ($errors->any())
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
