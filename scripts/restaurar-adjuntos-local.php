<?php

// Restauracion operativa local del #18. Nunca reutiliza ni elimina una base existente.

use Illuminate\Encryption\Encrypter;

$root = dirname(__DIR__);

try {
    if (! in_array($argv[1] ?? '', ['--comprobar', '--restaurar'], true) || $argc !== 2) {
        throw new RuntimeException('Uso: php scripts/restaurar-adjuntos-local.php --comprobar|--restaurar');
    }
    require $root.'/web/vendor/autoload.php';
    $values = Dotenv\Dotenv::parse(file_get_contents($root.'/web/.env'));
    $host = $values['DB_HOST'] ?? '127.0.0.1';
    $port = $values['DB_PORT'] ?? '5432';
    if (($values['DB_CONNECTION'] ?? '') !== 'pgsql' || ($values['DB_DATABASE'] ?? '') !== 'correspondencia'
        || ! in_array($host, ['127.0.0.1', 'localhost', '::1'], true) || ! empty($values['DB_URL'])) {
        throw new RuntimeException('La conexion debe ser PostgreSQL local del proyecto, sin URL alternativa.');
    }
    $pointerPath = $root.'/.local/recuperacion-18/lote-actual.json';
    $pointer = json_decode(file_get_contents($pointerPath), true, 512, JSON_THROW_ON_ERROR);
    $batch = realpath($pointer['directorio']);
    $parent = realpath($root.'/.local/recuperacion-18');
    if ($batch === false || $parent === false || dirname($batch) !== $parent
        || ! preg_match('/^[a-f0-9]{32}$/', basename($batch))
        || empty($pointer['permisos_verificados']) || empty($pointer['respaldo_creado'])) {
        throw new RuntimeException('No se encontro un lote privado completado.');
    }
    $manifest = json_decode(file_get_contents($batch.'/manifiesto.json'), true, 512, JSON_THROW_ON_ERROR);
    if (($manifest['schema'] ?? null) !== 1 || ($manifest['database'] ?? '') !== 'correspondencia'
        || empty($manifest['attachments']) || empty($manifest['table_counts'])) {
        throw new RuntimeException('El manifiesto no corresponde al respaldo esperado.');
    }
    $dump = $batch.'/datos/base.dump';
    if (! is_file($dump) || ! hash_equals($manifest['dump_sha256'], hash_file('sha256', $dump))) {
        throw new RuntimeException('El archivo pg_dump falta o su integridad no coincide.');
    }
    foreach ($manifest['files_sha256'] as $relative => $hash) {
        if (! preg_match('~^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+\.enc$~', $relative) || str_contains($relative, '..')
            || ! is_file($batch.'/adjuntos/'.$relative) || is_link($batch.'/adjuntos/'.$relative)
            || ! hash_equals($hash, hash_file('sha256', $batch.'/adjuntos/'.$relative))) {
            throw new RuntimeException('Un archivo cifrado del respaldo falta o fue modificado.');
        }
    }
    $secretsFile = $batch.'/claves/cifrado.json';
    $secrets = json_decode(file_get_contents($secretsFile), true, 512, JSON_THROW_ON_ERROR);
    $encrypters = [];
    foreach ($manifest['attachments'] as $attachment) {
        $path = $attachment['storage_path'];
        if (! array_key_exists($path, $manifest['files_sha256'])) {
            throw new RuntimeException('Un adjunto no tiene archivo en el manifiesto.');
        }
        $version = $attachment['key_version'];
        $encoded = $secrets['keys'][$version] ?? '';
        $decoded = str_starts_with($encoded, 'base64:') ? base64_decode(substr($encoded, 7), true) : false;
        if ($decoded === false || ! Encrypter::supported($decoded, $secrets['cipher'])) {
            throw new RuntimeException('El respaldo no contiene una clave necesaria valida.');
        }
        $encrypters[$version] = new Encrypter($decoded, $secrets['cipher']);
    }
    if (! is_string($secrets['app_key'] ?? null) || $secrets['app_key'] === '') {
        throw new RuntimeException('El respaldo de APP_KEY esta incompleto.');
    }

    $database = 'correspondencia_recuperacion18_'.substr(basename($batch), 0, 12);
    if (! preg_match('/^correspondencia_recuperacion18_[a-f0-9]{12}$/', $database)
        || in_array($database, ['correspondencia', 'correspondencia_test', 'postgres'], true)) {
        throw new RuntimeException('Nombre de destino no permitido.');
    }
    $runtime = $batch.'/restaurado';
    if (file_exists($runtime) || ! empty($pointer['restauracion_creada'])) {
        throw new RuntimeException('El lote ya tiene un destino o intento de restauracion; no se sobrescribe.');
    }
    $pgBin = getenv('PG_BIN') ?: dirname($root).'/.tools/postgresql16/bin';
    $pgRestore = $pgBin.'/pg_restore.exe';
    if (! is_file($pgRestore)) {
        throw new RuntimeException('No se encontro pg_restore. Configure PG_BIN con su carpeta.');
    }
    $admin = new PDO('pgsql:host='.$host.';port='.$port.';dbname=postgres;connect_timeout=3',
        $values['DB_USERNAME'] ?? '', $values['DB_PASSWORD'] ?? '', [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    $existing = $admin->prepare('SELECT 1 FROM pg_database WHERE datname = :name');
    $existing->execute(['name' => $database]);
    if ($existing->fetchColumn() !== false) {
        throw new RuntimeException('La base de destino ya existe; no se restaura sobre ella.');
    }
    if (! $admin->query('SELECT rolcreatedb OR rolsuper FROM pg_roles WHERE rolname = current_user')->fetchColumn()) {
        throw new RuntimeException('La cuenta PostgreSQL no puede crear la base aislada.');
    }
    echo 'Integridad del respaldo comprobada: '.count($manifest['attachments']).' adjuntos y '.count($manifest['table_counts'])." tablas.\n";
    echo 'Destino nuevo: '.$database.".\n";
    if ($argv[1] === '--comprobar') {
        exit(0);
    }

    if (! mkdir($runtime, 0700)) {
        throw new RuntimeException('No se pudo crear el directorio de restauracion.');
    }
    $admin->exec('CREATE DATABASE "'.$database.'" WITH TEMPLATE template0');
    $environment = getenv();
    $environment['PGPASSWORD'] = $values['DB_PASSWORD'] ?? '';
    $environment['PGCONNECT_TIMEOUT'] = '5';
    $command = [$pgRestore, '--host='.$host, '--port='.$port, '--username='.($values['DB_USERNAME'] ?? ''),
        '--dbname='.$database, '--no-owner', '--no-acl', '--no-password', '--exit-on-error', '--single-transaction', $dump];
    $process = proc_open($command, [0 => ['pipe', 'r'], 1 => ['file', $runtime.'/pg_restore.log', 'a'], 2 => ['file', $runtime.'/pg_restore.log', 'a']], $pipes, $root, $environment);
    if (! is_resource($process)) {
        throw new RuntimeException('No se pudo iniciar pg_restore; se conserva el destino para diagnostico.');
    }
    fclose($pipes[0]);
    if (proc_close($process) !== 0) {
        throw new RuntimeException('pg_restore fallo; consulte el registro privado. No se elimina ni reutiliza el destino.');
    }
    $restored = new PDO('pgsql:host='.$host.';port='.$port.';dbname='.$database.';connect_timeout=3',
        $values['DB_USERNAME'] ?? '', $values['DB_PASSWORD'] ?? '', [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    if ($restored->query('SELECT current_database()')->fetchColumn() !== $database) {
        throw new RuntimeException('La conexion restaurada apunta a otra base.');
    }
    $counts = [];
    $tables = $restored->query("SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename")->fetchAll(PDO::FETCH_COLUMN);
    foreach ($tables as $table) {
        $counts[$table] = (int) $restored->query('SELECT count(*) FROM public."'.str_replace('"', '""', $table).'"')->fetchColumn();
    }
    if ($counts !== $manifest['table_counts']) {
        throw new RuntimeException('Las tablas o sus conteos no coinciden con el respaldo.');
    }
    $restoredRows = $restored->query('SELECT id, document_id, storage_path, key_version, size_bytes FROM attachments ORDER BY id')->fetchAll(PDO::FETCH_ASSOC);
    $expectedRows = [];
    foreach ($manifest['attachments'] as $attachment) {
        $expectedRows[$attachment['id']] = $attachment;
    }
    if (count($restoredRows) !== count($expectedRows)) {
        throw new RuntimeException('La cantidad de adjuntos restaurados no coincide.');
    }
    foreach ($restoredRows as $row) {
        $expected = $expectedRows[$row['id']] ?? null;
        if ($expected === null || $row['document_id'] !== $expected['document_id']
            || $row['storage_path'] !== $expected['storage_path'] || $row['key_version'] !== $expected['key_version']
            || (int) $row['size_bytes'] !== $expected['size_bytes']) {
            throw new RuntimeException('Los metadatos de un adjunto restaurado no coinciden.');
        }
    }
    foreach (['storage/app/private/attachments', 'storage/app/public', 'storage/framework/cache/data',
        'storage/framework/sessions', 'storage/framework/views', 'storage/logs', 'claves', 'bootstrap'] as $directory) {
        if (! mkdir($runtime.'/'.$directory, 0700, true) && ! is_dir($runtime.'/'.$directory)) {
            throw new RuntimeException('No se pudo preparar el almacenamiento aislado.');
        }
    }
    $restoredStorage = $runtime.'/storage/app/private/attachments';
    foreach ($manifest['files_sha256'] as $relative => $hash) {
        $destination = $restoredStorage.'/'.$relative;
        if (! is_dir(dirname($destination)) && ! mkdir(dirname($destination), 0700, true)) {
            throw new RuntimeException('No se pudo crear una carpeta de archivos restaurados.');
        }
        if (file_exists($destination) || ! copy($batch.'/adjuntos/'.$relative, $destination)
            || ! hash_equals($hash, hash_file('sha256', $destination))) {
            throw new RuntimeException('Un archivo restaurado no coincide con el respaldo.');
        }
    }
    $restoredSecretFile = $runtime.'/claves/cifrado.json';
    if (! copy($secretsFile, $restoredSecretFile)
        || ! hash_equals(hash_file('sha256', $secretsFile), hash_file('sha256', $restoredSecretFile))) {
        throw new RuntimeException('No se pudo recuperar el archivo de claves original.');
    }
    $recoveredSecrets = json_decode(file_get_contents($restoredSecretFile), true, 512, JSON_THROW_ON_ERROR);
    foreach ($expectedRows as $attachment) {
        $encoded = $recoveredSecrets['keys'][$attachment['key_version']];
        $encrypter = new Encrypter(base64_decode(substr($encoded, 7), true), $recoveredSecrets['cipher']);
        $content = $encrypter->decryptString(file_get_contents($restoredStorage.'/'.$attachment['storage_path']));
        if (strlen($content) !== $attachment['size_bytes'] || ! hash_equals($attachment['sha256_original'], hash('sha256', $content))) {
            throw new RuntimeException('El contenido recuperado no coincide con el original.');
        }
        unset($content);
    }
    $result = ['schema' => 1, 'database' => $database, 'directory' => $runtime, 'table_counts_verified' => count($counts),
        'attachments_verified' => count($expectedRows), 'files_verified' => count($manifest['files_sha256']),
        'original_keys_restored' => true, 'content_sha256_verified' => true, 'authenticated_download_verified' => false,
        'dump_sha256' => $manifest['dump_sha256'], 'completed_at_utc' => gmdate('c')];
    if (file_put_contents($runtime.'/restauracion.json', json_encode($result, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR)) === false) {
        throw new RuntimeException('La restauracion paso, pero no se pudo guardar su evidencia.');
    }
    $pointer['restauracion_creada'] = true;
    $pointer['base_restaurada'] = $database;
    if (file_put_contents($pointerPath, json_encode($pointer, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR)) === false) {
        throw new RuntimeException('No se pudo actualizar la referencia del lote restaurado.');
    }
    echo 'Restauracion completada: '.count($counts).' tablas, '.count($expectedRows).' adjuntos y '.count($manifest['files_sha256'])." archivos cifrados.\n";
    echo "Claves recuperadas del respaldo; SHA-256 del contenido original coincidente.\n";
    echo "Base y almacenamiento habituales conservados. Falta verificar la descarga autenticada del destino.\n";
} catch (Throwable $error) {
    fwrite(STDERR, 'No se completo la restauracion: '.$error->getMessage()."\n");
    exit(1);
}
