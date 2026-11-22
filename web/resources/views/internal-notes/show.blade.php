@extends('layout')
@section('title', 'Detalle de Nota Interna')

@section('content')
    <a class="back-link" href="{{ route('notes.index') }}">Volver a la bandeja</a>
    <header class="page-heading note-heading">
        <div>
            <h1>{{ $note->subject }}</h1>
            <p class="note-cite"><strong>CITE</strong> <span data-tracking-cite>{{ $note->cite ?? 'Por asignar' }}</span></p>
        </div>
        @include('internal-notes.state', ['note' => $note])
    </header>

    @include('internal-notes.tracking', ['progress' => $data['seguimiento']])

    <section class="note-section" aria-labelledby="datos-nota">
        <h2 id="datos-nota">Datos de la nota</h2>
        <dl class="note-record">
            <div><dt>DE</dt><dd>{{ $note->author->name }} · {{ $note->origin->name }}</dd></div>
            <div><dt>A</dt><dd>{{ $note->recipient->name }}</dd></div>
            <div><dt>Unidad actual</dt><dd data-tracking-current>{{ $data['unidad_actual']['nombre'] }}</dd></div>
            <div data-tracking-destination @if ($data['destino_pendiente'] === null) hidden @endif>
                <dt>Recepción pendiente en</dt><dd>{{ $data['destino_pendiente']['nombre'] ?? '' }}</dd>
            </div>
            @if ($note->reference)
                <div><dt>Referencia</dt><dd>{{ $note->reference }}</dd></div>
            @endif
        </dl>
        <h3>Contenido</h3>
        <p class="note-body">{{ $note->body }}</p>
    </section>
    <section class="note-section next-action" aria-labelledby="siguiente-accion">
        <h2 id="siguiente-accion">Siguiente acción</h2>
        <div class="actions">
            @if (in_array('editar_borrador', $data['acciones_permitidas'], true))
                <a class="btn btn-outline-secondary" href="{{ route('notes.edit', $note) }}">Editar borrador</a>
            @endif
            @if (in_array('enviar_a_firma', $data['acciones_permitidas'], true))
                <form method="post" action="{{ route('notes.request-signature', $note) }}">
                    @csrf
                    <input type="hidden" name="version" value="{{ $note->version }}">
                    <button type="submit" class="btn btn-primary">Enviar a firma</button>
                </form>
            @elseif (in_array('firmar_borrador', $data['acciones_permitidas'], true))
                <form method="post" action="{{ route('notes.sign', $note) }}" data-note-signature>
                    @csrf
                    <input type="hidden" name="version" value="{{ $note->version }}">
                    <input type="hidden" name="request_key" value="{{ $actionKey }}">
                    @include('internal-notes.signature', ['version' => $note->version])
                    <button type="submit" class="btn btn-primary">Firmar borrador</button>
                </form>
            @elseif (in_array('emitir', $data['acciones_permitidas'], true))
                <form method="post" action="{{ route('notes.emit', $note) }}">
                    @csrf
                    <input type="hidden" name="version" value="{{ $note->emission_version ?? $note->version }}">
                    <input type="hidden" name="request_key" value="{{ $note->emission_key ?? $actionKey }}">
                    <button type="submit" class="btn btn-primary">{{ $note->emission_key ? 'Reintentar emisión' : 'Emitir Nota Interna' }}</button>
                </form>
            @elseif (in_array('dar_conformidad', $data['acciones_permitidas'], true))
                <form method="post" action="{{ route('notes.approve', $note) }}" @unless ($retryVia) data-note-signature @endunless>
                    @csrf
                    <input type="hidden" name="version" value="{{ $via->action_version ?? $note->version }}">
                    <input type="hidden" name="request_key" value="{{ $via->action_key ?? $actionKey }}">
                    @unless ($retryVia)
                        @include('internal-notes.signature', ['version' => $via->action_version ?? $note->version])
                    @endunless
                    <button type="submit" class="btn btn-primary">{{ $retryVia ? 'Reintentar conformidad' : 'Firmar y dar conformidad' }}</button>
                </form>
            @elseif (in_array('confirmar_primera_recepcion', $data['acciones_permitidas'], true))
                <form method="post" action="{{ route('notes.receive', $note) }}">
                    @csrf
                    <input type="hidden" name="version" value="{{ $note->receipt_version ?? $note->version }}">
                    <input type="hidden" name="request_key" value="{{ $note->receipt_key ?? $actionKey }}">
                    <button type="submit" class="btn btn-primary">{{ $note->receipt_key ? 'Reintentar recepción' : 'Confirmar recepción' }}</button>
                </form>
            @elseif ($canOpenSheet)
                <a class="btn btn-primary" href="{{ route('documents.show', $note->document_id) }}">
                    {{ in_array('confirmar_recepcion_derivacion', $data['acciones_permitidas'], true) ? 'Abrir hoja para confirmar recepción' : 'Abrir hoja de ruta' }}
                </a>
            @else
                <p>No tienes una acción pendiente para esta nota.</p>
            @endif
        </div>
    </section>
    <section class="note-section" aria-labelledby="historial-nota">
        <h2 id="historial-nota">Historial de la nota</h2>
        @if ($note->emitted_at)
            <ol class="note-history">
                @include('internal-notes.history-entry', [
                    'date' => $note->emitted_at,
                    'action' => 'Emisión',
                    'actor' => $note->author->name,
                ])
                @foreach ($note->participants->whereNotNull('confirmed_at') as $review)
                    @include('internal-notes.history-entry', [
                        'date' => $review->confirmed_at,
                        'action' => 'Conformidad',
                        'actor' => $review->user->name,
                    ])
                @endforeach
                @if ($canOpenSheet)
                    @foreach ($note->document->sheet->movements as $movement)
                        @include('internal-notes.history-entry', [
                            'date' => $movement->occurred_at,
                            'action' => match ($movement->action) {
                                'RECEPCION' => 'Recepción', 'DERIVACION' => 'Derivación', 'ATENCION' => 'Atención',
                                'RESPUESTA' => 'Respuesta', 'CIERRE' => 'Cierre', default => $movement->action,
                            },
                            'actor' => $movement->actor->name,
                            'unit' => $movement->destinationUnit?->name,
                            'reason' => $movement->reason,
                        ])
                    @endforeach
                @endif
            </ol>
        @else
            <p class="text-secondary mb-0">Todavía no hay movimientos registrados.</p>
        @endif
    </section>
    <script src="{{ asset('js/note-tracking.js') }}" defer></script>
@endsection
