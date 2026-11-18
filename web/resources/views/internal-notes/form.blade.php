@extends('internal-notes.layout')
@section('title', $note->exists ? 'Editar borrador' : 'Nueva Nota Interna')

@section('content')
    <h1>{{ $note->exists ? 'Editar borrador' : 'Nueva Nota Interna' }}</h1>
    @php
        $vias = (array) old('vias_usuario_ids', $note->participants->where('role', 'via')->pluck('user_id')->values()->all());
        $copies = (array) old('cc_usuario_ids', $note->participants->where('role', 'cc')->pluck('user_id')->all());
    @endphp
    <form method="post" action="{{ $note->exists ? route('notes.update', $note) : route('notes.store') }}">
        @csrf
        @if ($note->exists)
            @method('PATCH')
            <input type="hidden" name="version" value="{{ $note->version }}">
        @endif
        <section>
            <p><strong>DE</strong> {{ auth()->user()->name }} · {{ auth()->user()->unit->name }}</p>
            <label for="destinatario">A · Unidad destinataria</label>
            <select id="destinatario" name="destinatario_unidad_id" required>
                <option value="">Elige una unidad</option>
                @foreach ($units as $unit)
                    <option value="{{ $unit->id }}" @selected((int) old('destinatario_unidad_id', $note->recipient_unit_id) === $unit->id)>{{ $unit->name }}</option>
                @endforeach
            </select>
            <label for="asunto">Asunto</label>
            <input id="asunto" name="asunto" value="{{ old('asunto', $note->subject) }}" maxlength="200" required>
            <label for="referencia">Referencia (opcional)</label>
            <input id="referencia" name="referencia" value="{{ old('referencia', $note->reference) }}" maxlength="200">
            <label for="cuerpo">Cuerpo de la nota</label>
            <textarea id="cuerpo" name="cuerpo" rows="8" maxlength="20000" required>{{ old('cuerpo', $note->body) }}</textarea>
        </section>
        <fieldset>
            <legend>VÍA · Orden de revisión (opcional)</legend>
            <p>Elige los revisores según el orden en que deban actuar. Deja los selectores vacíos para un envío directo.</p>
            @for ($index = 0; $index < 10; $index++)
                <label for="via-{{ $index }}">Revisor {{ $index + 1 }}</label>
                <select id="via-{{ $index }}" name="vias_usuario_ids[]">
                    <option value="">Sin revisor</option>
                    @foreach ($accounts as $account)
                        <option value="{{ $account->id }}" @selected((int) ($vias[$index] ?? 0) === $account->id)>{{ $account->name }} · {{ $account->unit->name }}</option>
                    @endforeach
                </select>
            @endfor
        </fieldset>
        <fieldset>
            <legend>CC · Copia informativa (opcional)</legend>
            <label for="copias">Personas que recibirán una copia</label>
            <select id="copias" name="cc_usuario_ids[]" multiple size="5">
                @foreach ($accounts as $account)
                    <option value="{{ $account->id }}" @selected(in_array($account->id, $copies, false))>{{ $account->name }} · {{ $account->unit->name }}</option>
                @endforeach
            </select>
        </fieldset>
        <div class="actions">
            <button type="submit">Guardar borrador</button>
            <a href="{{ $note->exists ? route('notes.show', $note) : route('notes.index') }}">Cancelar</a>
        </div>
    </form>
@endsection
