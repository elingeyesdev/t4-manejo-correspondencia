<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class SessionController extends Controller
{
    public function create()
    {
        return view('login');
    }

    public function store(Request $r)
    {
        $data = $r->validate(['email' => 'required|email', 'password' => 'required|string']);
        if (! Auth::attempt($data)) {
            throw ValidationException::withMessages(['email' => 'Las credenciales no son válidas.']);
        }
        if (! $r->user()->isOperational()) {
            Auth::logout();
            throw ValidationException::withMessages(['email' => 'La cuenta o su unidad no están habilitadas.']);
        }
        $r->session()->regenerate();
        $r->session()->put('auth_version', $r->user()->auth_version);

        return redirect()->intended(route('documents.index'));
    }

    public function destroy(Request $r)
    {
        Auth::guard('web')->logout();
        $r->session()->invalidate();
        $r->session()->regenerateToken();

        return redirect()->route('login');
    }

    public function token(Request $r)
    {
        $data = $r->validate(['email' => 'required|email', 'password' => 'required|string', 'device_name' => 'required|string|max:80']);
        $user = User::where('email', $data['email'])->first();
        if (! $user || ! Hash::check($data['password'], $user->password) || ! $user->isOperational()) {
            throw ValidationException::withMessages(['email' => 'Las credenciales no son válidas o la cuenta no está habilitada.']);
        }

        return response()->json(['token' => $user->createToken($data['device_name'], ['*'], now()->addHours(8))->plainTextToken, 'user' => $user]);
    }

    public function revoke(Request $r)
    {
        $r->user()->currentAccessToken()->delete();

        return response()->noContent();
    }
}
