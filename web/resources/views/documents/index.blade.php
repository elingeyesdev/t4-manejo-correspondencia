@extends('layout')
@section('title', 'Documentos')
@section('content')
    <div data-refresh-list>
    <div class="page-heading">
        <div>
            <h1>Correspondencia registrada</h1>
            <p class="text-secondary mb-0 mt-1">{{ $documents->total() }} {{ $documents->total() === 1 ? 'registro disponible' : 'registros disponibles' }}</p>
        </div>
        <div class="actions">
            @if (auth()->user()->role === 'funcionario')
                <a class="btn btn-outline-secondary" href="{{ route('notes.index', ['bandeja' => 'por_recibir']) }}">Notas por recibir</a>
            @endif
            @if (auth()->user()->canRegister())
                <a class="btn btn-primary" href="{{ route('documents.create') }}">Nueva correspondencia</a>
            @endif
        </div>
    </div>
    <div class="table-responsive notes-table-scroll" tabindex="0" role="region" aria-label="Correspondencia registrada">
        <table class="table notes-table">
            <thead>
                <tr>
                    <th scope="col">Vista previa</th><th scope="col">Asunto y remitente</th>
                    <th scope="col">Unidad</th><th scope="col">Estado</th><th scope="col">Consulta</th>
                </tr>
            </thead>
            <tbody>
                @forelse ($documents as $document)
                    <tr>
                        <td class="document-preview-cell">@include('documents.preview', ['compact' => true])</td>
                        <th scope="row">{{ $document->subject }}<br><small class="text-secondary fw-normal">{{ $document->sender }}</small></th>
                        <td>{{ $document->unit->name }}</td>
                        <td>@include('partials.sheet-state', ['state' => $document->sheet->state])</td>
                        <td><a href="{{ route('documents.show', $document->id) }}" aria-label="Abrir documento: {{ $document->subject }}">Abrir documento</a></td>
                    </tr>
                @empty
                    <tr><td colspan="5" class="empty-cell">No hay documentos disponibles.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
    @include('partials.pagination', ['paginator' => $documents->withQueryString(), 'label' => 'Páginas de documentos'])
    </div>
    <script src="{{ asset('js/document-list-refresh.js') }}" defer></script>
@endsection
