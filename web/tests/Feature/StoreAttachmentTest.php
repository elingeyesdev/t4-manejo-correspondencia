<?php

namespace Tests\Feature;

use App\Models\Attachment;
use App\Models\Catalog;
use App\Models\Document;
use App\Models\Unit;
use App\Models\User;
use App\Services\AttachmentCipher;
use App\Services\RegisterDocument;
use App\Services\StoreAttachment;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Mockery;
use RuntimeException;
use Tests\TestCase;

class StoreAttachmentTest extends TestCase
{
    use RefreshDatabase;

    private Document $document;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed();

        config([
            'attachments.disk' => 'attachments',
            'attachments.cipher' => 'AES-256-CBC',
            'attachments.active_key_version' => 'v1',
            'attachments.keys' => [
                'v1' => 'base64:'.base64_encode(random_bytes(32)),
            ],
        ]);

        Storage::fake('attachments');

        $unit = Unit::firstOrFail();

        $user = User::factory()->create([
            'role' => 'recepcion',
            'unit_id' => $unit->id,
            'enabled' => true,
        ]);

        [$this->document] = app(RegisterDocument::class)->execute($user, [
            'remitente' => 'Prueba',
            'asunto' => 'Prueba de adjuntos',
            'fecha' => '2026-11-02',
            'tipo_id' => Catalog::where('kind', 'tipo')->firstOrFail()->id,
            'prioridad_id' => Catalog::where('kind', 'prioridad')->firstOrFail()->id,
            'unidad_id' => $unit->id,
            'request_key' => (string) Str::uuid(),
        ]);
    }

    private function file(): UploadedFile
    {
        return UploadedFile::fake()->createWithContent(
            'prueba.pdf',
            "%PDF-1.4\nContenido de prueba\n%%EOF"
        );
    }

    public function test_stores_encrypted_content_and_metadata(): void
    {
        $file = $this->file();
        $original = file_get_contents($file->getRealPath());

        $attachment = app(StoreAttachment::class)
            ->execute($this->document, $file);

        $disk = Storage::disk('attachments');
        $disk->assertExists($attachment->storage_path);

        $stored = $disk->get($attachment->storage_path);

        $this->assertNotSame($original, $stored);
        $this->assertSame(
            $original,
            app(AttachmentCipher::class)->decrypt(
                $stored,
                $attachment->key_version
            )
        );

        $this->assertDatabaseHas('attachments', [
            'id' => $attachment->id,
            'document_id' => $this->document->id,
            'original_name' => 'prueba.pdf',
            'size_bytes' => strlen($original),
            'key_version' => 'v1',
        ]);

        $this->assertArrayNotHasKey('storage_path', $attachment->toArray());
        $this->assertArrayNotHasKey('key_version', $attachment->toArray());
    }

    public function test_removes_file_when_database_registration_fails(): void
    {
        Event::listen('eloquent.creating: '.Attachment::class, function () {
            throw new RuntimeException('Fallo simulado de registro.');
        });

        try {
            app(StoreAttachment::class)->execute($this->document, $this->file());
            $this->fail('La operacion debio fallar.');
        } catch (RuntimeException $error) {
            $this->assertSame('Fallo simulado de registro.', $error->getMessage());
        }

        $this->assertDatabaseCount('attachments', 0);
        $this->assertSame([], Storage::disk('attachments')->allFiles());
    }

    public function test_does_not_register_attachment_when_write_fails(): void
    {
        $disk = Mockery::mock();
        $disk->shouldReceive('put')->once()->andReturn(false);
        $disk->shouldReceive('delete')->once()->andReturn(true);

        Storage::shouldReceive('disk')
            ->with('attachments')
            ->once()
            ->andReturn($disk);

        try {
            app(StoreAttachment::class)->execute($this->document, $this->file());
            $this->fail('La escritura debio fallar.');
        } catch (RuntimeException $error) {
            $this->assertSame(
                'No se pudo guardar el archivo cifrado.',
                $error->getMessage()
            );
        }

        $this->assertDatabaseCount('attachments', 0);
    }
}
