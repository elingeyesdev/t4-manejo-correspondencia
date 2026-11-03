<?php

// Verifica la API real en un servidor efimero 127.0.0.1:8001 y base restaurada.
// El mismo archivo actua como router del servidor; no sirve archivos privados.

use App\Models\User;
use GuzzleHttp\Client;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Foundation\Application;
use Illuminate\Http\Request;

function contextoRecuperacion18(string $root): array
{
    $pointer = json_decode(file_get_contents($root.'/.local/recuperacion-18/lote-actual.json'), true, 512, JSON_THROW_ON_ERROR);
    $batch = realpath($pointer['directorio']);
    $parent = realpath($root.'/.local/recuperacion-18');
    if ($batch === false || $parent === false || dirname($batch) !== $parent
        || ! preg_match('/^[a-f0-9]{32}$/', basename($batch)) || empty($pointer['restauracion_creada'])) {
        throw new RuntimeException('No hay un lote restaurado dentro del directorio privado esperado.');
    }
    $runtime = realpath($batch.'/restaurado');
    if ($runtime === false || dirname($runtime) !== $batch) {
        throw new RuntimeException('No se encontro el entorno recuperado.');
    }
    $result = json_decode(file_get_contents($runtime.'/restauracion.json'), true, 512, JSON_THROW_ON_ERROR);
    $database = 'correspondencia_recuperacion18_'.substr(basename($batch), 0, 12);
    if (($result['database'] ?? '') !== $database || ($pointer['base_restaurada'] ?? '') !== $database
        || ! preg_match('/^correspondencia_recuperacion18_[a-f0-9]{12}$/', $database)
        || empty($result['original_keys_restored']) || empty($result['content_sha256_verified'])) {
        throw new RuntimeException('La restauracion no tiene los resultados previos esperados.');
    }
    $manifest = json_decode(file_get_contents($batch.'/manifiesto.json'), true, 512, JSON_THROW_ON_ERROR);
    if (empty($manifest['attachments']) || $result['dump_sha256'] !== $manifest['dump_sha256']) {
        throw new RuntimeException('La evidencia no coincide con el respaldo original.');
    }
    $keyFile = $runtime.'/claves/cifrado.json';
    if (! hash_equals(hash_file('sha256', $batch.'/claves/cifrado.json'), hash_file('sha256', $keyFile))) {
        throw new RuntimeException('Las claves recuperadas no coinciden con las respaldadas.');
    }
    $secrets = json_decode(file_get_contents($keyFile), true, 512, JSON_THROW_ON_ERROR);
    $values = Dotenv\Dotenv::parse(file_get_contents($root.'/web/.env'));
    $host = $values['DB_HOST'] ?? '127.0.0.1';
    if (($values['DB_CONNECTION'] ?? '') !== 'pgsql' || ($values['DB_DATABASE'] ?? '') !== 'correspondencia'
        || ! in_array($host, ['127.0.0.1', 'localhost', '::1'], true) || ! empty($values['DB_URL'])) {
        throw new RuntimeException('La conexion local no coincide con la configuracion del procedimiento.');
    }

    return compact('root', 'batch', 'runtime', 'database', 'manifest', 'result', 'secrets', 'values', 'host');
}

function aplicacionRecuperada18(array $context): Application
{
    $runtime = $context['runtime'];
    $values = $context['values'];
    $secrets = $context['secrets'];
    $environment = ['APP_ENV' => 'local', 'APP_DEBUG' => 'false', 'APP_URL' => 'http://127.0.0.1:8001',
        'APP_KEY' => $secrets['app_key'], 'APP_PREVIOUS_KEYS' => implode(',', $secrets['app_previous_keys'] ?? []),
        'APP_CONFIG_CACHE' => $runtime.'/bootstrap/config.php', 'APP_ROUTES_CACHE' => $runtime.'/bootstrap/routes.php',
        'LARAVEL_STORAGE_PATH' => $runtime.'/storage', 'DB_CONNECTION' => 'pgsql', 'DB_URL' => '',
        'DB_HOST' => $context['host'], 'DB_PORT' => $values['DB_PORT'] ?? '5432', 'DB_DATABASE' => $context['database'],
        'DB_USERNAME' => $values['DB_USERNAME'] ?? '', 'DB_PASSWORD' => $values['DB_PASSWORD'] ?? '',
        'CACHE_STORE' => 'array', 'SESSION_DRIVER' => 'array', 'QUEUE_CONNECTION' => 'sync', 'LOG_CHANNEL' => 'single'];
    if (is_file($environment['APP_CONFIG_CACHE']) || is_file($environment['APP_ROUTES_CACHE'])) {
        throw new RuntimeException('El entorno recuperado no debe usar configuracion o rutas cacheadas.');
    }
    foreach ($environment as $key => $value) {
        putenv($key.'='.$value);
        $_ENV[$key] = $value;
        $_SERVER[$key] = $value;
    }
    $app = require $context['root'].'/web/bootstrap/app.php';
    $app->useStoragePath($runtime.'/storage');
    $app->make(Kernel::class)->bootstrap();
    $app['config']->set('attachments', ['disk' => 'attachments', 'cipher' => $secrets['cipher'],
        'active_key_version' => $secrets['active_key_version'], 'keys' => $secrets['keys']]);
    $app['config']->set('filesystems.disks.attachments.root', $runtime.'/storage/app/private/attachments');
    $app['filesystem']->forgetDisk('attachments');
    $app['db']->purge('pgsql');
    if ($app['config']->get('database.default') !== 'pgsql'
        || $app['config']->get('database.connections.pgsql.database') !== $context['database']
        || $app['db']->connection()->selectOne('SELECT current_database() AS name')->name !== $context['database']) {
        throw new RuntimeException('La aplicacion no esta conectada exclusivamente a la base recuperada.');
    }

    return $app;
}

