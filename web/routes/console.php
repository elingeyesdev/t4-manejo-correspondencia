<?php

use App\Models\Unit;
use App\Models\User;
use App\Services\DeliverNoteNotices;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rules\Password;

Artisan::command('correspondencia:administrador', function () {
    $unit = Unit::where('enabled', true)->first();
    if (! $unit) {
        $this->error('Ejecute primero php artisan db:seed.');

        return 1;
    }
    $name = $this->ask('Nombre');
    $email = $this->ask('Correo');
    $password = $this->secret('Contraseña (mínimo 12 caracteres, letras y números)');
    $confirm = $this->secret('Repita la contraseña');
    $v = Validator::make(['name' => $name, 'email' => $email, 'password' => $password, 'password_confirmation' => $confirm],
        ['name' => 'required|string|max:150', 'email' => 'required|email|unique:users,email', 'password' => ['required', 'confirmed', Password::min(12)->letters()->numbers()]]);
    if ($v->fails()) {
        foreach ($v->errors()->all() as $e) {
            $this->error($e);
        }

        return 1;
    }
    User::create(['name' => $name, 'email' => $email, 'password' => $password, 'role' => 'administrador', 'unit_id' => $unit->id, 'enabled' => true]);
    $this->info('Administrador creado. La contraseña no se guarda en archivos ni se muestra.');

    return 0;
})->purpose('Crear el administrador inicial con contraseña privada');

Artisan::command('correspondencia:enviar-avisos', function (DeliverNoteNotices $deliveries): void {
    $this->info('Avisos procesados: '.$deliveries->run());
})->purpose('Procesar avisos de Nota Interna pendientes de envío');

Schedule::command('correspondencia:enviar-avisos')
    ->everySecond()
    ->withoutOverlapping(5)
    ->when(fn () => (bool) config('fcm.project_id'));
