<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreAttachmentRequest;
use App\Models\Attachment;
use App\Models\Document;
use App\Services\AttachmentCipher;
use App\Services\StoreAttachment;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use RuntimeException;
use Symfony\Component\HttpFoundation\HeaderUtils;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Throwable;

class AttachmentController extends Controller
{
    public function index(Request $request, string $id)
    {
        $document = Document::visibleTo($request->user())->findOrFail($id);

        $attachments = Attachment::where('document_id', $document->id)
            ->latest()
            ->orderBy('id')
            ->paginate(15);

        return response()->json(
            $attachments->through(fn ($attachment) => $this->payload($attachment))
        );
    }

    public function store(
        StoreAttachmentRequest $request,
        string $id,
        StoreAttachment $service
    ) {
        try {
            $attachment = $service->execute(
                $request->user(),
                $id,
                $request->file('archivo')
            );
        } catch (ModelNotFoundException|HttpExceptionInterface $error) {
            throw $error;
        } catch (Throwable $error) {
            report($error);

            return response()->json([
                'message' => 'No se pudo guardar el adjunto. Intenta nuevamente.',
            ], 503);
        }

        return response()->json($this->payload($attachment), 201);
    }

    public function download(
        Request $request,
        string $id,
        string $adjunto,
        AttachmentCipher $cipher
    ) {
        $document = Document::visibleTo($request->user())->findOrFail($id);

        $attachment = Attachment::where('document_id', $document->id)
            ->findOrFail($adjunto);

        try {
            $encrypted = Storage::disk(config('attachments.disk'))
                ->get($attachment->storage_path);

            if (! is_string($encrypted)) {
                throw new RuntimeException('No se pudo leer el adjunto cifrado.');
            }

            $content = $cipher->decrypt($encrypted, $attachment->key_version);
        } catch (Throwable $error) {
            report($error);

            return response()->json([
                'message' => 'El adjunto no esta disponible en este momento.',
            ], 503);
        }

        $filename = str_replace(
            ['/', '\\'],
            '_',
            $attachment->original_name
        );

        return response($content, 200, [
            'Content-Type' => $attachment->mime_type,
            'Content-Disposition' => HeaderUtils::makeDisposition(
                'attachment',
                $filename,
                'adjunto'
            ),
            'Cache-Control' => 'private, no-store',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }

    private function payload(Attachment $attachment): array
    {
        return [
            'id' => $attachment->id,
            'document_id' => $attachment->document_id,
            'nombre' => $attachment->original_name,
            'mime' => $attachment->mime_type,
            'tamano_bytes' => $attachment->size_bytes,
            'creado_en' => $attachment->created_at?->toISOString(),
            'descarga_url' => url(
                '/api/documentos/'.$attachment->document_id
                .'/adjuntos/'.$attachment->id.'/descarga'
            ),
        ];
    }
}