$root = dirname(__DIR__);
$server = null;
$tokenModel = null;
$failure = null;
$proof = null;

try {
    require $root.'/web/vendor/autoload.php';
    if (PHP_SAPI !== 'cli-server' && (! in_array($argv[1] ?? '', ['--comprobar', '--descargar'], true) || $argc !== 2)) {
        throw new RuntimeException('Uso: php scripts/verificar-restauracion-local.php --comprobar|--descargar');
    }
    $context = contextoRecuperacion18($root);
    $app = aplicacionRecuperada18($context);

    if (PHP_SAPI === 'cli-server') {
        $nonce = getenv('RECUPERACION18_NONCE') ?: '';
        if (! preg_match('/^[a-f0-9]{32}$/', $nonce)) {
            throw new RuntimeException('El servidor efimero no fue iniciado por el verificador.');
        }
        if (parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) === '/_recuperacion18/identidad') {
            header('Content-Type: application/json');
            echo json_encode(['nonce' => $nonce, 'database' => $context['database']], JSON_THROW_ON_ERROR);
        } else {
            $app->handleRequest(Request::capture());
        }
        exit(0);
    }

    foreach ($context['manifest']['files_sha256'] as $relative => $hash) {
        if (! preg_match('~^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+\.enc$~', $relative) || str_contains($relative, '..')
            || ! is_file($context['runtime'].'/storage/app/private/attachments/'.$relative)
            || ! hash_equals($hash, hash_file('sha256', $context['runtime'].'/storage/app/private/attachments/'.$relative))) {
            throw new RuntimeException('El almacenamiento recuperado no conserva los archivos esperados.');
        }
    }
    $user = User::query()->where('role', 'administrador')->where('enabled', true)
        ->whereHas('unit', fn ($query) => $query->where('enabled', true))->orderBy('id')->first();
    if ($user === null) {
        throw new RuntimeException('Falta una cuenta administradora operativa en la base restaurada.');
    }
    $socket = @stream_socket_server('tcp://127.0.0.1:8001', $socketError, $socketMessage);
    if ($socket === false) {
        throw new RuntimeException('El puerto local 8001 esta ocupado; no se contactara otro servidor.');
    }
    fclose($socket);
    echo 'Aplicacion aislada comprobada: '.$context['database'].".\n";
    echo 'Archivos y claves recuperadas comprobados; adjuntos: '.count($context['manifest']['attachments']).".\n";
    if ($argv[1] === '--comprobar') {
        exit(0);
    }

    $verification = $context['runtime'].'/verificacion-'.bin2hex(random_bytes(6));
    if (! mkdir($verification, 0700)) {
        throw new RuntimeException('No se pudo crear la carpeta privada de descargas.');
    }
    $nonce = bin2hex(random_bytes(16));
    $environment = getenv();
    $environment['RECUPERACION18_NONCE'] = $nonce;
    $server = proc_open([PHP_BINARY, '-d', 'memory_limit=256M', '-S', '127.0.0.1:8001', '-t', $root.'/web/public', __FILE__],
        [0 => ['pipe', 'r'], 1 => ['file', $verification.'/servidor.log', 'a'], 2 => ['file', $verification.'/servidor.log', 'a']],
        $pipes, $root, $environment);
    if (! is_resource($server)) {
        throw new RuntimeException('No se pudo iniciar el servidor de verificacion.');
    }
    fclose($pipes[0]);
    $client = new Client(['base_uri' => 'http://127.0.0.1:8001', 'connect_timeout' => 1, 'timeout' => 20,
        'http_errors' => false, 'allow_redirects' => false, 'headers' => ['Accept' => 'application/json']]);
    $ready = false;
    $deadline = microtime(true) + 15;
    do {
        if (! proc_get_status($server)['running']) {
            break;
        }
        try {
            $identity = $client->get('/_recuperacion18/identidad');
            $identityData = json_decode((string) $identity->getBody(), true, 512, JSON_THROW_ON_ERROR);
            $ready = $identity->getStatusCode() === 200 && ($identityData['nonce'] ?? '') === $nonce
                && ($identityData['database'] ?? '') === $context['database'];
        } catch (Throwable) {
            $ready = false;
        }
        if (! $ready) {
            usleep(200000);
        }
    } while (! $ready && microtime(true) < $deadline);
    if (! $ready) {
        throw new RuntimeException('No se pudo comprobar la identidad del servidor aislado; consulte su registro privado.');
    }

    $first = $context['manifest']['attachments'][0];
    $firstUrl = '/api/documentos/'.$first['document_id'].'/adjuntos/'.$first['id'].'/descarga';
    if ($client->get($firstUrl)->getStatusCode() !== 401) {
        throw new RuntimeException('La descarga sin autenticacion no fue rechazada con 401.');
    }
    $issuedToken = $user->createToken('verificacion-recuperacion-18');
    $tokenModel = $issuedToken->accessToken;
    $proofAttachments = [];
    foreach ($context['manifest']['attachments'] as $attachment) {
        if (! preg_match('/^[a-f0-9-]{36}$/i', $attachment['id']) || ! preg_match('/^[a-f0-9-]{36}$/i', $attachment['document_id'])) {
            throw new RuntimeException('Identificador de adjunto no previsto en el manifiesto.');
        }
        $metadata = $app['db']->table('attachments')->where('id', $attachment['id'])->first();
        $download = $verification.'/'.$attachment['id'].'.bin';
        $response = $client->get('/api/documentos/'.$attachment['document_id'].'/adjuntos/'.$attachment['id'].'/descarga',
            ['headers' => ['Authorization' => 'Bearer '.$issuedToken->plainTextToken], 'sink' => $download]);
        if ($response->getStatusCode() !== 200 || $metadata === null
            || $response->getHeaderLine('Content-Type') !== $metadata->mime_type
            || $response->getHeaderLine('X-Content-Type-Options') !== 'nosniff'
            || ! str_contains($response->getHeaderLine('Cache-Control'), 'no-store')
            || filesize($download) !== $attachment['size_bytes']
            || ! hash_equals($attachment['sha256_original'], hash_file('sha256', $download))) {
            throw new RuntimeException('Una descarga autenticada no coincide con el contenido original.');
        }
        $proofAttachments[] = ['id' => $attachment['id'], 'status' => 200, 'size_bytes' => filesize($download),
            'sha256_matches' => true, 'mime_matches' => true];
    }
    $proof = ['database' => $context['database'], 'guest_status' => 401, 'attachments' => $proofAttachments,
        'keys_from_restored_copy' => true, 'isolated_storage' => true, 'transport' => 'HTTP 127.0.0.1:8001',
        'completed_at_utc' => gmdate('c')];
} catch (Throwable $error) {
    $failure = $error->getMessage();
} finally {
    if (is_resource($server)) {
        proc_terminate($server);
        proc_close($server);
    }
    if ($tokenModel !== null) {
        try {
            $tokenModel->delete();
        } catch (Throwable) {
            $failure = 'No se pudo revocar el token efimero de la base restaurada; revise ese entorno antes de continuar.';
        }
    }
}

