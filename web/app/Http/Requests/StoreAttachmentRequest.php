<?php

namespace App\Http\Requests;

use App\Models\Document;
use Closure;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\UploadedFile;

class StoreAttachmentRequest extends FormRequest
{
    public function authorize(): bool
    {
        $user = $this->user();

        if (! $user || ! $user->isOperational()) {
            return false;
        }

        $document = Document::visibleTo($user)->with('sheet')->findOrFail($this->route('id'));

        return $document->sheet->canUploadAttachment($user);
    }

    public function rules(): array
    {
        return [
            'archivo' => [
                'bail',
                'required',
                'file',
                'mimetypes:application/pdf,image/jpeg,image/png',
                'max:10240',
                function (string $attribute, mixed $value, Closure $fail): void {
                    if ($value instanceof UploadedFile && $value->getSize() < 1) {
                        $fail('El archivo no puede estar vacio.');
                    }
                },
            ],
        ];
    }

    public function messages(): array
    {
        return [
            'archivo.required' => 'Selecciona un archivo.',
            'archivo.uploaded' => 'No se pudo recibir el archivo. Verifica que no supere los 10 MiB e intenta nuevamente.',
            'archivo.file' => 'La subida del archivo no es valida.',
            'archivo.mimetypes' => 'Solo se permiten archivos PDF, JPEG o PNG.',
            'archivo.max' => 'El archivo no debe superar los 10 MiB.',
        ];
    }
}
