<section id="adjuntos" class="note-section wide-section" aria-labelledby="adjuntos-titulo">
    <h2 id="adjuntos-titulo">Adjuntos</h2>
    @if ($document->sheet->canUploadAttachment(auth()->user()))
        <form action="{{ route('attachments.store', $document->id) }}" method="post" enctype="multipart/form-data"
            class="note-form mb-4" aria-label="Adjuntar archivo" data-institutional-form>
            @csrf
            <label for="attachment-file" class="form-label">Selecciona un archivo</label>
            <input id="attachment-file" class="form-control" type="file" name="archivo" required
                accept=".pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png" aria-describedby="attachment-help" data-attachment>
            <p class="form-text" id="attachment-help">PDF, JPG o PNG · máximo 10 MiB.</p>
            <div class="actions">
                <button type="submit" class="btn btn-primary">Subir archivo</button>
                <button type="reset" class="btn btn-outline-secondary">Quitar selección</button>
            </div>
        </form>
    @endif
    <p class="text-secondary mb-2">Archivos guardados · {{ $attachments->total() }}</p>
    @if ($attachments->isEmpty())
        <p class="text-secondary mb-0">Esta correspondencia todavía no tiene adjuntos en esta página.</p>
    @else
        <ul class="list-group list-group-flush">
            @foreach ($attachments as $attachment)
                <li class="list-group-item px-0 d-flex justify-content-between align-items-start flex-wrap gap-2">
                    <div class="text-break">
                        <strong>{{ $attachment->original_name }}</strong>
                        <div class="text-secondary">
                            {{ $attachment->size_bytes < 1048576 ? ceil($attachment->size_bytes / 1024).' KB' : number_format($attachment->size_bytes / 1048576, 1).' MB' }}
                            · {{ $attachment->created_at->timezone('America/La_Paz')->format('d/m/Y H:i') }}
                        </div>
                    </div>
                    <div class="actions">
                        <a href="{{ route('attachments.view', [$document->id, $attachment->id]) }}" target="_blank" rel="noopener noreferrer" aria-label="Ver {{ $attachment->original_name }} en una pestaña nueva">Ver</a>
                        <a href="{{ route('attachments.download', [$document->id, $attachment->id]) }}" aria-label="Descargar {{ $attachment->original_name }}">Descargar</a>
                    </div>
                </li>
            @endforeach
        </ul>
    @endif
    @include('partials.pagination', ['paginator' => $attachments->withQueryString(), 'label' => 'Páginas de adjuntos', 'fragment' => '#adjuntos'])
</section>
