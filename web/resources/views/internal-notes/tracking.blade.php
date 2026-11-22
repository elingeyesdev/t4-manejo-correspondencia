<section class="note-tracking" aria-label="Seguimiento de la nota" data-note-tracking="{{ route('notes.tracking', $note, false) }}">
    <ol class="note-tracking-stages" role="list">
        @foreach (['preparacion' => 'Preparación', 'revision' => 'Revisión VÍA', 'recepcion' => 'Recepción', 'atencion' => 'Atención', 'cierre' => 'Cierre'] as $stage => $label)
            <li data-tracking-stage="{{ $stage }}" @if ($stage === $progress['etapa']) aria-current="step" @endif>
                <span class="note-tracking-envelope" aria-hidden="true">✉</span>
                {{ $label }}
            </li>
        @endforeach
    </ol>
    <p class="note-tracking-summary" role="status">
        <strong data-tracking-label>{{ $progress['etiqueta'] }}</strong>
        <span data-tracking-unit>{{ $progress['unidad']['nombre'] }}</span>
    </p>
    <p class="note-tracking-message text-body-secondary" role="status" hidden></p>
</section>
