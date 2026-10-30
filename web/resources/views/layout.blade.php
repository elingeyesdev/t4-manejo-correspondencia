<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">

    <title>@yield('title', 'Correspondencia') · Gestión documental</title>

    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body>
    @php
        $sakaiContext = [
            'authenticated' => auth()->check(),
            'userName' => auth()->user()?->name ?? '',
            'isAdmin' => auth()->user()?->isAdmin() ?? false,
            'canRegister' => auth()->user()?->canRegister() ?? false,
            'documentsUrl' => route('documents.index'),
            'createUrl' => route('documents.create'),
            'adminUrl' => route('admin'),
            'logoutUrl' => route('logout'),
            'csrfToken' => csrf_token(),
        ];
    @endphp

    <div
        id="sakai-app"
        data-context="{{ json_encode($sakaiContext) }}"
    ></div>

    <main id="laravel-content" class="w-full">
        @if(session('status'))
            <div
                class="notice mb-4 p-4 rounded-border bg-primary-50 text-primary-900"
                role="status"
            >
                {{ session('status') }}
            </div>
        @endif

        @if($errors->any())
            <div
                class="errors mb-4 p-4 rounded-border bg-red-50 text-red-900"
                role="alert"
            >
                <strong>Revisa los datos:</strong>
                <ul class="list-disc pl-5">
                    @foreach($errors->all() as $error)
                        <li>{{ $error }}</li>
                    @endforeach
                </ul>
            </div>
        @endif

        @yield('content')
    </main>
</body>
</html>
