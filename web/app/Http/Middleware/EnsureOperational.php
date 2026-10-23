<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class EnsureOperational
{
    public function handle(Request $request, Closure $next)
    {
        $user = $request->user();
        $version = $request->hasSession() ? $request->session()->get('auth_version') : null;
        if (! $user->isOperational() || ($version !== null && (int) $version !== $user->auth_version)) {
            if ($request->hasSession()) {
                Auth::guard('web')->logout();
                $request->session()->invalidate();
                $request->session()->regenerateToken();
            }
            abort(403, 'La cuenta o su unidad no están habilitadas, o sus permisos cambiaron. Inicie sesión nuevamente.');
        }

        return $next($request);
    }
}
