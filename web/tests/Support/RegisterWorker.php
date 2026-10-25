<?php

use App\Models\User;
use App\Services\RegisterDocument;
use Illuminate\Contracts\Console\Kernel;

if (getenv('DB_DATABASE') !== 'correspondencia_test') {
    fwrite(STDERR, 'Solo base de pruebas.');
    exit(2);
}
$root = dirname(__DIR__, 2);
require $root.'/vendor/autoload.php';
$app = require $root.'/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();
$input = json_decode(base64_decode($argv[2]), true, 512, JSON_THROW_ON_ERROR);
$gate = $argv[3];
file_put_contents($gate.'/ready-'.getmypid(), 'ready');
$deadline = microtime(true) + 12;
while (! file_exists($gate.'/go')) {
    if (microtime(true) > $deadline) {
        exit(3);
    } usleep(10000);
}
try {
    [$doc,$created] = $app->make(RegisterDocument::class)->execute(User::findOrFail((int) $argv[1]), $input);
    echo json_encode(['id' => $doc->id, 'created' => $created], JSON_THROW_ON_ERROR);
} catch (Throwable $e) {
    fwrite(STDERR, get_class($e).': '.$e->getMessage());
    exit(1);
}
