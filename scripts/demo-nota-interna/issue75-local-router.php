<?php

use Illuminate\Http\Request;

$web = dirname(__DIR__, 2).'/web';
$public = realpath($web.'/public');
$path = urldecode(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?: '/');
$asset = realpath($public.$path);
if ($asset && str_starts_with($asset, $public.DIRECTORY_SEPARATOR) && is_file($asset) && ! str_ends_with(strtolower($asset), '.php')) {
    return false;
}

define('LARAVEL_START', microtime(true));
require $web.'/vendor/autoload.php';
require __DIR__.'/issue75-local-camunda.php';
$app = require $web.'/bootstrap/app.php';
$app->booted(function () use ($app): void {
    if (! $app->environment('local') || config('database.default') !== 'sqlite'
        || config('camunda.url') !== 'http://camunda.local.test/v2') {
        throw new LogicException('El motor simulado solo se habilita en la instancia local SQLite.');
    }
    issue75SimulateCamunda();
});
$app->handleRequest(Request::capture());
