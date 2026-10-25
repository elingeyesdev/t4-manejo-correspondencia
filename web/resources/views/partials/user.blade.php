<form method="post" action="/administracion/usuarios{{ $item?'/'.$item->id:'' }}">@csrf @if($item)@method('PUT')@endif
<div class="grid">
<label>Nombre<input name="name" required maxlength="150" value="{{ $item?->name }}">
</label>
<label>Correo<input name="email" type="email" required value="{{ $item?->email }}">
</label>
<label>Unidad<select name="unit_id" required>@foreach($units->where('enabled',true) as $unit)<option value="{{ $unit->id }}" @selected($item?->unit_id==$unit->id)>{{ $unit->name }}</option>@endforeach</select>
</label>
<label>Rol<select name="role">@foreach(['administrador'=>'Administrador','recepcion'=>'Recepción','funcionario'=>'Funcionario'] as $role=>$label)<option value="{{ $role }}" @selected($item?->role===$role)>{{ $label }}</option>@endforeach</select>
</label>
<label>Contraseña {{ $item?'(dejar vacía para conservar)':'' }}<input type="password" name="password" minlength="12" autocomplete="new-password" @required(!$item)>
</label>
<label>Confirmar contraseña<input type="password" name="password_confirmation" autocomplete="new-password" @required(!$item)>
</label>
</div>
<p>
<label>Estado<select name="enabled">
<option value="1" @selected(!$item || $item->enabled)>Habilitado</option>
<option value="0" @selected($item && !$item->enabled)>Deshabilitado</option>
</select>
</label>
</p>
<p class="muted">Una actualización invalida las sesiones anteriores del usuario. Las contraseñas requieren al menos 12 caracteres con letras y números.</p>
<button>Guardar usuario</button>
</form>
