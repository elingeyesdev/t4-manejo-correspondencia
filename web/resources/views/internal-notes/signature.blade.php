<fieldset class="note-signature mb-3">
    <legend class="form-label">Firma requerida</legend>
    <p id="note-signature-help" class="form-text">Dibuja tu firma con el mouse o el dedo, o carga una imagen de tu firma.</p>
    <canvas width="480" height="180" aria-label="Área de firma" aria-describedby="note-signature-help"></canvas>
    <input type="hidden" name="firma">
    <p class="form-text text-danger" data-signature-error role="alert" hidden></p>
    <button type="button" class="btn btn-outline-secondary btn-sm" data-signature-clear>Borrar trazo</button>
</fieldset>
<script src="{{ asset('js/note-signature.js') }}" defer></script>
