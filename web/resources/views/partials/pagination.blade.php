@if ($paginator->hasPages())
    <nav class="notes-pagination" aria-label="{{ $label }}">
        @if ($paginator->previousPageUrl())
            <a href="{{ $paginator->previousPageUrl() }}{{ $fragment ?? '' }}" rel="prev">Anterior</a>
        @endif
        <span>Página {{ $paginator->currentPage() }} de {{ $paginator->lastPage() }}</span>
        @if ($paginator->nextPageUrl())
            <a href="{{ $paginator->nextPageUrl() }}{{ $fragment ?? '' }}" rel="next">Siguiente</a>
        @endif
    </nav>
@endif
