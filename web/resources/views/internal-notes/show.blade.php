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
    </section>
@endsection
