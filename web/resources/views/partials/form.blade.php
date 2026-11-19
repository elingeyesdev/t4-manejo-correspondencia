<form action="{{ $form['action'] }}" method="post" aria-label="{{ $form['formLabel'] }}" data-institutional-form>
    @csrf
    @if (($form['method'] ?? 'POST') !== 'POST')
        @method($form['method'])
    @endif
    <input type="hidden" name="_form" value="{{ $form['formKey'] }}">
    @foreach ($form['hidden'] ?? [] as $name => $value)
        <input type="hidden" name="{{ $name }}" value="{{ is_scalar($value) ? $value : '' }}">
    @endforeach
    @if ($form['fields'])
        <div class="row g-3">
            @foreach ($form['fields'] as $field)
                @php
                    $name = $field['name'];
                    $id = $form['formKey'].'-'.$name;
                    $type = $field['type'] ?? 'text';
                    $value = ((array) $form['initial'])[$name] ?? '';
                    $value = $type !== 'password' && is_scalar($value) ? (string) $value : '';
                    $error = ((array) $form['errors'])[$name][0] ?? null;
                    $describedBy = implode(' ', array_filter([isset($field['help']) ? $id.'-help' : null, $error ? $id.'-error' : null]));
                    $control = new \Illuminate\View\ComponentAttributeBag([
                        'id' => $id, 'name' => $name, 'required' => $field['required'] ?? false,
                        'aria-describedby' => $describedBy ?: null, 'aria-invalid' => $error ? 'true' : null,
                    ]);
                @endphp
                <div @class(['col-12', 'col-md-6' => ! ($field['wide'] ?? false)])>
                    @if ($type !== 'checkbox')
                        <label for="{{ $id }}" class="form-label">{{ $field['label'] }}</label>
                    @endif
                    @if ($type === 'select')
                        <select {{ $control->class(['form-select', 'is-invalid' => $error]) }}>
                            <option value="">Selecciona una opción</option>
                            @foreach ($field['options'] as $option)
                                <option value="{{ $option['value'] }}" @selected($value === (string) $option['value'])>{{ $option['label'] }}</option>
                            @endforeach
                        </select>
                    @elseif ($type === 'textarea')
                        <textarea {{ $control->class(['form-control', 'is-invalid' => $error]) }} rows="4"
                            @isset($field['maxLength']) maxlength="{{ $field['maxLength'] }}" @endisset
                            @isset($field['maxCodePoints']) data-max-code-points="{{ $field['maxCodePoints'] }}" @endisset>{{ $value }}</textarea>
                    @elseif ($type === 'checkbox')
                        <div class="form-check">
                            <input {{ $control->class(['form-check-input', 'is-invalid' => $error]) }} type="checkbox" value="1">
                            <label for="{{ $id }}" class="form-check-label">{{ $field['label'] }}</label>
                        </div>
                    @else
                        <input {{ $control->class(['form-control', 'is-invalid' => $error]) }} type="{{ $type }}" value="{{ $value }}"
                            @isset($field['maxLength']) maxlength="{{ $field['maxLength'] }}" @endisset
                            @isset($field['minLength']) minlength="{{ $field['minLength'] }}" @endisset
                            @isset($field['pattern']) pattern="{{ $field['pattern'] }}" @endisset
                            @if ($type === 'password') autocomplete="new-password" @endif>
                    @endif
                    @isset($field['help'])
                        <p class="form-text mb-0" id="{{ $id }}-help">{{ $field['help'] }}</p>
                    @endisset
                    @if ($error)
                        <p class="invalid-feedback d-block mb-0" id="{{ $id }}-error">{{ $error }}</p>
                    @endif
                </div>
            @endforeach
        </div>
    @endif
    @if (! empty($form['help']))
        <p class="text-secondary mt-3 mb-0">{{ $form['help'] }}</p>
    @endif
    <div class="actions mt-3">
        <button type="submit" class="btn btn-primary">{{ $form['submitLabel'] }}</button>
        @if (! empty($form['cancelUrl']))
            <a class="btn btn-outline-secondary" href="{{ $form['cancelUrl'] }}">Volver</a>
        @endif
    </div>
</form>
