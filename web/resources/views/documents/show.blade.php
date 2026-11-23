@extends('layout')
@section('title', 'Detalle de correspondencia')
@section('content')
    @php
        $actions = $payload['acciones_permitidas'];
        $workflows = [];
        $pending = $document->rootDocument()->sheet->camunda_transition;
        if (($pending['actor_id'] ?? null) !== auth()->id()) {
            $pending = null;
        }

        $addWorkflow = function ($operation, $label, $submitLabel, $help, $fields = [], $action = null) use (&$workflows, $payload, $errors, $pending) {
            $formKey = 'route-'.$operation;
            $submitted = old('_form') === $formKey;
            $version = $payload['hoja']['version'];
            $oldVersion = old('version');
            $requestKey = $submitted && is_scalar($oldVersion) && (string) $oldVersion === (string) $version
                ? old('request_key')
                : null;
            $pendingOperation = ['attend' => 'atencion', 'derive' => 'derivacion', 'receive' => 'recepcion', 'close' => 'cierre'][$operation] ?? null;
            $retry = $pending !== null && $pending['operation'] === $pendingOperation ? $pending : null;
            $initial = [];
            foreach ($fields as $field) {
                $value = $submitted ? old($field['name']) : null;
                if ($retry) {
                    $value = $retry['intent'][$field['name']] ?? $value;
                }
                $initial[$field['name']] = is_scalar($value) ? (string) $value : '';
            }

            $workflows[] = [
                'action' => $action ?? route('route-sheets.'.$operation, $payload['hoja']['id']),
                'formKey' => $formKey,
                'formLabel' => $label, 'retry' => $retry !== null,
                'submitLabel' => $submitLabel,
                'help' => $help,
                'hidden' => [
                    'version' => $version,
                    'request_key' => $retry['key'] ?? (is_string($requestKey) && preg_match('/^[A-Za-z0-9_-]{16,100}$/D', $requestKey)
                        ? $requestKey
                        : (string) \Illuminate\Support\Str::uuid()),
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
                'subject' => $document->subject, 'sender' => $document->sender,
                'receivedOn' => $document->received_on->format('d/m/Y'),
                'unit' => $document->unit->name, 'type' => $document->type->name,
                'priority' => $document->priority->name,
            ],
            'sheet' => [
                'state' => $payload['estado'],
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
    <div id="document-detail">
        <a class="back-link" href="{{ $detailProps['indexUrl'] }}">Volver a documentos</a>
        <div class="page-heading">
            <h1>{{ $detailProps['document']['subject'] }}</h1>
            @include('partials.sheet-state', ['state' => $detailProps['sheet']['state']])
        </div>
        @if ($detailProps['sheet']['state'] === 'CERRADA')
            <p class="alert notice-success" role="status"><strong>Expediente cerrado.</strong> Sus datos, archivos e historial están disponibles para consulta.</p>
        @endif
        <section class="note-section wide-section" aria-labelledby="vista-previa-titulo">
            <h2 id="vista-previa-titulo">Vista previa del documento</h2>
            @include('documents.preview', ['compact' => false])
            @if ($document->internalNote)
                <p class="mt-2 mb-0"><a href="{{ route('notes.show', $document->internalNote) }}">Abrir Nota Interna</a></p>
            @endif
        </section>
        @if ($receiptStamp)
            <section class="note-section wide-section" aria-labelledby="sello-titulo">
                <h2 id="sello-titulo">Constancia de recepción</h2>
                @include('internal-notes.receipt-stamp', ['stamp' => $receiptStamp])
            </section>
        @endif
        <div class="row g-4">
            <section class="col-12 col-lg-6" aria-labelledby="documento-titulo">
                <div class="note-section">
                    <h2 id="documento-titulo">Documento</h2>
                    <dl class="note-record mb-0">
                        @if ($document->internalNote?->cite)
                            <div><dt>CITE</dt><dd>{{ $document->internalNote->cite }}</dd></div>
                        @endif
                        <div><dt>Remitente</dt><dd>{{ $detailProps['document']['sender'] }}</dd></div>
                        <div><dt>Fecha de recepción</dt><dd>{{ $detailProps['document']['receivedOn'] }}</dd></div>
                        <div><dt>Unidad</dt><dd>{{ $detailProps['document']['unit'] }}</dd></div>
                        <div><dt>Tipo y prioridad</dt><dd>{{ $detailProps['document']['type'] }} · {{ $detailProps['document']['priority'] }}</dd></div>
                    </dl>
                </div>
            </section>
            <section class="col-12 col-lg-6" aria-labelledby="hoja-titulo">
                <div class="note-section">
                    <h2 id="hoja-titulo">Hoja de ruta</h2>
                    <dl class="note-record mb-0">
                        <div><dt>Responsable actual</dt><dd>{{ $detailProps['sheet']['responsible'] }}</dd></div>
                        <div><dt>Estado</dt><dd>@include('partials.sheet-state', ['state' => $detailProps['sheet']['state']])</dd></div>
                        <div><dt>Unidad vigente</dt><dd>{{ $detailProps['sheet']['currentUnit'] }}</dd></div>
                        @if ($detailProps['sheet']['pendingUnit'])
                            <div><dt>Destino pendiente</dt><dd>{{ $detailProps['sheet']['pendingUnit'] }}</dd></div>
                        @endif
                    </dl>
                </div>
            </section>
        </div>
        @if ($workflows)
            <section class="note-section wide-section" aria-labelledby="acciones-titulo">
                <h2 id="acciones-titulo">Acciones del expediente</h2>
                <div class="admin-list">
                    @foreach ($workflows as $workflow)
                        <details class="admin-item" @if (count($workflows) === 1 || old('_form') === $workflow['formKey'] || $workflow['retry']) open @endif>
                            <summary>{{ $workflow['formLabel'] }}</summary>
                            <div class="note-form mt-3 mb-2">@include('partials.form', ['form' => $workflow])</div>
                        </details>
                    @endforeach
                </div>
            </section>
        @endif
        <section class="note-section wide-section" aria-labelledby="qr-titulo">
            <h2 id="qr-titulo">QR de la hoja de ruta</h2>
            <div class="d-flex align-items-start flex-wrap gap-3">
                <img src="{{ $detailProps['qr']['imageUrl'] }}" alt="Código QR de la hoja de ruta"
                    width="144" height="144" class="route-qr" loading="lazy">
                <div>
                    <p class="mb-2">Escanea el código para consultar esta hoja de ruta.</p>
                    <a href="{{ $detailProps['qr']['consultUrl'] }}">Consultar hoja de ruta</a>
                </div>
            </div>
        </section>
        <section class="note-section wide-section" aria-labelledby="historial-titulo">
            <h2 id="historial-titulo">Historial documental</h2>
            <div class="table-responsive notes-table-scroll" tabindex="0" role="region" aria-label="Movimientos del expediente">
                <table class="table notes-table movement-table">
                    <thead>
                        <tr>
                            <th scope="col">Acción</th><th scope="col">Realizado por</th><th scope="col">Unidad de origen</th>
                            <th scope="col">Unidad de destino</th><th scope="col">Fecha y hora · Bolivia</th>
                            <th scope="col">Estado resultante</th><th scope="col">Motivo u observación</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse ($detailProps['movements'] as $event)
                            <tr>
                                <th scope="row">{{ \Illuminate\Support\Str::headline(strtolower($event['action'])) }}</th>
                                <td>{{ $event['actor'] }}</td><td>{{ $event['originUnit'] }}</td><td>{{ $event['destinationUnit'] }}</td>
                                <td>{{ $event['date'] }}</td><td>@include('partials.sheet-state', ['state' => $event['state']])</td>
                                <td class="note-body">{{ $event['reason'] }}</td>
                            </tr>
                        @empty
                            <tr><td colspan="7" class="empty-cell">No hay movimientos registrados para este documento.</td></tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        </section>
    </div>
    @if ($payload['documento_original'])
        <section class="note-section wide-section">
            <h2>Documento original</h2>
            <a class="link-offset-2" href="{{ route('documents.show', $payload['documento_original']['id']) }}">
                {{ $payload['documento_original']['asunto'] }}
            </a>
        </section>
    @elseif ($payload['respuestas'])
        <section class="note-section wide-section">
            <h2>Respuestas vinculadas</h2>
            <ul class="mb-0">
                @foreach ($payload['respuestas'] as $response)
                    <li>
                        <a class="link-offset-2" href="{{ route('documents.show', $response['id']) }}">
                            {{ $response['asunto'] }}
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
