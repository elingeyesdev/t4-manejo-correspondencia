<span class="note-state" data-state="{{ strtolower($state) }}">
    {{ match ($state) {
        'PENDIENTE_RECEPCION' => 'Pendiente de recepción',
        'EN_ATENCION' => 'En atención',
        default => \Illuminate\Support\Str::headline(strtolower($state)),
    } }}
</span>
