@extends('layout')
@section('title', $note->exists ? 'Editar borrador' : 'Nueva Nota Interna')

@section('content')
    <header class="page-heading">
        <h1>{{ $note->exists ? 'Editar borrador' : 'Nueva Nota Interna' }}</h1>
        <a href="{{ route('notes.index') }}">Volver a la bandeja</a>
    </header>
    @php
        $vias = (array) old('vias_usuario_ids', $note->participants->where('role', 'via')->pluck('user_id')->values()->all());
        $copies = (array) old('cc_usuario_ids', $note->participants->where('role', 'cc')->pluck('user_id')->all());
        $extraReviewers = count(array_filter(array_slice($vias, 1))) > 0 || $errors->has('vias_usuario_ids.*');
    @endphp
    <div class="note-editor">
    <form class="note-form" id="nota-edicion" method="post" data-draft-preview="{{ route('notes.preview-draft', [], false) }}"
          data-draft-id="{{ $note->id }}" action="{{ $note->exists ? route('notes.update', $note) : route('notes.store') }}">
        @csrf
        @if ($note->exists)
            @method('PATCH')
            <input type="hidden" name="version" value="{{ $note->version }}">
        @endif

        <fieldset class="form-section">
            <legend>Datos de la nota</legend>
            <dl class="sender">
                <dt>DE</dt>
                <dd>{{ auth()->user()->name }} · {{ auth()->user()->unit->name }}</dd>
            </dl>
            <div class="row g-3">
                <div class="col-md-7">
                    <label class="form-label" for="destinatario">A · Unidad destinataria</label>
                    <select class="form-select @error('destinatario_unidad_id') is-invalid @enderror" id="destinatario" name="destinatario_unidad_id" required
                            @error('destinatario_unidad_id') aria-invalid="true" aria-describedby="error-destinatario" @enderror>
                        <option value="">Elige una unidad</option>
                        @foreach ($units as $unit)
                            <option value="{{ $unit->id }}" @selected((int) old('destinatario_unidad_id', $note->recipient_unit_id) === $unit->id)>{{ $unit->name }}</option>
                        @endforeach
                    </select>
                    @error('destinatario_unidad_id') <p class="invalid-feedback" id="error-destinatario">{{ $message }}</p> @enderror
                </div>
                <div class="col-md-5">
                    <label class="form-label" for="referencia">Referencia <span class="optional">(opcional)</span></label>
                    <input class="form-control @error('referencia') is-invalid @enderror" id="referencia" name="referencia" value="{{ old('referencia', $note->reference) }}" maxlength="200"
                           @error('referencia') aria-invalid="true" aria-describedby="error-referencia" @enderror>
                    @error('referencia') <p class="invalid-feedback" id="error-referencia">{{ $message }}</p> @enderror
                </div>
                <div class="col-12">
                    <label class="form-label" for="asunto">Asunto</label>
                    <input class="form-control @error('asunto') is-invalid @enderror" id="asunto" name="asunto" value="{{ old('asunto', $note->subject) }}" maxlength="200" required
                           @error('asunto') aria-invalid="true" aria-describedby="error-asunto" @enderror>
                    @error('asunto') <p class="invalid-feedback" id="error-asunto">{{ $message }}</p> @enderror
                </div>
                <div class="col-12">
                    <label class="form-label" for="cuerpo">Cuerpo de la nota</label>
                    <textarea class="form-control @error('cuerpo') is-invalid @enderror" id="cuerpo" name="cuerpo" rows="6" maxlength="20000" required
                              @error('cuerpo') aria-invalid="true" aria-describedby="error-cuerpo" @enderror>{{ old('cuerpo', $note->body) }}</textarea>
                    @error('cuerpo') <p class="invalid-feedback" id="error-cuerpo">{{ $message }}</p> @enderror
                </div>
            </div>
        </fieldset>

        <fieldset class="form-section" aria-describedby="via-ayuda">
            <legend>VÍA · Orden de revisión <span class="optional">(opcional)</span></legend>
            <p class="form-text" id="via-ayuda">Selecciona los revisores en orden. Para un envío directo, deja estos campos vacíos.</p>
            @include('internal-notes.reviewer', ['index' => 0])
            <details class="reviewers-details" @if ($extraReviewers) open @endif>
                <summary>Agregar más revisores</summary>
                <div class="row g-3 mt-0">
                    @for ($index = 1; $index < 10; $index++)
                        <div class="col-md-6">@include('internal-notes.reviewer', ['index' => $index])</div>
                    @endfor
                </div>
            </details>
        </fieldset>

        <fieldset class="form-section">
            <legend>CC · Copia informativa <span class="optional">(opcional)</span></legend>
            <details class="reviewers-details" @if ($copies !== []) open @endif>
                <summary>Elegir personas que recibirán una copia</summary>
                <label class="form-label mt-2" for="buscar-copias">Buscar por nombre o unidad</label>
                <input class="form-control mb-2" type="search" id="buscar-copias" data-copy-search>
                <div class="note-copy-options" role="group" aria-label="Personas para copia">
                @foreach ($accounts as $account)
                    <label class="form-check" data-copy-option>
                        <input class="form-check-input" type="checkbox" name="cc_usuario_ids[]"
                               value="{{ $account->id }}" @checked(in_array($account->id, $copies, false))>
                        <span class="form-check-label">{{ $account->name }} · {{ $account->unit->name }}</span>
                    </label>
                @endforeach
                </div>
            </details>
        </fieldset>

        <div class="actions">
            <button type="submit" class="btn btn-primary">Guardar borrador</button>
            <a class="btn btn-outline-secondary" href="{{ $note->exists ? route('notes.show', $note) : route('notes.index') }}">Cancelar</a>
        </div>
    </form>
    <section class="note-section note-editor-preview" aria-labelledby="borrador-vista">
        <h2 id="borrador-vista">Vista previa del borrador</h2>
        <p data-draft-status role="status">Preparando la hoja…</p>
        <iframe data-draft-frame class="document-preview-pdf" title="Vista previa del borrador" hidden></iframe>
        <button type="button" class="btn btn-outline-secondary mt-2" data-draft-retry hidden>Reintentar vista previa</button>
        @if (app(\App\Services\InstitutionalNoteDocument::class)->configured())
            <button type="button" class="btn btn-outline-secondary mt-2" data-draft-paginate>Revisar saltos de página (PDF)</button>
        @endif
    </section>
    </div>
    <script src="{{ asset('js/note-document.js') }}" defer></script>
@endsection
