<?php

namespace Tests\Feature;

use App\Services\AttachmentCipher;
use Illuminate\Contracts\Encryption\DecryptException;
use RuntimeException;
use Tests\TestCase;

class AttachmentCipherTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        config([
            'attachments.cipher' => 'AES-256-CBC',
            'attachments.active_key_version' => 'v1',
            'attachments.keys' => [
                'v1' => 'base64:'.base64_encode(random_bytes(32)),
            ],
        ]);
    }

    public function test_recovers_original_binary_content(): void
    {
        $service = app(AttachmentCipher::class);
        $original = "\x00\xFF\x89PNG\r\nContenido de prueba";

        $encrypted = $service->encrypt($original);

        $this->assertSame('v1', $encrypted['key_version']);
        $this->assertNotSame($original, $encrypted['content']);
        $this->assertSame(
            $original,
            $service->decrypt($encrypted['content'], 'v1')
        );
    }

    public function test_rejects_modified_ciphertext(): void
    {
        $service = app(AttachmentCipher::class);
        $encrypted = $service->encrypt('Documento de prueba');

        $payload = json_decode(
            base64_decode($encrypted['content'], true),
            true,
            512,
            JSON_THROW_ON_ERROR
        );

        $payload['value'][0] = $payload['value'][0] === 'A' ? 'B' : 'A';
        $modified = base64_encode(json_encode($payload, JSON_THROW_ON_ERROR));

        $this->expectException(DecryptException::class);

        $service->decrypt($modified, 'v1');
    }

    public function test_rejects_unavailable_key(): void
    {
        $service = app(AttachmentCipher::class);
        $encrypted = $service->encrypt('Documento de prueba');

        config(['attachments.keys' => []]);

        $this->expectException(RuntimeException::class);

        $service->decrypt($encrypted['content'], 'v1');
    }
}
