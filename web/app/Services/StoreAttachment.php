<?php

namespace App\Services;

use App\Models\Attachment;
use App\Models\Document;
use App\Models\RouteSheet;
use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;
use Throwable;

class StoreAttachment
{
    public function __construct(
        private AttachmentCipher $cipher
    ) {}

    public function execute(User $actor, string $documentId, UploadedFile $file): Attachment
    {
        $content = file_get_contents($file->getRealPath());

        if ($content === false) {
            throw new RuntimeException('No se pudo leer el archivo recibido.');
        }

        $encrypted = $this->cipher->encrypt($content);
        $id = (string) Str::uuid();
        $path = $documentId.'/'.$id.'.enc';
        $disk = Storage::disk(config('attachments.disk'));

        $name = preg_replace(
            '/[\x00-\x1F\x7F]/',
            '',
            $file->getClientOriginalName()
        );

        $name = mb_substr(trim($name), 0, 255);

        if ($name === '') {
            $name = 'adjunto';
        }

        $writeStarted = false;
        try {
            return DB::transaction(function () use (
                $actor,
                $id,
                $documentId,
                $file,
                $content,
                $path,
                $name,
                $encrypted,
                $disk,
                &$writeStarted,
            ) {
                $actor = User::query()->lockForUpdate()->findOrFail($actor->id);
                abort_unless($actor->isOperational(), 403);
                $sheet = RouteSheet::where('document_id', $documentId)->lockForUpdate()->firstOrFail();
                Document::visibleTo($actor)->findOrFail($documentId);
                abort_unless($sheet->canUploadAttachment($actor), 403);

                $writeStarted = true;
                if (! $disk->put($path, $encrypted['content'])) {
                    throw new RuntimeException('No se pudo guardar el archivo cifrado.');
                }

                return Attachment::create([
                    'id' => $id,
                    'document_id' => $documentId,
                    'original_name' => $name,
                    'mime_type' => $file->getMimeType(),
                    'size_bytes' => strlen($content),
                    'storage_path' => $path,
                    'key_version' => $encrypted['key_version'],
                ]);
            });
        } catch (Throwable $error) {
            if ($writeStarted) {
                try {
                    if (! $disk->delete($path)) {
                        throw new RuntimeException(
                            'No se pudo limpiar el archivo de una carga fallida.'
                        );
                    }
                } catch (Throwable $cleanupError) {
                    report($cleanupError);
                }
            }

            throw $error;
        }
    }
}
