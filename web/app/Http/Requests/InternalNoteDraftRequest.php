<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class InternalNoteDraftRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        $via = $this->input('vias_usuario_ids', []);
        if (is_array($via)) {
            $this->merge(['vias_usuario_ids' => array_values(array_filter($via, fn ($value) => $value !== null && $value !== ''))]);
        }
    }

    public function rules(): array
    {
        return [
            'asunto' => ['required', 'string', 'max:200'],
            'referencia' => ['nullable', 'string', 'max:200'],
            'cuerpo' => ['required', 'string', 'max:20000'],
            'destinatario_unidad_id' => ['required', 'integer'],
            'vias_usuario_ids' => ['sometimes', 'array', 'list', 'max:10'],
            'vias_usuario_ids.*' => ['required', 'integer', 'distinct'],
            'cc_usuario_ids' => ['sometimes', 'array', 'list', 'max:50'],
            'cc_usuario_ids.*' => ['required', 'integer', 'distinct'],
            'version' => [$this->isMethod('PATCH') ? 'required' : 'sometimes', 'integer', 'min:1'],
        ];
    }
}
