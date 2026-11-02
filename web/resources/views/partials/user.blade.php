@php
    $formKey = 'user-'.($item?->id ?? 'new');
    $restoring = old('_form') === $formKey;
    $formProps = [
        'action' => url('/administracion/usuarios'.($item ? '/'.$item->id : '')),
        'csrfToken' => csrf_token(), 'method' => $item ? 'PUT' : 'POST',
        'formKey' => $formKey, 'formLabel' => $item ? 'Editar usuario '.$item->name : 'Agregar usuario',
        'submitLabel' => 'Guardar usuario',
        'help' => 'Una actualización invalida las sesiones anteriores del usuario. Las contraseñas requieren al menos 12 caracteres con letras y números.',
        'initial' => [
            'name' => $restoring ? old('name') : ($item?->name ?? ''),
            'email' => $restoring ? old('email') : ($item?->email ?? ''),
            'unit_id' => (string) ($restoring ? old('unit_id') : ($item?->unit_id ?? '')),
            'role' => $restoring ? old('role') : ($item?->role ?? 'funcionario'),
            'enabled' => (string) ($restoring ? old('enabled') : (int) ($item?->enabled ?? true)),
        ],
        'errors' => (object) ($restoring ? $errors->messages() : []),
        'fields' => [
            ['name' => 'name', 'label' => 'Nombre', 'required' => true, 'maxLength' => 150],
            ['name' => 'email', 'label' => 'Correo', 'type' => 'email', 'required' => true, 'maxLength' => 255],
            ['name' => 'unit_id', 'label' => 'Unidad', 'type' => 'select', 'required' => true,
                'options' => $units->where('enabled', true)->map(fn ($unit) => ['value' => (string) $unit->id, 'label' => $unit->name])->values()->all()],
            ['name' => 'role', 'label' => 'Rol', 'type' => 'select', 'required' => true,
                'options' => [['value' => 'administrador', 'label' => 'Administrador'], ['value' => 'recepcion', 'label' => 'Recepción'], ['value' => 'funcionario', 'label' => 'Funcionario']]],
            ['name' => 'password', 'label' => 'Contraseña', 'type' => 'password', 'required' => ! $item, 'minLength' => 12,
                'help' => $item ? 'Deja vacía para conservar la contraseña actual.' : 'Al menos 12 caracteres con letras y números.'],
            ['name' => 'password_confirmation', 'label' => 'Confirmar contraseña', 'type' => 'password', 'required' => ! $item],
            ['name' => 'enabled', 'label' => 'Estado', 'type' => 'select', 'required' => true,
                'options' => [['value' => '1', 'label' => 'Habilitado'], ['value' => '0', 'label' => 'Deshabilitado']]],
        ],
    ];
@endphp
<div data-sakai-form data-props="{{ json_encode($formProps, JSON_UNESCAPED_SLASHES) }}"></div>
