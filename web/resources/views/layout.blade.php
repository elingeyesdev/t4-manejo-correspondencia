<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>@yield('title','Correspondencia') · Gestión documental</title>
<link rel="stylesheet" href="{{ asset('css/app.css') }}">
</head>
<body>
<header>
<a href="{{ route('documents.index') }}">
<strong>Correspondencia</strong>
<br>
<small>Gestión documental institucional</small>
</a>
@auth<nav>
<a href="{{ route('documents.index') }}">Documentos</a>@if(auth()->user()->isAdmin())<a href="{{ route('admin') }}">Administración</a>@endif<span>{{ auth()->user()->name }}</span>
<form method="post" action="{{ route('logout') }}">@csrf<button>Salir</button>
</form>
</nav>@endauth</header>
<main>@if(session('status'))<div class="notice" role="status">{{ session('status') }}</div>@endif
@if($errors->any())<div class="errors" role="alert">
<strong>Revisa los datos:</strong>
<ul>@foreach($errors->all() as $error)<li>{{ $error }}</li>@endforeach</ul>
</div>@endif
@yield('content')</main>
<footer>Sistema de correspondencia · Registro y trazabilidad institucional</footer>
</body>
</html>
