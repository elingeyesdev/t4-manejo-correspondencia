<span class="note-state" data-state="{{ $note->displayState() }}">
    @if ($note->state === $note::DRAFT && $note->current_sender_signed)
        Borrador firmado
    @elseif ($note->state === $note::DRAFT && $note->signature_requested_at !== null)
        Pendiente de firma
    @else
        {{ $note->stateLabel() }}
    @endif
</span>
