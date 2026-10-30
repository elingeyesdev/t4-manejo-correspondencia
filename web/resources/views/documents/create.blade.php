@extends('layout')
@section('title', 'Nuevo registro')
@section('content')
    <div class="mb-6">
        <h1 class="text-3xl font-semibold mb-2">Registrar correspondencia</h1>
        <p class="text-muted-color m-0">Se crearán el documento y su hoja de ruta en una sola operación.</p>
    </div>
    @php
        $formProps = [
            'action' => route('documents.store'),
            'csrfToken' => csrf_token(),
            'formKey' => 'register',
            'formLabel' => 'Registrar correspondencia',
            'submitLabel' => 'Guardar documento y hoja',
            'cancelUrl' => route('documents.index'),
            'help' => 'El responsable inicial es el usuario que registra. La derivación a otra unidad corresponde al siguiente recorrido.',
            'hidden' => ['request_key' => old('request_key', $requestKey)],
            'initial' => [
                'remitente' => old('remitente', ''), 'asunto' => old('asunto', ''),
                'fecha' => old('fecha', now('America/La_Paz')->format('Y-m-d')),
                'tipo_id' => (string) old('tipo_id', ''),
                'prioridad_id' => (string) old('prioridad_id', ''),
                'unidad_id' => (string) old('unidad_id', ''),
            ],
            'errors' => (object) $errors->messages(),
            'fields' => [
                ['name' => 'remitente', 'label' => 'Remitente', 'required' => true, 'maxLength' => 150],
                ['name' => 'fecha', 'label' => 'Fecha de recepción', 'type' => 'date', 'required' => true],
                ['name' => 'asunto', 'label' => 'Asunto', 'type' => 'textarea', 'required' => true, 'maxLength' => 500, 'wide' => true],
                ['name' => 'tipo_id', 'label' => 'Tipo de documento', 'type' => 'select', 'required' => true,
                    'options' => $types->map(fn ($item) => ['value' => (string) $item->id, 'label' => $item->name])->values()->all()],
                ['name' => 'prioridad_id', 'label' => 'Prioridad', 'type' => 'select', 'required' => true,
                    'options' => $priorities->map(fn ($item) => ['value' => (string) $item->id, 'label' => $item->name])->values()->all()],
                ['name' => 'unidad_id', 'label' => 'Unidad de registro', 'type' => 'select', 'required' => true, 'wide' => true,
                    'options' => $units->map(fn ($item) => ['value' => (string) $item->id, 'label' => $item->name])->values()->all()],
            ],
        ];
    @endphp
    <div class="card">
        <div id="register-form" data-sakai-form data-props="{{ json_encode($formProps, JSON_UNESCAPED_SLASHES) }}"></div>
    </div>
@endsection
