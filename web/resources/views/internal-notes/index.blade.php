@extends('internal-notes.layout')
@section('title', 'Bandeja de Nota Interna')

@section('content')
    <h1>Bandeja de Nota Interna</h1>
    <nav aria-label="Bandejas de Nota Interna">
        @foreach (['mis_notas' => 'Mis notas', 'por_revisar' => 'Por revisar', 'por_recibir' => 'Por recibir', 'copias' => 'Copias'] as $key => $label)
            <a href="{{ route('notes.index', ['bandeja' => $key]) }}" @if ($tray === $key) aria-current="page" @endif>{{ $label }}</a>
        @endforeach
        <a class="button" href="{{ route('notes.create') }}">Nueva nota</a>
    </nav>
    <section class="table-scroll" aria-label="Resultados">
        <table>
            <thead><tr><th scope="col">CITE</th><th scope="col">Asunto</th><th scope="col">Unidad de origen</th><th scope="col">Unidad destinataria</th><th scope="col">Fecha</th><th scope="col">Estado</th></tr></thead>
            <tbody>
                @forelse ($notes as $note)
                    <tr>
                        <td>{{ $note->cite ?? 'Por asignar' }}</td>
                        <td><a href="{{ route('notes.show', $note) }}">{{ $note->subject }}</a></td>
                        <td>{{ $note->origin->name }}</td>
                        <td>{{ $note->recipient->name }}</td>
                        <td>{{ $note->updated_at->timezone('America/La_Paz')->format('d/m/Y H:i') }}</td>
                        <td>{{ $note->stateLabel() }}</td>
                    </tr>
                @empty
                    <tr><td colspan="6">No hay notas en esta bandeja.</td></tr>
                @endforelse
            </tbody>
        </table>
        <p>Página {{ $notes->currentPage() }} de {{ $notes->lastPage() }}</p>
        <nav aria-label="Paginación">
            @if ($notes->previousPageUrl()) <a href="{{ $notes->previousPageUrl() }}" rel="prev">Anterior</a> @endif
            @if ($notes->nextPageUrl()) <a href="{{ $notes->nextPageUrl() }}" rel="next">Siguiente</a> @endif
        </nav>
    </section>
@endsection
