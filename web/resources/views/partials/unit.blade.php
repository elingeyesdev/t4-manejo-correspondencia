<form method="post" action="/administracion/unidades{{ $item?'/'.$item->id:'' }}">@csrf @if($item)@method('PUT')@endif
<div class="grid">
<label>Código<input name="code" required maxlength="30" pattern="[A-Z0-9_-]+" value="{{ $item?->code }}">
</label>
<label>Nombre<input name="name" required maxlength="150" value="{{ $item?->name }}">
</label>
</div>
<p>
<label>Estado<select name="enabled">
<option value="1" @selected(!$item || $item->enabled)>Habilitada</option>
<option value="0" @selected($item && !$item->enabled)>Deshabilitada</option>
</select>
</label>
</p>
<button>Guardar unidad</button>
</form>
