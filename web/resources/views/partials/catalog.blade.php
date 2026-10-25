<form method="post" action="/administracion/catalogos{{ $item?'/'.$item->id:'' }}">@csrf @if($item)@method('PUT')<input type="hidden" name="kind" value="{{ $item->kind }}">@else<label>Catálogo<select name="kind">
<option value="tipo">Tipo de documento</option>
<option value="prioridad">Prioridad</option>
</select>
</label>@endif
<div class="grid">
<label>Código<input name="code" required maxlength="30" pattern="[A-Z0-9_-]+" value="{{ $item?->code }}">
</label>
<label>Nombre<input name="name" required maxlength="150" value="{{ $item?->name }}">
</label>
</div>
<p>
<label>Estado<select name="enabled">
<option value="1" @selected(!$item || $item->enabled)>Habilitado</option>
<option value="0" @selected($item && !$item->enabled)>Deshabilitado</option>
</select>
</label>
</p>
<button>Guardar catálogo</button>
</form>
