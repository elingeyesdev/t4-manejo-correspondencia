@extends('layout')
@section('title','Acceso')
@section('content')<section class="card login">
<span class="pill">ACCESO INSTITUCIONAL</span>
<h1>Iniciar sesión</h1>
<p class="muted">Ingresa con tu cuenta para consultar los documentos de tu unidad.</p>
<form method="post" action="/acceso">@csrf<div class="field">
<label for="email">Correo electrónico</label>
<input id="email" type="email" name="email" value="{{ old('email') }}" required autocomplete="username" autofocus>
</div>
<div class="field">
<label for="password">Contraseña</label>
<input id="password" type="password" name="password" required autocomplete="current-password">
</div>
<button>Ingresar</button>
</form>
</section>@endsection
