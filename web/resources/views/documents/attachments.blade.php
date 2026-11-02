@php
    $attachmentsProps = [
        'canUpload' => auth()->user()->canRegister(),
        'uploadUrl' => route('attachments.store', $document->id),
        'csrfToken' => csrf_token(),
        'total' => $attachments->total(),
        'pageSize' => $attachments->perPage(),
        'currentPage' => $attachments->currentPage(),
        'records' => $attachments->map(fn ($attachment) => [
            'id' => $attachment->id, 'name' => $attachment->original_name,
            'mime' => $attachment->mime_type, 'size' => $attachment->size_bytes,
            'date' => $attachment->created_at->timezone('America/La_Paz')->format('d/m/Y H:i'),
            'viewUrl' => route('attachments.view', [$document->id, $attachment->id]),
            'downloadUrl' => route('attachments.download', [$document->id, $attachment->id]),
        ])->values()->all(),
    ];
@endphp
<section id="adjuntos" aria-label="Adjuntos de la correspondencia">
    <div id="document-attachments" data-props="{{ json_encode($attachmentsProps, JSON_UNESCAPED_SLASHES) }}"></div>
</section>
