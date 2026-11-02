@php
    $formKey = 'unit-'.($item?->id ?? 'new');
    $restoring = old('_form') === $formKey;
    $formProps = [
        'action' => url('/administracion/unidades'.($item ? '/'.$item->id : '')),
        'csrfToken' => csrf_token(), 'method' => $item ? 'PUT' : 'POST',
        'formKey' => $formKey, 'formLabel' => $item ? 'Editar unidad '.$item->code : 'Agregar unidad',
        'submitLabel' => 'Guardar unidad',
        'initial' => [
            'code' => $restoring ? old('code') : ($item?->code ?? ''),
            'name' => $restoring ? old('name') : ($item?->name ?? ''),
            'enabled' => (string) ($restoring ? old('enabled') : (int) ($item?->enabled ?? true)),
        ],
        'errors' => (object) ($restoring ? $errors->messages() : []),
        'fields' => [
            ['name' => 'code', 'label' => 'Código', 'required' => true, 'maxLength' => 30, 'pattern' => '[A-Z0-9_-]+', 'help' => 'Mayúsculas, números, guion o guion bajo.'],
            ['name' => 'name', 'label' => 'Nombre', 'required' => true, 'maxLength' => 150],
            ['name' => 'enabled', 'label' => 'Estado', 'type' => 'select', 'required' => true,
                'options' => [['value' => '1', 'label' => 'Habilitada'], ['value' => '0', 'label' => 'Deshabilitada']]],
        ],
    ];
@endphp
<div data-sakai-form data-props="{{ json_encode($formProps, JSON_UNESCAPED_SLASHES) }}"></div>
