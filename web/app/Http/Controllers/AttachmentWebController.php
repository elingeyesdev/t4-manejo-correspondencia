<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreAttachmentRequest;
use App\Services\AttachmentCipher;
use App\Services\StoreAttachment;
use Illuminate\Http\Request;

class AttachmentWebController extends Controller
{
    public function store(StoreAttachmentRequest $request, string $id, StoreAttachment $service, AttachmentController $attachments)
    {
        $response = $attachments->store($request, $id, $service);
        $destination = redirect()->to(route('documents.show', $id).'#adjuntos');

        return $response->getStatusCode() === 201
            ? $destination->with('status', 'Archivo guardado correctamente.')
            : $destination->withErrors(['archivo' => 'No se pudo guardar el archivo. Vuelve a seleccionarlo e intenta nuevamente.']);
    }

    public function download(Request $request, string $id, string $adjunto, AttachmentCipher $cipher, AttachmentController $attachments)
    {
        return $this->file($request, $id, $adjunto, $cipher, $attachments, false);
    }

    public function view(Request $request, string $id, string $adjunto, AttachmentCipher $cipher, AttachmentController $attachments)
    {
        return $this->file($request, $id, $adjunto, $cipher, $attachments, true);
    }

    private function file(Request $request, string $id, string $adjunto, AttachmentCipher $cipher, AttachmentController $attachments, bool $inline)
    {
        $response = $attachments->download($request, $id, $adjunto, $cipher);
        if ($response->getStatusCode() !== 200) {
            return redirect()->route('documents.show', $id)->withErrors(['archivo' => 'No se pudo abrir el archivo. Intenta nuevamente.']);
        }
        if ($inline) {
            $response->headers->set('Content-Disposition', preg_replace('/^attachment/i', 'inline', $response->headers->get('Content-Disposition')));
        }

        return $response;
    }
}
