<?php

return [
    'required' => 'El campo :attribute es obligatorio.',
    'string' => 'El campo :attribute debe ser texto.',
    'email' => 'El correo electrónico no es válido.',
    'integer' => 'El campo :attribute debe ser un identificador válido.',
    'boolean' => 'El estado indicado no es válido.',
    'date_format' => 'El campo :attribute debe tener el formato :format y ser una fecha válida.',
    'exists' => 'El valor de :attribute no está disponible.',
    'unique' => 'El valor de :attribute ya está registrado.',
    'in' => 'El valor de :attribute no está permitido.',
    'regex' => 'El formato de :attribute no es válido.',
    'confirmed' => 'La confirmación de :attribute no coincide.',
    'min' => ['string' => 'El campo :attribute debe contener al menos :min caracteres.'],
    'max' => ['string' => 'El campo :attribute no debe superar :max caracteres.'],
    'password' => ['letters' => 'La contraseña debe contener letras.', 'numbers' => 'La contraseña debe contener números.'],
    'attributes' => ['email' => 'correo', 'password' => 'contraseña', 'name' => 'nombre', 'code' => 'código', 'remitente' => 'remitente', 'asunto' => 'asunto', 'fecha' => 'fecha', 'tipo_id' => 'tipo', 'prioridad_id' => 'prioridad', 'unidad_id' => 'unidad', 'unit_id' => 'unidad', 'request_key' => 'clave de solicitud', 'role' => 'rol', 'enabled' => 'estado'],
];
