@php($localDate = $date->timezone('America/La_Paz'))
<li>
    <time datetime="{{ $localDate->toIso8601String() }}">{{ $localDate->format('d/m/Y H:i') }}</time>
    <div>
        <strong>{{ $action }}</strong> · {{ $actor }}
        @if (filled($unit ?? null))
            <span class="history-unit"> · {{ $unit }}</span>
        @endif
        @if (filled($reason ?? null))
            <div>{{ $reason }}</div>
        @endif
    </div>
</li>
