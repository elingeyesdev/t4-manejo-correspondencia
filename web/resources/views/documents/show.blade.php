@extends('layout')
@section('title', 'Detalle de correspondencia')
@section('content')
    @php
        $canDerive = in_array('derivar', $payload['acciones_permitidas'], true) && $destinations->isNotEmpty();
        $canReceive = in_array('recibir', $payload['acciones_permitidas'], true);
        $workflow = null;

        if ($canDerive || $canReceive) {
            $formKey = $canDerive ? 'route-derive' : 'route-receive';
            $requestKey = old('_form') === $formKey ? old('request_key') : null;
            $reason = old('motivo');
            $destination = old('destino_unidad_id');

            $workflow = [
                'action' => route($canDerive ? 'route-sheets.derive' : 'route-sheets.receive', $payload['hoja']['id']),
                'csrfToken' => csrf_token(),
                'formKey' => $formKey,
                'formLabel' => $canDerive ? 'Derivar hoja' : 'Confirmar recepción',
                'submitLabel' => $canDerive ? 'Derivar' : 'Confirmar recepción',
                'help' => $canDerive
                    ? 'La responsabilidad actual se conserva hasta que la unidad de destino confirme la recepción.'
                    : 'Al confirmar, quedas como responsable de la hoja en tu unidad.',
                'hidden' => [
                    'version' => $payload['hoja']['version'],
                    'request_key' => is_string($requestKey) && preg_match('/^[A-Za-z0-9_-]{16,100}$/D', $requestKey)
                        ? $requestKey
                        : (string) \Illuminate\Support\Str::uuid(),
                ],
                'initial' => [
                    'motivo' => is_string($reason) ? $reason : '',
                    'destino_unidad_id' => is_scalar($destination) ? (string) $destination : '',
                ],
                'errors' => (object) $errors->messages(),
                'fields' => $canDerive ? [
                    ['name' => 'destino_unidad_id', 'label' => 'Unidad de destino', 'type' => 'select', 'required' => true,
                        'options' => $destinations->map(fn ($unit) => ['value' => (string) $unit->id, 'label' => $unit->name])->all()],
                    ['name' => 'motivo', 'label' => 'Motivo', 'type' => 'textarea', 'required' => true,
                        'maxCodePoints' => 500, 'help' => 'Hasta 500 caracteres.', 'wide' => true],
                ] : [],
            ];
        }
        $detailProps = [
            'document' => [
                'code' => $document->code, 'guide' => $document->guide,
                'subject' => $document->subject, 'sender' => $document->sender,
                'receivedOn' => $document->received_on->format('d/m/Y'),
                'unit' => $document->unit->name, 'type' => $document->type->name,
                'priority' => $document->priority->name,
            ],
            'sheet' => [
                'code' => $payload['hoja']['codigo'], 'state' => $payload['estado'],
                'version' => $payload['hoja']['version'],
                'responsible' => $payload['hoja']['responsable']['nombre'],
                'currentUnit' => $payload['hoja']['unidad_vigente']['nombre'],
                'pendingUnit' => $document->sheet->pendingUnit?->name,
            ],
            'movements' => collect($history['data'])->map(fn ($event) => [
                'id' => $event['id'],
                'action' => $event['accion'],
                'actor' => $event['actor']['nombre'] ?? 'No disponible',
                'originUnit' => $event['unidad_origen']['nombre'] ?? 'No registrada',
                'destinationUnit' => $event['unidad_destino']['nombre'] ?? 'No registrada',
                'date' => \Carbon\CarbonImmutable::parse($event['fecha'])
                    ->timezone('America/La_Paz')
                    ->format('d/m/Y H:i:s'),
                'state' => $event['estado_resultante'],
                'reason' => $event['motivo'] ?? '—',
            ])->values()->all(),
            'qr' => [
                'imageUrl' => route('route-sheets.qr', [
                    'reference' => $payload['hoja']['id'],
                ]),
                'consultUrl' => route('route-sheets.show', [
                    'reference' => $payload['hoja']['id'],
                ]),
            ],
            'workflow' => $workflow,
            'indexUrl' => route('documents.index'),
        ];
    @endphp
    <div id="document-detail" data-props="{{ json_encode($detailProps, JSON_UNESCAPED_SLASHES) }}"></div>
    @include('documents.attachments')
@endsection
