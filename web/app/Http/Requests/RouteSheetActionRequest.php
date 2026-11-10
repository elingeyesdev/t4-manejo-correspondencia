<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class RouteSheetActionRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        $data = ['request_key' => $this->header('Idempotency-Key', $this->input('request_key'))];

        if (is_string($this->input('motivo'))) {
            $data['motivo'] = trim($this->input('motivo'), " \t\r\n");
        }

        $this->merge($data);
    }

    public function rules(): array
    {
        $rules = [
            'version' => ['required', 'integer', 'min:1'],
            'request_key' => ['required', 'string', 'min:16', 'max:100', 'regex:/^[A-Za-z0-9_-]+$/D'],
        ];

        if ($this->routeIs('*.derive')) {
            $rules['destino_unidad_id'] = ['required', 'integer', 'min:1'];
            $rules['motivo'] = ['required', 'string', 'max:500'];
        }

        return $rules;
    }
}
