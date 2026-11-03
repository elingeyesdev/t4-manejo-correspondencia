<?php

// Respaldo operativo local del #18. Ejecutar desde la raiz del repositorio.
// --comprobar no crea respaldos; --crear requiere detener los escritores web/CLI.

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Encryption\Encrypter;

$root = dirname(__DIR__);
$pdo = null;

try {
    if (! in_array($argv[1] ?? '', ['--comprobar', '--crear'], true) || $argc !== 2) {
        throw new RuntimeException('Uso: php scripts/respaldar-adjuntos-local.php --comprobar|--crear');
    }

    require $root.'/web/vendor/autoload.php';
    if (is_file($root.'/web/bootstrap/cache/config.php')) {
        throw new RuntimeException('Ejecute php web/artisan config:clear antes del respaldo.');
    }
    $app = require $root.'/web/bootstrap/app.php';
    $app->make(Kernel::class)->bootstrap();
    if (config('database.default') !== 'pgsql') {
        throw new RuntimeException('Este procedimiento requiere PostgreSQL.');
    }
    $db = config('database.connections.pgsql');
    if (! in_array($db['host'], ['127.0.0.1', 'localhost', '::1'], true) || ! empty($db['url'])) {
        throw new RuntimeException('Se admite solo la conexion PostgreSQL local sin URL alternativa.');
    }
    if ($db['database'] !== 'correspondencia') {
        throw new RuntimeException('La base origen esperada es correspondencia.');
    }

    $pointerPath = $root.'/.local/recuperacion-18/lote-actual.json';
    $pointer = json_decode(file_get_contents($pointerPath), true, 512, JSON_THROW_ON_ERROR);
    $batch = realpath($pointer['directorio']);
    $parent = realpath($root.'/.local/recuperacion-18');
    if ($batch === false || $parent === false || dirname($batch) !== $parent
        || ! preg_match('/^[a-f0-9]{32}$/', basename($batch))
        || empty($pointer['permisos_verificados']) || empty($pointer['excluido_de_git'])) {
        throw new RuntimeException('El lote privado no coincide con el directorio preparado.');
    }
    foreach (['datos', 'adjuntos', 'claves'] as $directory) {
        if (realpath($batch.'/'.$directory) !== $batch.DIRECTORY_SEPARATOR.$directory) {
            throw new RuntimeException('Falta una carpeta del lote o existe una redireccion no prevista.');
        }
    }
    $manifestPath = $batch.'/manifiesto.json';
    if (is_file($manifestPath) || is_file($batch.'/datos/base.dump') || is_file($batch.'/claves/cifrado.json')) {
        throw new RuntimeException('El lote ya contiene un respaldo o un intento previo; no se sobrescribe.');
    }

    $pgBin = getenv('PG_BIN') ?: dirname($root).'/.tools/postgresql16/bin';
    $pgDump = $pgBin.'/pg_dump.exe';
    if (! is_file($pgDump)) {
        throw new RuntimeException('No se encontro pg_dump. Configure PG_BIN con su carpeta.');
    }
    $pdo = new PDO(
        'pgsql:host='.$db['host'].';port='.$db['port'].';dbname='.$db['database'].';connect_timeout=3',
        $db['username'], $db['password'], [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    $actualDatabase = $pdo->query('SELECT current_database()')->fetchColumn();
    $rows = $pdo->query('SELECT id, document_id, storage_path, key_version, size_bytes FROM attachments ORDER BY id')->fetchAll(PDO::FETCH_ASSOC);
    if ($actualDatabase !== 'correspondencia' || $rows === []) {
        throw new RuntimeException('La base origen no coincide o no contiene adjuntos para comprobar recuperacion.');
    }
    $cipher = config('attachments.cipher');
    $keys = config('attachments.keys');
    $encrypters = [];
    foreach (array_unique(array_column($rows, 'key_version')) as $version) {
        $encoded = $keys[$version] ?? '';
        $decoded = str_starts_with($encoded, 'base64:') ? base64_decode(substr($encoded, 7), true) : false;
        if ($decoded === false || ! Encrypter::supported($decoded, $cipher)) {
            throw new RuntimeException('Falta una clave valida para una version usada por los adjuntos.');
        }
        $encrypters[$version] = new Encrypter($decoded, $cipher);
    }
    if (! is_string(config('app.key')) || config('app.key') === '') {
        throw new RuntimeException('APP_KEY no esta configurada.');
    }
    $storage = realpath(config('filesystems.disks.attachments.root'));
    if ($storage === false || config('attachments.disk') !== 'attachments'
        || config('filesystems.disks.attachments.driver') !== 'local') {
        throw new RuntimeException('Se requiere el disco local privado de adjuntos.');
    }
    foreach ($rows as $row) {
        $path = str_replace('\\', '/', $row['storage_path']);
        if (! preg_match('~^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+\.enc$~', $path)
            || str_contains($path, '..') || ! is_file($storage.'/'.$path) || is_link($storage.'/'.$path)) {
            throw new RuntimeException('Un archivo referenciado falta o tiene una ruta no prevista.');
        }
    }
    echo 'Conexion local comprobada; adjuntos disponibles: '.count($rows).".\n";
    echo "Lote privado comprobado; claves presentes sin mostrar sus valores.\n";
    $canCreateDatabase = $pdo->query('SELECT rolcreatedb OR rolsuper FROM pg_roles WHERE rolname = current_user')->fetchColumn();
    echo 'Permiso para crear base aislada: '.($canCreateDatabase ? 'si' : 'no').".\n";
    if ($argv[1] === '--comprobar') {
        exit(0);
    }

    $webSocket = @fsockopen('127.0.0.1', 8000, $socketError, $socketMessage, 1);
    if (is_resource($webSocket)) {
        fclose($webSocket);
        throw new RuntimeException('Detenga el servidor web y otros escritores antes del respaldo.');
    }
    $pdo->beginTransaction();
    $pdo->exec('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY');
    $snapshot = $pdo->query('SELECT pg_export_snapshot()')->fetchColumn();
    $rows = $pdo->query('SELECT id, document_id, storage_path, key_version, size_bytes FROM attachments ORDER BY id')->fetchAll(PDO::FETCH_ASSOC);
    $counts = [];
    $tables = $pdo->query("SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename")->fetchAll(PDO::FETCH_COLUMN);
    foreach ($tables as $table) {
        $counts[$table] = (int) $pdo->query('SELECT count(*) FROM public."'.str_replace('"', '""', $table).'"')->fetchColumn();
    }
    $files = [];
    $iterator = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($storage, FilesystemIterator::SKIP_DOTS));
    foreach ($iterator as $file) {
        if ($file->isLink()) {
            throw new RuntimeException('No se admiten enlaces dentro del almacenamiento respaldado.');
        }
        if (! $file->isFile() || $file->getFilename() === '.gitignore') {
            continue;
        }
        $relative = str_replace('\\', '/', substr($file->getPathname(), strlen($storage) + 1));
        if (! preg_match('~^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+\.enc$~', $relative) || str_contains($relative, '..')) {
            throw new RuntimeException('Se encontro un archivo fuera del formato privado esperado.');
        }
        $destination = $batch.'/adjuntos/'.$relative;
        if (! is_dir(dirname($destination)) && ! mkdir(dirname($destination), 0700, true)) {
            throw new RuntimeException('No se pudo crear una carpeta de archivos.');
        }
        if (file_exists($destination) || ! copy($file->getPathname(), $destination)) {
            throw new RuntimeException('No se pudo copiar un archivo sin sobrescribir.');
        }
        $files[$relative] = hash_file('sha256', $destination);
        if (! hash_equals(hash_file('sha256', $file->getPathname()), $files[$relative])) {
            throw new RuntimeException('El archivo copiado difiere del original.');
        }
    }
    $attachments = [];
    foreach ($rows as $row) {
        $content = $encrypters[$row['key_version']]->decryptString(file_get_contents($batch.'/adjuntos/'.$row['storage_path']));
        if (strlen($content) !== (int) $row['size_bytes']) {
            throw new RuntimeException('El contenido descifrado no coincide con el tamano registrado.');
        }
        $attachments[] = ['id' => $row['id'], 'document_id' => $row['document_id'], 'storage_path' => $row['storage_path'],
            'key_version' => $row['key_version'], 'size_bytes' => (int) $row['size_bytes'], 'sha256_original' => hash('sha256', $content)];
        unset($content);
    }
    $secrets = ['app_key' => config('app.key'), 'app_previous_keys' => config('app.previous_keys', []),
        'cipher' => $cipher, 'active_key_version' => config('attachments.active_key_version'), 'keys' => $keys];
    $secretHandle = fopen($batch.'/claves/cifrado.json', 'x');
    if ($secretHandle === false) {
        throw new RuntimeException('No se pudo crear el respaldo de claves.');
    }
    $secretJson = json_encode($secrets, JSON_THROW_ON_ERROR | JSON_PRETTY_PRINT);
    if (fwrite($secretHandle, $secretJson) !== strlen($secretJson)) {
        fclose($secretHandle);
        throw new RuntimeException('El respaldo de claves quedo incompleto.');
    }
    fclose($secretHandle);
    unset($secrets, $secretJson);

    $dumpPath = $batch.'/datos/base.dump';
    $command = [$pgDump, '--host='.$db['host'], '--port='.$db['port'], '--username='.$db['username'], '--dbname='.$db['database'],
        '--format=custom', '--no-owner', '--no-acl', '--no-password', '--lock-wait-timeout=5s', '--snapshot='.$snapshot, '--file='.$dumpPath];
    $environment = getenv();
    $environment['PGPASSWORD'] = $db['password'];
    $environment['PGCONNECT_TIMEOUT'] = '5';
    $process = proc_open($command, [0 => ['pipe', 'r'], 1 => ['file', $batch.'/datos/pg_dump.log', 'a'], 2 => ['file', $batch.'/datos/pg_dump.log', 'a']], $pipes, $root, $environment);
    if (! is_resource($process)) {
        throw new RuntimeException('No se pudo iniciar pg_dump.');
    }
    fclose($pipes[0]);
    if (proc_close($process) !== 0 || ! is_file($dumpPath) || filesize($dumpPath) === 0) {
        throw new RuntimeException('pg_dump fallo; consulte el registro privado del lote.');
    }
    $pdo->rollBack();
    $manifest = ['schema' => 1, 'database' => $actualDatabase, 'table_counts' => $counts,
        'dump_sha256' => hash_file('sha256', $dumpPath), 'files_sha256' => $files, 'attachments' => $attachments,
        'php_version' => PHP_VERSION, 'completed_at_utc' => gmdate('c')];
    if (file_put_contents($manifestPath, json_encode($manifest, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR)) === false) {
        throw new RuntimeException('No se pudo guardar el manifiesto de integridad.');
    }
    $pointer['respaldo_creado'] = true;
    if (file_put_contents($pointerPath, json_encode($pointer, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR)) === false) {
        throw new RuntimeException('El respaldo se creo, pero no se pudo actualizar la referencia del lote.');
    }
    echo 'Respaldo completado: '.count($rows).' adjuntos, '.count($files).' archivos cifrados y '.count($counts)." tablas.\n";
    echo "Base en formato pg_dump custom; archivos y claves originales guardados en el lote privado.\n";
    echo "La base habitual solo se consulto; no se modificaron registros.\n";
} catch (Throwable $error) {
    if ($pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    fwrite(STDERR, 'No se completo el respaldo: '.$error->getMessage()."\n");
    exit(1);
}
