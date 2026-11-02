<?php
$root = getenv('LARAVEL_ADJUNTOS_BACKEND');
require $root.'/vendor/autoload.php';
$app = require $root.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();
if (config('database.default') !== 'pgsql' ||
    ! in_array(config('database.connections.pgsql.host'), ['127.0.0.1', 'localhost'], true) ||
    Illuminate\Support\Facades\DB::selectOne('select current_database() as db')->db !== 'correspondencia_test') {
    throw new RuntimeException('Solo se permite PostgreSQL local correspondencia_test.');
}
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Storage;
use App\Models\User;
use App\Models\Unit;
use App\Models\Catalog;
use App\Services\RegisterDocument;
use App\Models\Attachment;
use App\Services\AttachmentCipher;

$stateFile = getenv('ADJUNTOS_FIXTURE_STATE');
$op = $argv[1];
if ($op === 'crear') {
    $kernel->call('migrate', ['--force' => true]);
    $kernel->call('db:seed', ['--force' => true]);
    $suffix = Str::lower(Str::random(12));
    $unit = Unit::create(['institution_id' => DB::table('institutions')->value('id'),
        'code' => 'F'.strtoupper($suffix), 'name' => 'Revisión Flutter '.$suffix, 'enabled' => true]);
    $users=[]; $tokens=[];
    foreach (['recepcion', 'funcionario'] as $role) {
        $u = User::create(['name' => 'Flutter '.$role, 'email' => $role.$suffix.'@example.test',
            'password' => 'SoloFixtureAdjuntos2026', 'unit_id' => $unit->id, 'role' => $role, 'enabled' => true]);
        $users[] = $u->id;
        $tokens[$role] = $u->createToken('prueba-adjuntos')->plainTextToken;
        if ($role === 'recepcion') $actor = $u;
    }
    [$doc] = app(RegisterDocument::class)->execute($actor, ['remitente' => 'Prueba de integración Flutter',
        'asunto' => 'Captura y adjuntos '.$suffix, 'fecha' => '2026-11-02',
        'tipo_id' => Catalog::where('kind','tipo')->firstOrFail()->id,
        'prioridad_id' => Catalog::where('kind','prioridad')->firstOrFail()->id,
        'unidad_id' => $unit->id, 'request_key' => (string) Str::uuid()]);
    $state=['usuarios'=>$users,'unidad'=>$unit->id,'documento'=>$doc->id];
    file_put_contents($stateFile, json_encode($state));
    echo json_encode($state+['tokens'=>$tokens]);
} elseif ($op === 'verificar') {
    $state=json_decode(file_get_contents($stateFile),true,512,JSON_THROW_ON_ERROR);
    $adjunto=Attachment::where('document_id',$state['documento'])->firstOrFail();
    $encrypted=Storage::disk(config('attachments.disk'))->get($adjunto->storage_path);
    $original=file_get_contents($root.'/tests/Fixtures/adjunto.jpg');
    echo json_encode(['cantidad'=>Attachment::where('document_id',$state['documento'])->count(),
      'cifrado'=>$encrypted !== $original,
      'contenido_identico'=>hash_equals(hash('sha256',$original),hash('sha256',app(AttachmentCipher::class)->decrypt($encrypted,$adjunto->key_version)))]);
} elseif ($op === 'limpiar' && file_exists($stateFile)) {
    $state=json_decode(file_get_contents($stateFile),true,512,JSON_THROW_ON_ERROR);
    DB::transaction(function () use ($state) {
        DB::table('personal_access_tokens')->where('tokenable_type',User::class)->whereIn('tokenable_id',$state['usuarios'])->delete();
        DB::table('audits')->whereIn('actor_id',$state['usuarios'])->delete();
        DB::table('requests')->whereIn('actor_id',$state['usuarios'])->delete();
        DB::table('movements')->whereIn('actor_id',$state['usuarios'])->delete();
        DB::table('attachments')->where('document_id',$state['documento'])->delete();
        DB::table('route_sheets')->where('document_id',$state['documento'])->delete();
        DB::table('documents')->where('id',$state['documento'])->delete();
        DB::table('users')->whereIn('id',$state['usuarios'])->delete();
        DB::table('units')->where('id',$state['unidad'])->delete();
    });
    unlink($stateFile);
    echo '{}';
} else { echo '{}'; }
