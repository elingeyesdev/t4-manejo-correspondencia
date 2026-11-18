<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('title') · Correspondencia</title>
    <style>
        :root { font-family: system-ui, sans-serif; color: #202c36; background: #f4f6f8; line-height: 1.5; }
        body { margin: 0; }
        header, main { max-width: 72rem; margin: auto; padding: 1rem; }
        header { border-bottom: 1px solid #c9d1d8; display: flex; gap: 1rem; align-items: baseline; flex-wrap: wrap; }
        a { color: #17466a; }
        a:focus-visible, button:focus-visible, select:focus-visible, input:focus-visible, textarea:focus-visible { outline: 3px solid #23619a; outline-offset: 2px; }
        section, fieldset { background: white; border: 1px solid #c9d1d8; padding: 1rem; margin-block: 1rem; }
        h1 { margin: .2rem 0 1rem; }
        h2 { font-size: 1.2rem; }
        nav, .actions { display: flex; flex-wrap: wrap; align-items: center; gap: 1rem; }
        nav [aria-current] { font-weight: 700; }
        label { display: block; font-weight: 600; }
        input:not([type=hidden]), textarea, select { width: 100%; max-width: 40rem; box-sizing: border-box; font: inherit; padding: .45rem; margin: .2rem 0 .75rem; border: 1px solid #718292; }
        button, .button { display: inline-block; background: #17466a; color: white; border: none; padding: .45rem .75rem; font: inherit; text-decoration: none; cursor: pointer; }
        table { width: 100%; border-collapse: collapse; text-align: left; background: white; }
        td, th { border-bottom: 1px solid #c9d1d8; padding: .7rem; vertical-align: top; }
        th { background: #eaf0f4; }
        .table-scroll { overflow-x: auto; }
        dt { font-weight: 600; }
        dd { margin: 0 0 .6rem; }
        .body { white-space: pre-wrap; overflow-wrap: anywhere; }
        .alert { border-left: 4px solid #9b2929; }
    </style>
</head>
<body>
    <header>
        <strong>Correspondencia institucional</strong>
        <a href="{{ route('documents.index') }}">Documentos</a>
        <a href="{{ route('notes.index') }}">Nota Interna</a>
    </header>
    <main>
        @if (session('status'))
            <section role="status">{{ session('status') }}</section>
        @endif
        @if ($errors->any())
            <section class="alert" role="alert">
                <strong>Revisa los datos del formulario</strong>
                <ul>
                    @foreach ($errors->all() as $error)
                        <li>{{ $error }}</li>
                    @endforeach
                </ul>
            </section>
        @endif
        @yield('content')
    </main>
</body>
</html>
