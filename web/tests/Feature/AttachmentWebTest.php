<?php

namespace Tests\Feature;

use App\Models\Attachment;
use App\Models\Catalog;
use App\Models\Document;
use App\Models\Unit;
use App\Models\User;
use App\Services\RegisterDocument;
use App\Services\StoreAttachment;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;
use Tests\TestCase;

class AttachmentWebTest extends TestCase
{
    use RefreshDatabase;

    private User $operator;

    private Document $document;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
        config(['attachments.keys.v1' => 'base64:'.base64_encode(random_bytes(32))]);
        Storage::fake('attachments');
        $this->operator = User::factory()->create(['role' => 'recepcion', 'unit_id' => Unit::firstOrFail()->id, 'enabled' => true]);
        $this->document = $this->document();
    }

    private function document(): Document
    {
        [$doc] = app(RegisterDocument::class)->execute($this->operator, [
            'remitente' => 'Revisión integrada', 'asunto' => 'Archivo de correspondencia', 'fecha' => '2026-11-02',
            'tipo_id' => Catalog::where('kind', 'tipo')->firstOrFail()->id,
            'prioridad_id' => Catalog::where('kind', 'prioridad')->firstOrFail()->id,
            'unidad_id' => $this->operator->unit_id, 'request_key' => (string) Str::uuid(),
        ]);

        return $doc;
    }

    private function photo(string $name = 'carta.jpg'): UploadedFile
    {
        return new UploadedFile(base_path('tests/Fixtures/adjunto.jpg'), $name, 'image/jpeg', null, true);
    }

    private function props(string $html): array
    {
        $this->assertSame(1, preg_match('/id="document-attachments" data-props="([^"]*)"/', $html, $matches));

        return json_decode(html_entity_decode($matches[1], ENT_QUOTES | ENT_HTML5, 'UTF-8'), true, 512, JSON_THROW_ON_ERROR);
    }

    public function test_api_and_web_share_the_same_files_and_original_content(): void
    {
        $api = $this->actingAs($this->operator)->postJson('/api/documentos/'.$this->document->id.'/adjuntos', ['archivo' => $this->photo('desde-movil.jpg')])->assertCreated();
        $id = $api->json('id');
        $response = $this->get(route('documents.show', $this->document->id))->assertOk();
        $panel = $this->props($response->getContent());
        $this->assertTrue($panel['canUpload']);
        $this->assertSame('desde-movil.jpg', $panel['records'][0]['name']);
        $original = file_get_contents(base_path('tests/Fixtures/adjunto.jpg'));
        $download = $this->get(route('attachments.download', [$this->document->id, $id]))->assertOk();
        $this->assertSame($original, $download->getContent());
        $this->assertStringStartsWith('attachment;', $download->headers->get('Content-Disposition'));
        $view = $this->get(route('attachments.view', [$this->document->id, $id]))->assertOk();
        $this->assertSame($original, $view->getContent());
        $this->assertStringStartsWith('inline;', $view->headers->get('Content-Disposition'));
        $this->post(route('attachments.store', $this->document->id), ['archivo' => $this->photo('desde-web.jpg')])
            ->assertRedirect(route('documents.show', $this->document->id).'#adjuntos')->assertSessionHas('status', 'Archivo guardado correctamente.');
        $this->getJson('/api/documentos/'.$this->document->id.'/adjuntos')->assertOk()->assertJsonPath('total', 2);
        $webFile = Attachment::where('original_name', 'desde-web.jpg')->firstOrFail();
        $this->assertSame($original, $this->getJson('/api/documentos/'.$this->document->id.'/adjuntos/'.$webFile->id.'/descarga')->getContent());
    }

    public function test_official_can_read_but_cannot_upload_from_web(): void
    {
        $a = app(StoreAttachment::class)->execute($this->operator, $this->document->id, $this->photo());
        $official = User::factory()->create(['role' => 'funcionario', 'unit_id' => $this->operator->unit_id, 'enabled' => true]);
        $response = $this->actingAs($official)->get(route('documents.show', $this->document->id))->assertOk();
        $this->assertFalse($this->props($response->getContent())['canUpload']);
        $this->get(route('attachments.download', [$this->document->id, $a->id]))->assertOk();
        $this->post(route('attachments.store', $this->document->id), ['archivo' => $this->photo()])->assertForbidden();
        $this->assertDatabaseCount('attachments', 1);
    }

    public function test_other_units_and_unrelated_documents_cannot_download_the_file(): void
    {
        $a = app(StoreAttachment::class)->execute($this->operator, $this->document->id, $this->photo());
        $second = $this->document();
        $this->actingAs($this->operator)->get(route('attachments.view', [$second->id, $a->id]))->assertNotFound();
        $unit = Unit::create(['institution_id' => $this->operator->unit->institution_id, 'code' => 'OTRA', 'name' => 'Otra unidad', 'enabled' => true]);
        $other = User::factory()->create(['unit_id' => $unit->id, 'role' => 'recepcion', 'enabled' => true]);
        $this->actingAs($other)->get(route('attachments.download', [$this->document->id, $a->id]))->assertNotFound();
        $this->post(route('attachments.store', $this->document->id), ['archivo' => $this->photo()])->assertNotFound();
    }

    public function test_rejected_file_returns_to_the_document_without_creating_an_attachment(): void
    {
        $url = route('documents.show', $this->document->id);
        $this->actingAs($this->operator)->from($url)->post(route('attachments.store', $this->document->id), ['archivo' => UploadedFile::fake()->createWithContent('archivo.txt', 'Esto no es una imagen')])
            ->assertRedirect($url)->assertSessionHasErrors('archivo');
        $this->assertDatabaseCount('attachments', 0);
    }

    public function test_storage_failure_does_not_display_success(): void
    {
        $this->mock(StoreAttachment::class, function ($mock) {
            $mock->shouldReceive('execute')->once()->andThrow(new RuntimeException('Fallo simulado'));
        });
        $this->actingAs($this->operator)->post(route('attachments.store', $this->document->id), ['archivo' => $this->photo()])
            ->assertSessionHasErrors('archivo')->assertSessionMissing('status');
        $this->assertDatabaseCount('attachments', 0);
    }

    public function test_panel_paginates_and_escapes_file_names(): void
    {
        for ($i = 0; $i < 16; $i++) {
            app(StoreAttachment::class)->execute($this->operator, $this->document->id, $this->photo('carta-'.$i.'.jpg'));
        }
        $url = route('documents.show', $this->document->id);
        $response = $this->actingAs($this->operator)->get($url.'?adjuntos_page=2')->assertOk();
        $panel = $this->props($response->getContent());
        $this->assertSame(2, $panel['currentPage']);
        $this->assertSame(16, $panel['total']);
        $this->assertCount(1, $panel['records']);
        app(StoreAttachment::class)->execute($this->operator, $this->document->id, $this->photo('<script>alert(1)</script>.jpg'));
        $this->get($url)->assertDontSee('<script>alert(1)</script>', false);
    }

    public function test_guest_cannot_upload_or_download(): void
    {
        $this->post(route('attachments.store', $this->document->id))->assertRedirect(route('login'));
        $this->get(route('attachments.download', [$this->document->id, (string) Str::uuid()]))->assertRedirect(route('login'));
    }
}
