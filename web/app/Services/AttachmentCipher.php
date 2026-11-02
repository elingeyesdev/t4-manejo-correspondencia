<?php

namespace App\Services;

use Illuminate\Encryption\Encrypter;
use RuntimeException;

class AttachmentCipher
{
    public function encrypt(string $content): array
    {
        $version = config('attachments.active_key_version');

        if (! is_string($version) || $version === '') {
            throw new RuntimeException('Falta la version activa de cifrado.');
        }

        return [
            'content' => $this->encrypter($version)->encryptString($content),
            'key_version' => $version,
        ];
    }

    public function decrypt(string $content, string $version): string
    {
        return $this->encrypter($version)->decryptString($content);
    }

    private function encrypter(string $version): Encrypter
    {
        $keys = config('attachments.keys', []);
        $encoded = $keys[$version] ?? null;

        if (! is_string($encoded) || ! str_starts_with($encoded, 'base64:')) {
            throw new RuntimeException('Clave de adjuntos no configurada.');
        }

        $key = base64_decode(substr($encoded, 7), true);
        $cipher = config('attachments.cipher');

        if (
            $key === false ||
            ! is_string($cipher) ||
            ! Encrypter::supported($key, $cipher)
        ) {
            throw new RuntimeException('Configuracion de cifrado invalida.');
        }

        return new Encrypter($key, $cipher);
    }
}
