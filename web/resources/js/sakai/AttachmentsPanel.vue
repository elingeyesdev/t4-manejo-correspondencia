<script setup>
import { onMounted, onUnmounted, ref } from 'vue';
import Button from 'primevue/button';
import Message from 'primevue/message';
import Paginator from 'primevue/paginator';

const props = defineProps({
    canUpload: { type: Boolean, default: false },
    uploadUrl: { type: String, required: true },
    csrfToken: { type: String, required: true },
    records: { type: Array, required: true },
    total: { type: Number, required: true },
    pageSize: { type: Number, required: true },
    currentPage: { type: Number, required: true },
});
const input = ref(null);
const selected = ref(null);
const error = ref('');
const submitting = ref(false);
const maxBytes = 10485760;
const allowed = ['application/pdf', 'image/jpeg', 'image/png'];

function selectFile(event) {
    selected.value = event.target.files?.[0] ?? null;
    error.value = '';
    validateFile();
}
function validateFile() {
    if (!selected.value) { error.value = 'Selecciona un archivo.'; return false; }
    if (!selected.value.size) { error.value = 'El archivo está vacío.'; return false; }
    if (selected.value.size > maxBytes) { error.value = 'El archivo no debe superar los 10 MiB.'; return false; }
    if (selected.value.type && !allowed.includes(selected.value.type)) {
        error.value = 'Selecciona un archivo PDF, JPG o PNG.'; return false;
    }
    return true;
}
function submit(event) {
    error.value = '';
    if (submitting.value || !validateFile()) { event.preventDefault(); return; }
    submitting.value = true;
}
function clear() {
    input.value.value = '';
    selected.value = null;
    error.value = '';
}
function page(event) {
    if (submitting.value) return;
    const url = new URL(window.location.href);
    url.searchParams.set('adjuntos_page', String(event.page + 1));
    url.hash = 'adjuntos';
    window.location.assign(url.href);
}
function size(bytes) {
    return bytes < 1048576 ? `${Math.ceil(bytes / 1024)} KB` : `${(bytes / 1048576).toFixed(1)} MB`;
}
function restore() { submitting.value = false; }
onMounted(() => window.addEventListener('pageshow', restore));
onUnmounted(() => window.removeEventListener('pageshow', restore));
</script>

<template>
    <div class="card">
        <div class="flex items-start gap-3 mb-6">
            <span class="flex items-center justify-center bg-cyan-100 text-cyan-700 rounded-border w-12 h-12 shrink-0">
                <i class="pi pi-paperclip text-xl" aria-hidden="true"></i>
            </span>
            <div class="min-w-0">
                <h2 class="text-xl font-semibold m-0">Adjuntos</h2>
                <p class="text-muted-color mt-2 mb-0">Consulta las fotos y archivos de esta correspondencia.</p>
            </div>
        </div>

        <form v-if="canUpload" :action="uploadUrl" method="post" enctype="multipart/form-data"
            aria-label="Adjuntar archivo" class="border border-surface rounded-border p-4 mb-6" @submit="submit">
            <input type="hidden" name="_token" :value="csrfToken">
            <label for="attachment-file" class="block font-medium mb-2">Selecciona un archivo</label>
            <input ref="input" id="attachment-file" type="file" name="archivo"
                accept=".pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png"
                required :aria-disabled="submitting" @click="submitting && $event.preventDefault()" class="block w-full min-w-0"
                aria-describedby="attachment-help attachment-error" @change="selectFile">
            <p v-if="selected" class="mt-3 mb-0 break-all">Archivo seleccionado: {{ selected.name }}</p>
            <p id="attachment-help" class="text-muted-color mt-3 mb-0">PDF, JPG o PNG · máximo 10 MiB.</p>
            <Message v-if="error" id="attachment-error" severity="error" class="mt-3" role="alert">{{ error }}</Message>
            <div class="flex flex-wrap gap-3 mt-4">
                <Button type="submit" label="Subir archivo" icon="pi pi-cloud-upload" :loading="submitting" :disabled="submitting" />
                <Button v-if="selected" type="button" label="Quitar selección" severity="secondary" outlined :disabled="submitting" @click="clear" />
            </div>
            <p v-if="submitting" class="text-muted-color mt-3 mb-0" role="status">Guardando archivo. Espera a que termine.</p>
        </form>

        <p class="font-medium mb-3">Archivos guardados · {{ total }}</p>
        <p v-if="!total" class="text-muted-color mb-0">Esta correspondencia todavía no tiene adjuntos.</p>
        <ul v-else class="list-none p-0 m-0 flex flex-col divide-y divide-surface">
            <li v-for="file in records" :key="file.id" class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 py-4">
                <div class="flex items-start gap-3 min-w-0 w-full sm:w-auto sm:flex-1">
                    <i :class="file.mime === 'application/pdf' ? 'pi pi-file-pdf text-purple-600' : 'pi pi-image text-blue-600'" class="mt-1 text-xl" aria-hidden="true"></i>
                    <div class="min-w-0">
                        <p class="font-medium m-0 break-all">{{ file.name }}</p>
                        <p class="text-muted-color mt-1 mb-0">{{ size(file.size) }} · {{ file.date }}</p>
                    </div>
                </div>
                <div class="flex flex-wrap gap-2">
                    <Button as="a" :href="file.viewUrl" target="_blank" rel="noopener noreferrer" label="Ver" icon="pi pi-eye" severity="secondary" outlined :aria-label="`Ver ${file.name}`" />
                    <Button as="a" :href="file.downloadUrl" label="Descargar" icon="pi pi-download" text :aria-label="`Descargar ${file.name}`" />
                </div>
            </li>
        </ul>
        <Paginator v-if="total > pageSize" :rows="pageSize" :totalRecords="total"
            :first="(currentPage - 1) * pageSize" @page="page" />
    </div>
</template>
