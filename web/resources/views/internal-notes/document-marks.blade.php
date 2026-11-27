@if ($strokes && ! isset($images['imagen_firma']))
    <svg class="trazo" viewBox="0 0 1000 375" role="img" aria-label="Firma manuscrita">
        @foreach ($strokes as $stroke)
            <polyline points="{{ implode(' ', array_map(fn ($point) => $point[0].','.($point[1] * .375), $stroke)) }}"
                fill="none" stroke="#18335a" stroke-width="5" stroke-linecap="round" stroke-linejoin="round" />
        @endforeach
    </svg>
@endif
@foreach ($images as $key => $src)
    <img class="imagen" src="{{ $src }}" alt="{{ $key === 'imagen_sello' ? 'Sello' : 'Firma' }}">
@endforeach
