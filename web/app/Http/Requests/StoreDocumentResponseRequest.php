<?php

namespace App\Http\Requests;

class StoreDocumentResponseRequest extends StoreDocumentRequest
{
    public function authorize(): bool
    {
        return $this->user()?->isOperational() ?? false;
    }

    public function rules(): array
    {
        $rules = parent::rules();

        unset($rules['unidad_id']);
        $rules['version'] = ['required', 'integer', 'min:1'];

        return $rules;
    }
}
