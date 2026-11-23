@if ($document->internalNote)
    <p class="note-body mb-0">{{ $compact ? \Illuminate\Support\Str::limit(\Illuminate\Support\Str::squish($document->internalNote->body), 120) : $document->internalNote->body }}</p>
@elseif ($preview = $document->previewAttachments->first())
    @php($previewUrl = route('attachments.view', [$document->id, $preview->id]))
    @if (str_starts_with($preview->mime_type, 'image/'))
        <img class="{{ $compact ? 'document-thumbnail' : 'document-preview-image' }}"
            src="{{ $previewUrl }}" alt="{{ $preview->original_name }}" @if ($compact) loading="lazy" @endif>
    @elseif (! $compact)
        <iframe class="document-preview-pdf" src="{{ $previewUrl }}" title="Vista previa de {{ $preview->original_name }}"></iframe>
    @endif
    @if (! $compact || $preview->mime_type === 'application/pdf')
        <p class="mt-2 mb-0">
            <a href="{{ $previewUrl }}" target="_blank" rel="noopener noreferrer">{{ $preview->original_name }}</a>
        </p>
    @endif
@else
    <p class="text-secondary mb-0">Sin archivo para previsualizar.</p>
@endif
