<?php
use App\Models\Catalog;
use App\Models\User;
use App\Models\Unit;
use App\Services\RegisterDocument;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

$root = getenv('LARAVEL_ADJUNTOS_BACKEND');
require $root.'/vendor/autoload.php';
$app = require $root.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();
if (config('database.default') !== 'pgsql' ||
    !in_array(config('database.connections.pgsql.host'), ['127.0.0.1', 'localhost'], true) ||
    DB::selectOne('select current_database() as db')->db !== 'correspondencia_test') {
    throw new RuntimeException('Solo se permite correspondencia_test en PostgreSQL local.');
}
$stateFile = getenv('RECORRIDO_FIXTURE_STATE');
$op = $argv[1];
if ($op === 'crear') {
    $kernel->call('migrate', ['--force' => true]);
    $kernel->call('db:seed', ['--force' => true]);
    $state = DB::transaction(function () {
        $suffix = strtoupper(Str::random(10));
        $units = [];
        $users = [];
        $tokens = [];
        foreach (['origen', 'destino', 'ajena'] as $name) {
            $unit = Unit::create([
                'institution_id' => DB::table('institutions')->value('id'),
                'code' => 'R'.$suffix.strtoupper($name),
                'name' => 'Recorrido '.$name.' '.$suffix, 'enabled' => true,
            ]);
            $units[$name] = $unit->id;
            $user = User::create([
                'name' => 'Recorrido '.$name, 'email' => strtolower($suffix.$name).'@example.test',
                'password' => Str::random(32), 'unit_id' => $unit->id,
                'role' => $name === 'origen' ? 'recepcion' : 'funcionario', 'enabled' => true,
            ]);
            $users[$name] = $user->id;
            $tokens[$name] = $user->createToken('recorrido-flutter')->plainTextToken;
            if ($name === 'origen') $actor = $user;
        }
        [$document] = app(RegisterDocument::class)->execute($actor, [
            'remitente' => 'Persona ficticia', 'asunto' => 'Recorrido Flutter '.$suffix,
            'fecha' => '2026-11-10', 'tipo_id' => Catalog::where('kind', 'tipo')->firstOrFail()->id,
            'prioridad_id' => Catalog::where('kind', 'prioridad')->firstOrFail()->id,
            'unidad_id' => $units['origen'], 'request_key' => (string) Str::uuid(),
        ]);
        return ['unidades' => $units, 'usuarios' => $users, 'tokens' => $tokens,
            'documento' => $document->id, 'hoja' => $document->sheet->id];
    });
    file_put_contents($stateFile, json_encode(array_diff_key($state, ['tokens' => true])));
    echo json_encode($state);
} elseif ($op === 'verificar') {
    $state = json_decode(file_get_contents($stateFile), true, 512, JSON_THROW_ON_ERROR);
    $sheet = DB::table('route_sheets')->where('id', $state['hoja'])->first();
    echo json_encode([
        'estado' => $sheet->state, 'version' => $sheet->version,
        'responsable' => $sheet->responsible_id,
        'movimientos' => DB::table('movements')->where('route_sheet_id', $sheet->id)->orderBy('sheet_version')->pluck('action')->all(),
        'adjuntos' => DB::table('attachments')->where('document_id', $state['documento'])->count(),
    ]);
} elseif ($op === 'limpiar' && file_exists($stateFile)) {
    $state = json_decode(file_get_contents($stateFile), true, 512, JSON_THROW_ON_ERROR);
    DB::transaction(function () use ($state) {
        $users = array_values($state['usuarios']);
        DB::table('personal_access_tokens')->where('tokenable_type', User::class)->whereIn('tokenable_id', $users)->delete();
        DB::table('audits')->whereIn('actor_id', $users)->delete();
        DB::table('requests')->whereIn('actor_id', $users)->delete();
        DB::table('movements')->where('route_sheet_id', $state['hoja'])->delete();
        DB::table('attachments')->where('document_id', $state['documento'])->delete();
        DB::table('route_sheets')->where('id', $state['hoja'])->delete();
        DB::table('documents')->where('id', $state['documento'])->delete();
        DB::table('users')->whereIn('id', $users)->delete();
        DB::table('units')->whereIn('id', array_values($state['unidades']))->delete();
    });
    unlink($stateFile);
    echo '{}';
}
