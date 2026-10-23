<?php

// La base de pruebas es fija y distinta de la base de desarrollo.
$root = dirname(__DIR__);
require $root.'/web/vendor/autoload.php';
$values = Dotenv\Dotenv::parse(file_get_contents($root.'/web/.env'));
foreach (['DB_HOST', 'DB_PORT', 'DB_USERNAME', 'DB_PASSWORD'] as $key) {
    $value = $values[$key] ?? '';
    putenv($key.'='.$value);
    $_ENV[$key] = $value;
    $_SERVER[$key] = $value;
}
foreach (['APP_ENV' => 'testing', 'DB_CONNECTION' => 'pgsql', 'DB_DATABASE' => 'correspondencia_test'] as $key => $value) {
    putenv($key.'='.$value);
    $_ENV[$key] = $value;
    $_SERVER[$key] = $value;
}
chdir($root.'/web');
$clear = proc_open([PHP_BINARY, 'artisan', 'config:clear', '--no-ansi'], [STDIN, STDOUT, STDERR], $pipes);
if (! is_resource($clear) || proc_close($clear) !== 0) {
    exit(1);
}
$process = proc_open([PHP_BINARY, 'artisan', 'test', '--compact', '--no-ansi'], [STDIN, STDOUT, STDERR], $pipes);
if (! is_resource($process) || proc_close($process) !== 0) {
    exit(1);
}
$race = proc_open([PHP_BINARY, 'vendor/phpunit/phpunit/phpunit', 'tests/Postgres', '--colors=never'], [STDIN, STDOUT, STDERR], $pipes);
exit(is_resource($race) ? proc_close($race) : 1);
