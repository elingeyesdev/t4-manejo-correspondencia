@php
    $pdfUrl = route('notes.download', $institutionalNote, false);
    $htmlUrl = route('notes.document', $institutionalNote, false);
    $usesPdf = app(\App\Services\InstitutionalNoteDocument::class)->configured();
@endphp
<div data-note-viewer data-source="{{ $usesPdf ? $pdfUrl : $htmlUrl }}"
     data-revision="{{ $institutionalNote->version }}:{{ $institutionalNote->stateLabel() }}">
    <div class="actions mb-2">
        @if ($usesPdf)
            <a href="{{ route('notes.download', [$institutionalNote, 'version' => $institutionalNote->version], false) }}"
               data-versioned-pdf target="_blank" rel="noopener" class="btn btn-outline-secondary btn-sm">Abrir PDF para imprimir</a>
            <a href="{{ route('notes.download', [$institutionalNote, 'version' => $institutionalNote->version, 'descargar' => 1], false) }}"
               data-versioned-pdf class="btn btn-outline-secondary btn-sm">Descargar PDF</a>
            <a href="{{ $htmlUrl }}" target="_blank" rel="noopener">Leer en formato web</a>
        @else
            <a href="{{ $htmlUrl }}" target="_blank" rel="noopener">Abrir la hoja en otra pestaña</a>
            <span class="form-text">Exportación PDF pendiente de configuración en el servidor.</span>
        @endif
    </div>
    <iframe class="document-preview-pdf" src="{{ $usesPdf ? route('notes.download', [$institutionalNote, 'version' => $institutionalNote->version], false) : $htmlUrl }}"
            title="Documento completo de la nota interna"></iframe>
</div>
