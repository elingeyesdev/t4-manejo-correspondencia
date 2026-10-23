<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreDocumentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->canRegister();
    }

    protected function prepareForValidation(): void
    {
        $data = [];
        foreach (['remitente', 'asunto'] as $field) {
            if (is_string($this->input($field))) {
                $data[$field] = trim($this->input($field));
            }
        }
        $data['request_key'] = $this->header('Idempotency-Key', $this->input('request_key'));
        $this->merge($data);
    }

    public function rules(): array
    {
        return ['remitente' => 'required|string|max:150', 'asunto' => 'required|string|max:500', 'fecha' => 'required|date_format:Y-m-d',
            'tipo_id' => ['required', 'integer', Rule::exists('catalogs', 'id')->where('kind', 'tipo')],
            'prioridad_id' => ['required', 'integer', Rule::exists('catalogs', 'id')->where('kind', 'prioridad')],
            'unidad_id' => ['required', 'integer', Rule::exists('units', 'id')],
            'request_key' => 'required|string|min:16|max:100|regex:/^[A-Za-z0-9_-]+$/'];
    }
}
