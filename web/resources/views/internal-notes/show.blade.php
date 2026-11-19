@extends('internal-notes.layout')
@section('title', 'Detalle de Nota Interna')

@section('content')
    <a href="{{ route('notes.index') }}">Volver a la bandeja</a>
    <h1>{{ $note->subject }}</h1>
    <section>
        <dl>
            <dt>CITE</dt><dd>{{ $note->cite ?? 'Por asignar' }}</dd>
            <dt>Estado</dt><dd>{{ $note->stateLabel() }}</dd>
            <dt>DE</dt><dd>{{ $note->author->name }} · {{ $note->origin->name }}</dd>
            <dt>A</dt><dd>{{ $note->recipient->name }}</dd>
            <dt>Unidad actual</dt><dd>{{ $data['unidad_actual']['nombre'] }}</dd>
            @if ($data['destino_pendiente'])
                <dt>Recepción pendiente en</dt><dd>{{ $data['destino_pendiente']['nombre'] }}</dd>
            @endif
            @if ($note->reference)
                <dt>Referencia</dt><dd>{{ $note->reference }}</dd>
            @endif
        </dl>
        <p class="body">{{ $note->body }}</p>
    </section>
    <section>
        <h2>Siguiente acción</h2>
        <div class="actions">
            @if (in_array('editar_borrador', $data['acciones_permitidas'], true))
                <a href="{{ route('notes.edit', $note) }}">Editar borrador</a>
            @endif
            @if (in_array('emitir', $data['acciones_permitidas'], true))
                <form method="post" action="{{ route('notes.emit', $note) }}">
                    @csrf
                    <input type="hidden" name="version" value="{{ $note->emission_version ?? $note->version }}">
                    <input type="hidden" name="request_key" value="{{ $note->emission_key ?? $actionKey }}">
                    <button>{{ $note->emission_key ? 'Reintentar emisión' : 'Emitir Nota Interna' }}</button>
                </form>
            @elseif (in_array('dar_conformidad', $data['acciones_permitidas'], true))
                <form method="post" action="{{ route('notes.approve', $note) }}">
                    @csrf
                    <input type="hidden" name="version" value="{{ $via->action_version ?? $note->version }}">
                    <input type="hidden" name="request_key" value="{{ $via->action_key ?? $actionKey }}">
                    <button>{{ $via->action_key ? 'Reintentar conformidad' : 'Dar conformidad' }}</button>
                </form>
            @elseif (in_array('confirmar_primera_recepcion', $data['acciones_permitidas'], true))
                <form method="post" action="{{ route('notes.receive', $note) }}">
                    @csrf
                    <input type="hidden" name="version" value="{{ $note->receipt_version ?? $note->version }}">
                    <input type="hidden" name="request_key" value="{{ $note->receipt_key ?? $actionKey }}">
                    <button>{{ $note->receipt_key ? 'Reintentar recepción' : 'Confirmar recepción' }}</button>
                </form>
            @elseif ($canOpenSheet)
                <a class="button" href="{{ route('documents.show', $note->document_id) }}">
                    {{ in_array('confirmar_recepcion_derivacion', $data['acciones_permitidas'], true) ? 'Abrir hoja para confirmar recepción' : 'Abrir hoja de ruta' }}
                </a>
            @elseif ($note->state === $note::RECEIVE)
                <p>Queda pendiente la recepción en {{ $note->recipient->name }}.</p>
            @else
                <p>No tienes una acción pendiente para esta nota.</p>
            @endif
        </div>
    </section>
    <section>
        <h2>Historial de la nota</h2>
        @if ($note->emitted_at)
            <p>{{ $note->emitted_at->timezone('America/La_Paz')->format('d/m/Y H:i') }} · Emisión de {{ $note->author->name }}</p>
        @endif
        @forelse ($note->participants->whereNotNull('confirmed_at') as $review)
            <p>{{ $review->confirmed_at->timezone('America/La_Paz')->format('d/m/Y H:i') }} · Conformidad de {{ $review->user->name }}</p>
        @empty
            <p>Todavía no hay conformidades registradas.</p>
        @endforelse
        @if ($canOpenSheet)
            @foreach ($note->document->sheet->movements as $movement)
                <p>
                    {{ $movement->occurred_at->timezone('America/La_Paz')->format('d/m/Y H:i') }}
                    · {{ match ($movement->action) {
                        'RECEPCION' => 'Recepción', 'DERIVACION' => 'Derivación', 'ATENCION' => 'Atención',
                        'RESPUESTA' => 'Respuesta', 'CIERRE' => 'Cierre', default => $movement->action,
                    } }}
                    · {{ $movement->actor->name }}
                    @if ($movement->destinationUnit)
                        · {{ $movement->destinationUnit->name }}
                    @endif
                    @if ($movement->reason)
                        · {{ $movement->reason }}
                    @endif
                </p>
            @endforeach
        @endif
    </section>
@endsection
