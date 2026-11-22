@extends('layout')

@section('title', 'Avisos')

@section('content')
    <header class="mb-4">
        <h1>Avisos</h1>
        <p class="text-body-secondary">Sin leer: {{ $unread }}</p>
    </header>

    <ul class="list-group mb-3">
        @forelse ($notices as $notice)
            <li class="list-group-item d-flex flex-wrap justify-content-between gap-2 align-items-center">
                <div>
                    <a href="{{ route('notes.show', $notice->note_id) }}">{{ $notice->label() }}</a>
                    <div class="small text-body-secondary">
                        <time datetime="{{ $notice->created_at->toISOString() }}">{{ $notice->created_at->format('d/m/Y H:i') }}</time>
                        · {{ $notice->read_at ? 'Leído' : 'Sin leer' }}
                    </div>
                </div>
                @if (!$notice->read_at)
                    <form method="post" action="{{ route('notices.read', $notice->id) }}">
                        @csrf
                        @method('PUT')
                        <button class="btn btn-outline-secondary btn-sm" type="submit">Marcar como leído</button>
                    </form>
                @endif
            </li>
        @empty
            <li class="list-group-item">No hay avisos disponibles.</li>
        @endforelse
    </ul>
    @include('partials.pagination', ['paginator' => $notices, 'label' => 'Paginación de avisos'])
@endsection
