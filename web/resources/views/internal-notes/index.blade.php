@extends('internal-notes.layout')
@section('title', 'Bandeja de Nota Interna')

@section('content')
    <header class="page-heading">
        <h1>Bandeja de Nota Interna</h1>
        <a class="btn btn-primary" href="{{ route('notes.create') }}">Nueva nota</a>
    </header>

    <nav class="nav nav-tabs tray-nav" aria-label="Bandejas de Nota Interna">
        @foreach (['mis_notas' => 'Mis notas', 'por_revisar' => 'Por revisar', 'por_recibir' => 'Por recibir', 'por_atender' => 'Por atender', 'copias' => 'Copias'] as $key => $label)
            <a class="nav-link @if ($tray === $key) active @endif" href="{{ route('notes.index', ['bandeja' => $key]) }}"
               @if ($tray === $key) aria-current="page" @endif>{{ $label }}</a>
        @endforeach
    </nav>

    <div class="table-responsive notes-table-scroll" role="region" aria-label="Resultados de la bandeja" tabindex="0">
        <table class="table table-sm notes-table">
            <thead>
                <tr>
                    <th scope="col">CITE</th>
                    <th scope="col">Asunto</th>
                    <th scope="col">Unidad de origen</th>
                    <th scope="col">Unidad destinataria</th>
                    <th scope="col">Fecha</th>
                    <th scope="col">Estado</th>
                </tr>
            </thead>
            <tbody>
                @forelse ($notes as $note)
                    @php($date = ($note->document?->sheet?->updated_at ?? $note->updated_at)->timezone('America/La_Paz'))
                    <tr>
                        <td class="note-cite">{{ $note->cite ?? 'Por asignar' }}</td>
                        <th scope="row"><a href="{{ route('notes.show', $note) }}">{{ $note->subject }}</a></th>
                        <td>{{ $note->origin->name }}</td>
                        <td>{{ $note->recipient->name }}</td>
                        <td><time datetime="{{ $date->toIso8601String() }}">{{ $date->format('d/m/Y H:i') }}</time></td>
                        <td>@include('internal-notes.state', ['note' => $note])</td>
                    </tr>
                @empty
                    <tr><td class="empty-cell" colspan="6">No hay notas en esta bandeja.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>

    <nav class="notes-pagination" aria-label="Paginación">
        <span>Página {{ $notes->currentPage() }} de {{ $notes->lastPage() }}</span>
        @if ($notes->previousPageUrl()) <a href="{{ $notes->previousPageUrl() }}" rel="prev">Anterior</a> @endif
        @if ($notes->nextPageUrl()) <a href="{{ $notes->nextPageUrl() }}" rel="next">Siguiente</a> @endif
    </nav>
@endsection
