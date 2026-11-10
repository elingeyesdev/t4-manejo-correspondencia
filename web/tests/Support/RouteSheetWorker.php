<?php

use App\Models\User;
use App\Services\RouteSheetWorkflow;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

if (getenv('DB_DATABASE') !== 'correspondencia_test') {
    fwrite(STDERR, 'Solo base de pruebas.');
    exit(2);
}

$root = dirname(__DIR__, 2);
require $root.'/vendor/autoload.php';
$app = require $root.'/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

$input = json_decode(base64_decode($argv[2]), true, 512, JSON_THROW_ON_ERROR);
$actor = User::findOrFail((int) $argv[1]);
$gate = $argv[3];
file_put_contents($gate.'/ready-'.getmypid(), 'ready');
$deadline = microtime(true) + 12;

while (! file_exists($gate.'/go')) {
    if (microtime(true) > $deadline) {
        exit(3);
    }
    usleep(10000);
}

try {
    $workflow = $app->make(RouteSheetWorkflow::class);
    [$result, $created] = match ($input['operation']) {
        'derive' => $workflow->derive($actor, $input['sheet_id'], $input['data']),
        'receive' => $workflow->receive($actor, $input['sheet_id'], $input['data']),
    };

    echo json_encode([
        'status' => $created ? 201 : 200,
        'responsible_id' => $result['hoja']['responsable_id'],
    ], JSON_THROW_ON_ERROR);
} catch (ModelNotFoundException) {
    echo json_encode(['status' => 404], JSON_THROW_ON_ERROR);
} catch (HttpExceptionInterface $exception) {
    echo json_encode(['status' => $exception->getStatusCode()], JSON_THROW_ON_ERROR);
}