if (PHP_SAPI === 'cli-server') {
    http_response_code(503);
    header('Content-Type: application/json');
    echo json_encode(['message' => 'El entorno de recuperacion no esta disponible.']);
    exit(0);
}
if ($failure !== null) {
    fwrite(STDERR, 'No se completo la verificacion: '.$failure."\n");
    exit(1);
}
if ($proof !== null) {
    $proof['temporary_token_revoked'] = true;
    $proof['temporary_server_stopped'] = true;
    if (file_put_contents($verification.'/resultado.json', json_encode($proof, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR)) === false) {
        fwrite(STDERR, "Las descargas pasaron, pero no se pudo guardar su evidencia.\n");
        exit(1);
    }
    $result = $context['result'];
    $result['authenticated_download_verified'] = true;
    $result['last_verification_directory'] = $verification;
    if (file_put_contents($context['runtime'].'/restauracion.json', json_encode($result, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR)) === false) {
        fwrite(STDERR, "Las descargas pasaron, pero no se pudo actualizar la referencia de evidencia.\n");
        exit(1);
    }
    echo 'Descargas autenticadas comprobadas: '.count($proof['attachments']).".\n";
    echo "Sin autenticacion: HTTP 401. Con autenticacion: HTTP 200 y SHA-256 original coincidente.\n";
    echo "Token efimero revocado y servidor temporal detenido; base habitual conservada.\n";
}
