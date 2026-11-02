<?php

namespace Tests\Feature;

use App\Models\Attachment;
use App\Models\Catalog;
use App\Models\Document;
use App\Models\Unit;
use App\Models\User;
use App\Services\RegisterDocument;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AttachmentApiTest extends TestCase
{
    use RefreshDatabase;

    private User $operator;

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

        $this->operator = User::factory()->create([
            'role' => 'recepcion',
            'unit_id' => $unit->id,
            'enabled' => true,
        ]);

        [$this->document] = app(RegisterDocument::class)->execute(
            $this->operator,
            [
                'remitente' => 'Prueba API',
                'asunto' => 'Imagen adjunta',
                'fecha' => '2026-11-02',
                'tipo_id' => Catalog::where('kind', 'tipo')->firstOrFail()->id,
                'prioridad_id' => Catalog::where('kind', 'prioridad')->firstOrFail()->id,
                'unidad_id' => $unit->id,
                'request_key' => (string) Str::uuid(),
            ]
        );
    }

    private function url(): string
    {
        return '/api/documentos/'.$this->document->id.'/adjuntos';
    }

    private function png(): string
    {
        return base64_decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
            .'AAAAC0lEQVR42mP8/x8AAwMCAO+aP1sAAAAASUVORK5CYII=',
            true
        );
    }

    public function test_guests_cannot_access_attachment_routes(): void
    {
        $this->getJson($this->url())->assertUnauthorized();

        $this->postJson($this->url())->assertUnauthorized();

        $this->getJson(
            $this->url().'/'.Str::uuid().'/descarga'
        )->assertUnauthorized();

        $this->assertDatabaseCount('attachments', 0);
    }

    public function test_operator_can_upload_list_and_download_png(): void
    {
        Sanctum::actingAs($this->operator);

        $original = $this->png();

        $upload = $this->postJson($this->url(), [
            'archivo' => $this->fileFromContent(
                'foto.png',
                $original
            ),
        ])->assertCreated();

        $upload->assertJsonPath('nombre', 'foto.png')
            ->assertJsonPath('mime', 'image/png')
            ->assertJsonPath('tamano_bytes', strlen($original))
            ->assertJsonPath('document_id', $this->document->id);

        $this->assertArrayNotHasKey('storage_path', $upload->json());
        $this->assertArrayNotHasKey('key_version', $upload->json());

        $attachment = Attachment::findOrFail($upload->json('id'));

        $this->assertNotSame(
            $original,
            Storage::disk('attachments')->get($attachment->storage_path)
        );

        $this->getJson($this->url())
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $attachment->id);

        $download = $this->get(
            $this->url().'/'.$attachment->id.'/descarga',
            ['Accept' => 'application/json']
        )->assertOk();

        $download->assertHeader('Content-Type', 'image/png');
        $download->assertHeader('X-Content-Type-Options', 'nosniff');

        $this->assertSame($original, $download->getContent());
        $this->assertDatabaseCount('attachments', 1);
    }

    public function test_official_can_read_but_cannot_upload(): void
    {
        Sanctum::actingAs($this->operator);

        $upload = $this->postJson($this->url(), [
            'archivo' => $this->fileFromContent(
                'foto.png',
                $this->png()
            ),
        ])->assertCreated();

        $official = User::factory()->create([
            'role' => 'funcionario',
            'unit_id' => $this->operator->unit_id,
            'enabled' => true,
        ]);

        Sanctum::actingAs($official);

        $this->getJson($this->url())
            ->assertOk()
            ->assertJsonCount(1, 'data');

        $this->getJson(
            $this->url().'/'.$upload->json('id').'/descarga'
        )->assertOk();

        $this->postJson($this->url(), [
            'archivo' => $this->fileFromContent(
                'otra.png',
                $this->png()
            ),
        ])->assertForbidden();

        $this->assertDatabaseCount('attachments', 1);
    }

    public function test_user_from_another_unit_cannot_access_attachments(): void
    {
        Sanctum::actingAs($this->operator);

        $upload = $this->postJson($this->url(), [
            'archivo' => $this->fileFromContent(
                'foto.png',
                $this->png()
            ),
        ])->assertCreated();

        $unit = Unit::create([
            'institution_id' => $this->operator->unit->institution_id,
            'code' => 'OTRA',
            'name' => 'Otra unidad',
            'enabled' => true,
        ]);

        $otherUser = User::factory()->create([
            'role' => 'recepcion',
            'unit_id' => $unit->id,
            'enabled' => true,
        ]);

        Sanctum::actingAs($otherUser);

        $this->getJson($this->url())->assertNotFound();

        $this->getJson(
            $this->url().'/'.$upload->json('id').'/descarga'
        )->assertNotFound();

        $this->postJson($this->url(), [
            'archivo' => $this->fileFromContent(
                'otra.png',
                $this->png()
            ),
        ])->assertNotFound();

        $this->assertDatabaseCount('attachments', 1);
    }

    public function test_rejects_missing_file(): void
    {
        Sanctum::actingAs($this->operator);

        $this->postJson($this->url(), [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('archivo');

        $this->assertDatabaseCount('attachments', 0);
        $this->assertSame([], Storage::disk('attachments')->allFiles());
    }

    public function test_rejects_text_disguised_as_png(): void
    {
        Sanctum::actingAs($this->operator);

        $this->postJson($this->url(), [
            'archivo' => $this->fileFromContent(
                'foto.png',
                'Esto es texto, no una imagen.'
            ),
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('archivo');

        $this->assertDatabaseCount('attachments', 0);
        $this->assertSame([], Storage::disk('attachments')->allFiles());
    }

    public function test_rejects_empty_file(): void
    {
        Sanctum::actingAs($this->operator);

        $this->postJson($this->url(), [
            'archivo' => $this->fileFromContent(
                'vacio.png',
                ''
            ),
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('archivo');

        $this->assertDatabaseCount('attachments', 0);
        $this->assertSame([], Storage::disk('attachments')->allFiles());
    }

    public function test_rejects_file_larger_than_ten_megabytes(): void
    {
        Sanctum::actingAs($this->operator);

        $content = str_pad($this->png(), 10 * 1024 * 1024 + 1, "\0");

        $this->postJson($this->url(), [
            'archivo' => $this->fileFromContent(
                'grande.png',
                $content
            ),
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('archivo');

        $this->assertDatabaseCount('attachments', 0);
        $this->assertSame([], Storage::disk('attachments')->allFiles());
    }

    private function fileFromContent(string $name, string $content): UploadedFile
    {
        $path = tempnam(sys_get_temp_dir(), 'attachment-test-');

        if ($path === false) {
            throw new \RuntimeException('No se pudo crear el archivo de prueba.');
        }

        $this->beforeApplicationDestroyed(static function () use ($path) {
            if (is_file($path)) {
                unlink($path);
            }
        });

        if (file_put_contents($path, $content) !== strlen($content)) {
            throw new \RuntimeException('No se pudo escribir el archivo de prueba.');
        }

        return new UploadedFile(
            $path,
            $name,
            'application/octet-stream',
            UPLOAD_ERR_OK,
            true
        );
    }

    public function test_recovers_download_after_restoring_key_and_file(): void
    {
        Sanctum::actingAs($this->operator);

        $original = $this->png();

        $upload = $this->postJson($this->url(), [
            'archivo' => $this->fileFromContent('foto.png', $original),
        ])->assertCreated();

        $attachment = Attachment::findOrFail($upload->json('id'));
        $url = $this->url().'/'.$attachment->id.'/descarga';
        $disk = Storage::disk('attachments');

        $keyBackup = config('attachments.keys');
        $fileBackup = $disk->get($attachment->storage_path);

        // Simular que la clave no esta disponible.
        config(['attachments.keys' => []]);

        $this->getJson($url)
            ->assertStatus(503)
            ->assertJsonPath(
                'message',
                'El adjunto no esta disponible en este momento.'
            );

        // Restaurar la misma clave permite recuperar el contenido.
        config(['attachments.keys' => $keyBackup]);

        $download = $this->getJson($url)->assertOk();
        $this->assertSame($original, $download->getContent());

        // Simular perdida y restauracion del archivo cifrado.
        $this->assertTrue($disk->delete($attachment->storage_path));

        $this->getJson($url)->assertStatus(503);

        $this->assertTrue(
            $disk->put($attachment->storage_path, $fileBackup)
        );

        $recovered = $this->getJson($url)->assertOk();
        $this->assertSame($original, $recovered->getContent());

        $this->assertDatabaseCount('attachments', 1);
    }

    public function test_accepts_and_downloads_real_jpeg(): void
    {
        Sanctum::actingAs($this->operator);

        $original = file_get_contents(
            base_path('tests/Fixtures/adjunto.jpg')
        );

        $this->assertNotFalse($original);

        $upload = $this->postJson($this->url(), [
            'archivo' => $this->fileFromContent('foto.jpg', $original),
        ])->assertCreated()
            ->assertJsonPath('mime', 'image/jpeg')
            ->assertJsonPath('tamano_bytes', strlen($original));

        $download = $this->getJson(
            $this->url().'/'.$upload->json('id').'/descarga'
        )->assertOk();

        $download->assertHeader('Content-Type', 'image/jpeg');

        $this->assertSame($original, $download->getContent());
    }

    public function test_accepts_and_downloads_real_pdf(): void
    {
        Sanctum::actingAs($this->operator);

        // PDF minimo valido con una pagina vacia.
        $objects = [
            '<< /Type /Catalog /Pages 2 0 R >>',
            '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
            '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << >> >>',
        ];

        $original = "%PDF-1.4\n";
        $offsets = [0];

        foreach ($objects as $index => $object) {
            $number = $index + 1;
            $offsets[] = strlen($original);
            $original .= "{$number} 0 obj\n{$object}\nendobj\n";
        }

        $xref = strlen($original);
        $original .= "xref\n0 4\n0000000000 65535 f \n";

        foreach (array_slice($offsets, 1) as $offset) {
            $original .= sprintf("%010d 00000 n \n", $offset);
        }

        $original .= "trailer\n<< /Size 4 /Root 1 0 R >>\n";
        $original .= "startxref\n{$xref}\n%%EOF\n";

        $upload = $this->postJson($this->url(), [
            'archivo' => $this->fileFromContent('documento.pdf', $original),
        ])->assertCreated()
            ->assertJsonPath('mime', 'application/pdf')
            ->assertJsonPath('tamano_bytes', strlen($original));

        $download = $this->getJson(
            $this->url().'/'.$upload->json('id').'/descarga'
        )->assertOk();

        $download->assertHeader('Content-Type', 'application/pdf');

        $this->assertSame($original, $download->getContent());
    }

    public function test_cannot_download_attachment_under_another_document(): void
    {
        Sanctum::actingAs($this->operator);

        $upload = $this->postJson($this->url(), [
            'archivo' => $this->fileFromContent('foto.png', $this->png()),
        ])->assertCreated();

        [$otherDocument] = app(RegisterDocument::class)->execute(
            $this->operator,
            [
                'remitente' => 'Prueba de otro documento',
                'asunto' => 'Documento sin adjuntos',
                'fecha' => '2026-11-02',
                'tipo_id' => Catalog::where('kind', 'tipo')->firstOrFail()->id,
                'prioridad_id' => Catalog::where('kind', 'prioridad')->firstOrFail()->id,
                'unidad_id' => $this->operator->unit_id,
                'request_key' => (string) Str::uuid(),
            ]
        );

        $otherUrl = '/api/documentos/'.$otherDocument->id.'/adjuntos';

        $this->getJson($otherUrl)
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->getJson(
            $otherUrl.'/'.$upload->json('id').'/descarga'
        )->assertNotFound();

        $this->getJson(
            $this->url().'/'.$upload->json('id').'/descarga'
        )->assertOk();

        $this->assertDatabaseCount('attachments', 1);
    }
}
