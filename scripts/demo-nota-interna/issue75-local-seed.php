<?php

use App\Models\Unit;
use App\Models\User;
use App\Services\InternalNoteWorkflow;
use App\Services\ReceiveInternalNote;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

$web = dirname(__DIR__, 2).'/web';
require $web.'/vendor/autoload.php';
$app = require $web.'/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

$institution = DB::table('institutions')->value('id');
$unit = fn (string $code, string $name) => Unit::firstOrCreate(
    ['institution_id' => $institution, 'code' => $code],
    ['name' => $name, 'enabled' => true],
);
$unitAuthor = $unit('SECRETARIA', 'Secretaría de demostración');
$unitVia = $unit('DIRECCION', 'Dirección de demostración');
$unitReceiver = Unit::where('code', 'RECEPCION')->firstOrFail();
require __DIR__.'/issue75-local-identities.php';
$identities = issue75Identities();
$create = function (string $key, Unit $unit) use ($identities) {
    [$email, $name, $role, $password] = $identities[$key];

    return User::create([
        'name' => $name, 'email' => $email, 'password' => $password,
        'unit_id' => $unit->id, 'role' => $role, 'enabled' => true,
    ]);
};
$author = $create('author', $unitAuthor);
$via = $create('via', $unitVia);
$create('admin', $unitAuthor);
$create('reception', $unitReceiver);
$receiver = $create('receiver', $unitReceiver);

require __DIR__.'/issue75-local-camunda.php';
issue75SimulateCamunda();
$flow = app(InternalNoteWorkflow::class);
$inputs = [
    'asunto' => 'Revisión de instalaciones',
    'referencia' => 'Solicitud ficticia de mantenimiento',
    'cuerpo' => implode("\n\n", array_map(fn (int $n) => "Párrafo $n. Se solicita revisar las instalaciones y registrar los hallazgos. Este texto es un ejemplo para comprobar la composición, la lectura y la paginación de una nota interna.", range(1, 16))),
    'destinatario_unidad_id' => $unitReceiver->id,
];
$draft = $flow->save($author, ['asunto' => 'Borrador editable de demostración'] + $inputs);
$stroke = [[[90, 650], [240, 220], [320, 700], [430, 410], [520, 520], [800, 210], [890, 310]]];
$emit = function (array $overrides) use ($flow, $author, $inputs, $stroke) {
    $note = $flow->save($author, $overrides + $inputs);
    $flow->requestSignature($author, $note, $note->version);
    $flow->sign($author, $note, $note->version, (string) Str::uuid(), $stroke);

    return $flow->emit($author, $note, $note->version, (string) Str::uuid());
};
$review = $emit(['asunto' => 'Nota pendiente de revisión VÍA', 'vias_usuario_ids' => [$via->id]]);
$received = $emit(['asunto' => 'Nota con firma y sello RECIBIDO']);
$received = app(ReceiveInternalNote::class)->execute($receiver, $received, $received->version, (string) Str::uuid());
if ($received->receiptStamp() === null) {
    throw new RuntimeException('No se generó la constancia de recepción de prueba.');
}
echo json_encode(['draft' => $draft->id, 'review' => $review->id, 'received' => $received->id, 'cuentas' => $identities], JSON_THROW_ON_ERROR);
