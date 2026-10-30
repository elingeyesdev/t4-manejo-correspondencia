@php
    $formKey = 'catalog-'.($item?->id ?? 'new');
    $restoring = old('_form') === $formKey;
    $fields = [];
    if (! $item) {
        $fields[] = ['name' => 'kind', 'label' => 'Catálogo', 'type' => 'select', 'required' => true,
            'options' => [['value' => 'tipo', 'label' => 'Tipo de documento'], ['value' => 'prioridad', 'label' => 'Prioridad']]];
    }
    $fields = array_merge($fields, [
        ['name' => 'code', 'label' => 'Código', 'required' => true, 'maxLength' => 30, 'pattern' => '[A-Z0-9_-]+'],
        ['name' => 'name', 'label' => 'Nombre', 'required' => true, 'maxLength' => 150],
        ['name' => 'enabled', 'label' => 'Estado', 'type' => 'select', 'required' => true,
            'options' => [['value' => '1', 'label' => 'Habilitado'], ['value' => '0', 'label' => 'Deshabilitado']]],
    ]);
    $formProps = [
        'action' => url('/administracion/catalogos'.($item ? '/'.$item->id : '')),
        'csrfToken' => csrf_token(), 'method' => $item ? 'PUT' : 'POST',
        'formKey' => $formKey, 'formLabel' => $item ? 'Editar catálogo '.$item->name : 'Agregar catálogo',
        'submitLabel' => 'Guardar catálogo', 'hidden' => $item ? ['kind' => $item->kind] : (object) [],
        'initial' => [
            'kind' => $restoring ? old('kind') : 'tipo',
            'code' => $restoring ? old('code') : ($item?->code ?? ''),
            'name' => $restoring ? old('name') : ($item?->name ?? ''),
            'enabled' => (string) ($restoring ? old('enabled') : (int) ($item?->enabled ?? true)),
        ],
        'errors' => (object) ($restoring ? $errors->messages() : []), 'fields' => $fields,
    ];
@endphp
<div data-sakai-form data-props="{{ json_encode($formProps, JSON_UNESCAPED_SLASHES) }}"></div>
