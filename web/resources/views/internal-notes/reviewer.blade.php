<label class="form-label" for="via-{{ $index }}">Revisor {{ $index + 1 }}</label>
<select class="form-select @error('vias_usuario_ids.' . $index) is-invalid @enderror" id="via-{{ $index }}" name="vias_usuario_ids[]"
        @error('vias_usuario_ids.' . $index) aria-invalid="true" aria-describedby="error-via-{{ $index }}" @enderror>
    <option value="">Sin revisor</option>
    @foreach ($accounts as $account)
        <option value="{{ $account->id }}" @selected((int) ($vias[$index] ?? 0) === $account->id)>{{ $account->name }} · {{ $account->unit->name }}</option>
    @endforeach
</select>
@error('vias_usuario_ids.' . $index) <p class="invalid-feedback" id="error-via-{{ $index }}">{{ $message }}</p> @enderror
