@extends('layout')
@section('title', 'Detalle de correspondencia')
@section('content')
    @php
        $actions = $payload['acciones_permitidas'];
        $workflows = [];

        $addWorkflow = function ($operation, $label, $submitLabel, $help, $fields = [], $action = null) use (&$workflows, $payload, $errors) {
            $formKey = 'route-'.$operation;
            $submitted = old('_form') === $formKey;
            $version = $payload['hoja']['version'];
            $oldVersion = old('version');
            $requestKey = $submitted && is_scalar($oldVersion) && (string) $oldVersion === (string) $version
                ? old('request_key')
                : null;
            $initial = [];
            foreach ($fields as $field) {
                $value = $submitted ? old($field['name']) : null;
                $initial[$field['name']] = is_scalar($value) ? (string) $value : '';
            }

            $workflows[] = [
                'action' => $action ?? route('route-sheets.'.$operation, $payload['hoja']['id']),
                'csrfToken' => csrf_token(),
                'formKey' => $formKey,
                'formLabel' => $label,
                'submitLabel' => $submitLabel,
                'help' => $help,
                'hidden' => [
                    'version' => $version,
                    'request_key' => is_string($requestKey) && preg_match('/^[A-Za-z0-9_-]{16,100}$/D', $requestKey)
                        ? $requestKey
                        : (string) \Illuminate\Support\Str::uuid(),
                ],
                'initial' => (object) $initial,
                'errors' => (object) ($submitted ? $errors->messages() : []),
                'fields' => $fields,
            ];
        };

        if (in_array('atender', $actions, true)) {
            $addWorkflow('attend', 'Registrar atención', 'Guardar atención',
                'Cada observación se agrega al historial con tu nombre y la hora del servidor.', [
                    ['name' => 'observacion', 'label' => 'Observación', 'type' => 'textarea', 'required' => true,
                        'maxCodePoints' => 2000, 'help' => 'Hasta 2 000 caracteres.', 'wide' => true],
                ]);
        }
        if (in_array('responder', $actions, true)) {
            $catalogOptions = fn ($kind) => $responseCatalogs->get($kind, collect())
                ->map(fn ($item) => ['value' => (string) $item->id, 'label' => $item->name])->all();

            $addWorkflow('respond', 'Vincular respuesta', 'Guardar respuesta',
                'La respuesta se incorpora a este expediente con su propio código.', [
                    ['name' => 'remitente', 'label' => 'Remitente', 'required' => true, 'maxLength' => 150],
                    ['name' => 'fecha', 'label' => 'Fecha del documento', 'type' => 'date', 'required' => true],
                    ['name' => 'asunto', 'label' => 'Asunto', 'type' => 'textarea', 'required' => true, 'maxLength' => 500, 'wide' => true],
                    ['name' => 'tipo_id', 'label' => 'Tipo de documento', 'type' => 'select', 'required' => true, 'options' => $catalogOptions('tipo')],
                    ['name' => 'prioridad_id', 'label' => 'Prioridad', 'type' => 'select', 'required' => true, 'options' => $catalogOptions('prioridad')],
                ], route('documents.responses.store', $document->id));
        }
        if (in_array('derivar', $actions, true) && $destinations->isNotEmpty()) {
            $addWorkflow('derive', 'Derivar hoja', 'Derivar',
                'La responsabilidad actual se conserva hasta que la unidad de destino confirme la recepción.', [
                    ['name' => 'destino_unidad_id', 'label' => 'Unidad de destino', 'type' => 'select', 'required' => true,
                        'options' => $destinations->map(fn ($unit) => ['value' => (string) $unit->id, 'label' => $unit->name])->all()],
                    ['name' => 'motivo', 'label' => 'Motivo', 'type' => 'textarea', 'required' => true,
                        'maxCodePoints' => 500, 'help' => 'Hasta 500 caracteres.', 'wide' => true],
                ]);
        }
        if (in_array('recibir', $actions, true)) {
            $addWorkflow('receive', 'Confirmar recepción', 'Confirmar recepción',
                'Al confirmar, quedas como responsable de la hoja en tu unidad.');
        }
        if (in_array('cerrar', $actions, true)) {
            $addWorkflow('close', 'Cerrar expediente', 'Cerrar expediente',
                'El expediente cerrado y su historial seguirán disponibles para consulta.', [
                    ['name' => 'motivo', 'label' => 'Motivo del cierre', 'type' => 'textarea', 'required' => true,
                        'maxCodePoints' => 500, 'help' => 'Hasta 500 caracteres.', 'wide' => true],
                    ['name' => 'confirmar', 'label' => 'Confirmo el cierre de este expediente', 'type' => 'checkbox',
                        'required' => true, 'wide' => true],
                ]);
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
                'pendingUnit' => $document->rootDocument()->sheet->pendingUnit?->name,
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
            'workflows' => $workflows,
            'indexUrl' => route('documents.index'),
        ];
    @endphp
    <div id="document-detail" data-props="{{ json_encode($detailProps, JSON_UNESCAPED_SLASHES) }}"></div>
    @if ($payload['documento_original'])
        <section class="card">
            <h2 class="text-xl font-semibold mt-0 mb-4">Documento original</h2>
            <a class="text-primary underline" href="{{ route('documents.show', $payload['documento_original']['id']) }}">
                {{ $payload['documento_original']['codigo'] }} · {{ $payload['documento_original']['asunto'] }}
            </a>
        </section>
    @elseif ($payload['respuestas'])
        <section class="card">
            <h2 class="text-xl font-semibold mt-0 mb-4">Respuestas vinculadas</h2>
            <ul class="list-disc pl-5 space-y-2">
                @foreach ($payload['respuestas'] as $response)
                    <li>
                        <a class="text-primary underline" href="{{ route('documents.show', $response['id']) }}">
                            {{ $response['codigo'] }} · {{ $response['asunto'] }}
                        </a>
                    </li>
                @endforeach
            </ul>
        </section>
    @endif
    @if ($document->response_to_id === null)
        @include('documents.attachments')
    @endif
@endsection
