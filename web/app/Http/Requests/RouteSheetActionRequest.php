<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class RouteSheetActionRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        $data = ['request_key' => $this->header('Idempotency-Key', $this->input('request_key'))];

        foreach (['motivo', 'observacion'] as $field) {
            $value = $this->input($field);
            if (is_string($value)) {
                $data[$field] = trim($value, " \t\r\n");
            }
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
        }

        if ($this->routeIs('*.derive', '*.close')) {
            $rules['motivo'] = ['required', 'string', 'max:500'];
        }

        if ($this->routeIs('route-sheets.close')) {
            $rules['confirmar'] = ['accepted'];
        }

        if ($this->routeIs('*.attend')) {
            $rules['observacion'] = ['required', 'string', 'max:2000'];
        }

        return $rules;
    }

    public function messages(): array
    {
        return [
            'confirmar.accepted' => 'Confirma que quieres cerrar el expediente.',
            'observacion.required' => 'Escribe una observación.',
            'observacion.string' => 'La observación debe ser texto.',
            'observacion.max' => 'La observación debe tener hasta 2000 caracteres.',
        ];
    }
}
