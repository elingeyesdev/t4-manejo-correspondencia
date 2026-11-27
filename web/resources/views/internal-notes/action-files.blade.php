<fieldset class="mb-3">
    <legend class="form-label">Imágenes de firma y sello</legend>
    <div class="row g-2">
        <label class="col-sm-6">
            Cargar firma
            <input class="form-control" type="file" name="imagen_firma" accept="image/png,image/jpeg">
        </label>
        <label class="col-sm-6">
            Cargar sello (opcional)
            <input class="form-control" type="file" name="imagen_sello" accept="image/png,image/jpeg">
        </label>
    </div>
    <p class="form-text">PNG o JPEG, hasta 512 KB por imagen.</p>
    <details class="mb-2" data-action-preview="{{ route('notes.preview-action', $note) }}" data-operation="{{ $operation }}">
        <summary>Revisar firma y sello sobre la hoja</summary>
        <p data-preview-status role="status"></p>
        <iframe class="document-preview-pdf" title="Ubicación de las constancias antes de confirmar" hidden></iframe>
        <button type="button" class="btn btn-outline-secondary mt-2" data-preview-refresh>Actualizar vista previa</button>
    </details>
</fieldset>
