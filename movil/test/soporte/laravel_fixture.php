<?php

// Exclusivo para las pruebas Flutter: nunca acepta la base de desarrollo.
require dirname(__DIR__, 3).'/web/vendor/autoload.php';
$app = require dirname(__DIR__, 3).'/web/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
if (config('database.default') !== 'pgsql' || config('database.connections.pgsql.database') !== 'correspondencia_test') {
    throw new RuntimeException('La prueba requiere PostgreSQL y la base correspondencia_test.');
}
$action = $argv[1] ?? '';
$email = getenv('FLUTTER_TEST_EMAIL');
if (! $email || ! str_ends_with($email, '@flutter.example.test')) {
    throw new RuntimeException('Cuenta de prueba no válida.');
}
if ($action === 'crear') {
    Illuminate\Support\Facades\Artisan::call('migrate', ['--force' => true]);
    Illuminate\Support\Facades\Artisan::call('db:seed', ['--force' => true]);
    $base = App\Models\Unit::first();
    $unit = App\Models\Unit::create(['institution_id' => $base->institution_id, 'code' => 'F'.bin2hex(random_bytes(8)), 'name' => 'Flutter '.bin2hex(random_bytes(8))]);
    App\Models\User::create(['name' => 'Recepción Flutter', 'email' => $email, 'password' => getenv('FLUTTER_TEST_PASSWORD'), 'unit_id' => $unit->id, 'role' => 'recepcion', 'enabled' => true]);
    echo json_encode(['creado' => true]);
} elseif ($action === 'verificar') {
    $user = App\Models\User::where('email', $email)->firstOrFail();
    $doc = App\Models\Document::where('created_by', $user->id)->sole();
    echo json_encode(['documento' => $doc->payload(), 'documentos' => App\Models\Document::where('created_by', $user->id)->count(), 'movimientos' => $doc->sheet->movements()->count(), 'solicitudes' => Illuminate\Support\Facades\DB::table('requests')->where('actor_id', $user->id)->count()]);
} elseif ($action === 'limpiar') {
    $user = App\Models\User::where('email', $email)->first();
    if ($user) {
        Illuminate\Support\Facades\DB::transaction(function () use ($user) {
            $docs = App\Models\Document::where('created_by', $user->id)->pluck('id');
            $sheets = Illuminate\Support\Facades\DB::table('route_sheets')->whereIn('document_id', $docs)->pluck('id');
            Illuminate\Support\Facades\DB::table('requests')->where('actor_id', $user->id)->delete();
            Illuminate\Support\Facades\DB::table('audits')->where('actor_id', $user->id)->delete();
            Illuminate\Support\Facades\DB::table('movements')->whereIn('route_sheet_id', $sheets)->delete();
            Illuminate\Support\Facades\DB::table('route_sheets')->whereIn('id', $sheets)->delete();
            App\Models\Document::whereIn('id', $docs)->delete();
            $unit = $user->unit_id;
            $user->tokens()->delete();
            $user->delete();
            App\Models\Unit::whereKey($unit)->delete();
        });
    }
    echo json_encode(['limpio' => true]);
} else {
    throw new RuntimeException('Operación no válida.');
}
