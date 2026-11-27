<?php

function issue75Identities(): array
{
    $identities = [
        'admin' => ['administracion@correspondencia.local', 'Administración Institucional', 'administrador'],
        'reception' => ['recepcion@correspondencia.local', 'Ventanilla de Recepción', 'recepcion'],
        'receiver' => ['gestion.documental@correspondencia.local', 'Gestión Documental', 'funcionario'],
        'author' => ['mathew.bruckner@correspondencia.local', 'Mathew Bruckner', 'funcionario'],
        'via' => ['direccion@correspondencia.local', 'Dirección Administrativa', 'funcionario'],
    ];

    // Guardado junto al lanzador local, fuera del repositorio.
    $directory = dirname(__DIR__, 2).'/.local/nota-interna';
    if (! is_dir($directory) && ! mkdir($directory, 0700, true) && ! is_dir($directory)) {
        throw new RuntimeException('No se pudo crear el directorio de la instalación local.');
    }
    $file = fopen($directory.'/credenciales.json', 'c+b');
    if ($file === false) {
        throw new RuntimeException('No se pudo abrir el archivo de credenciales locales.');
    }

    try {
        if (! flock($file, LOCK_EX)) {
            throw new RuntimeException('No se pudo reservar el archivo de credenciales locales.');
        }
        $saved = stream_get_contents($file);
        $passwords = $saved === '' ? [] : json_decode($saved, true, flags: JSON_THROW_ON_ERROR);
        $previous = $passwords;
        foreach ($identities as $role => $identity) {
            $passwords[$role] ??= 'Cs!'.bin2hex(random_bytes(10));
            $identities[$role][] = $passwords[$role];
        }
        if ($previous !== $passwords) {
            $encoded = json_encode($passwords, JSON_THROW_ON_ERROR);
            if (! rewind($file) || fwrite($file, $encoded) !== strlen($encoded)
                || ! ftruncate($file, strlen($encoded)) || ! fflush($file)) {
                throw new RuntimeException('No se pudieron guardar las credenciales locales.');
            }
        }
    } finally {
        fclose($file);
    }

    return $identities;
}
