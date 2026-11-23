<div class="receipt-stamp">
    <p class="fw-bold mb-2">RECIBIDO · DEMOSTRACIÓN</p>
    <dl class="note-record mb-0">
        @if ($stamp['cite'])
            <div><dt>CITE</dt><dd>{{ $stamp['cite'] }}</dd></div>
        @endif
        <div><dt>Unidad receptora</dt><dd>{{ $stamp['unidad'] ?? 'No disponible' }}</dd></div>
        <div><dt>Recibido por</dt><dd>{{ $stamp['funcionario'] ?? 'No disponible' }}</dd></div>
        <div><dt>Fecha y hora · Bolivia</dt><dd><time datetime="{{ $stamp['fecha_hora'] }}">{{ \Carbon\CarbonImmutable::parse($stamp['fecha_hora'])->timezone('America/La_Paz')->format('d/m/Y H:i:s') }}</time></dd></div>
    </dl>
</div>
