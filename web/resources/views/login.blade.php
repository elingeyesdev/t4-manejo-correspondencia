@extends('layout')
@section('title', 'Acceso')
@section('content')
    <section class="access-panel" aria-labelledby="acceso-titulo">
        <h1 id="acceso-titulo">Acceso al sistema</h1>
        <p class="text-secondary mt-2 mb-4">Inicia sesión con tu cuenta institucional.</p>
        <form method="post" action="{{ route('login') }}" data-institutional-form>
            @csrf
            <div class="mb-3">
                <label for="email" class="form-label">Correo electrónico</label>
                <input id="email" class="form-control @error('email') is-invalid @enderror" type="email"
                    name="email" value="{{ old('email') }}" autocomplete="username" required
                    @error('email') aria-invalid="true" aria-describedby="email-error" @enderror>
                @error('email') <p id="email-error" class="invalid-feedback">{{ $message }}</p> @enderror
            </div>
            <div class="mb-3">
                <label for="password" class="form-label">Contraseña</label>
                <input id="password" class="form-control" type="password" name="password" autocomplete="current-password" required>
            </div>
            <button type="submit" class="btn btn-primary">Ingresar</button>
        </form>
    </section>
@endsection
