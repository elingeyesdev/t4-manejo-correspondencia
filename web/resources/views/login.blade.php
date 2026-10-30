<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">

    <title>Acceso · Gestión documental</title>

    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body>
    @php
        $loginProps = [
            'action' => route('login'),
            'csrfToken' => csrf_token(),
            'initialEmail' => old('email', ''),
            'errors' => $errors->all(),
        ];
    @endphp

    <div
        id="login-form"
        data-props="{{ json_encode($loginProps, JSON_UNESCAPED_SLASHES) }}"
    ></div>
</body>
</html>