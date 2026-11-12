<script setup>
import Button from 'primevue/button';
import Tag from 'primevue/tag';
import Message from 'primevue/message';
import DataTable from 'primevue/datatable';
import Column from 'primevue/column';
import { ref } from 'vue';
import SakaiForm from './SakaiForm.vue';

defineProps({
    document: { type: Object, required: true },
    sheet: { type: Object, required: true },
    movements: { type: Array, required: true },
    indexUrl: { type: String, required: true },
    qr: { type: Object, required: true },
    workflows: { type: Array, default: () => [] },
});
const qrFailed = ref(false);
</script>

<template>
    <Message v-if="sheet.state === 'CERRADA'" severity="success" class="mb-6" role="status">
        <strong>Expediente cerrado.</strong>
        El trámite finalizó. Sus datos, archivos e historial siguen disponibles para consulta.
    </Message>
    <div class="flex flex-wrap items-start justify-between gap-4 mb-6">
        <div class="min-w-0">
            <Tag :value="sheet.state" severity="info" class="mb-3" />
            <h1 class="text-3xl font-semibold m-0 break-words">{{ document.subject }}</h1>
            <p class="text-muted-color mt-2 mb-0">Documento y hoja de ruta vinculados · Información autorizada</p>
        </div>
        <Button as="a" :href="indexUrl" label="Volver a documentos" icon="pi pi-arrow-left" severity="secondary" outlined />
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <section class="card mb-0 min-w-0">
            <h2 class="text-xl font-semibold mt-0 mb-5">Documento</h2>
            <dl class="flex flex-col gap-4 m-0">
                <div><dt class="text-muted-color">Código</dt><dd class="m-0 font-medium break-all">{{ document.code }}</dd></div>
                <div><dt class="text-muted-color">Guía de consulta</dt><dd class="m-0 break-all">{{ document.guide }}</dd></div>
                <div><dt class="text-muted-color">Remitente</dt><dd class="m-0 break-words">{{ document.sender }}</dd></div>
                <div><dt class="text-muted-color">Fecha de recepción</dt><dd class="m-0">{{ document.receivedOn }}</dd></div>
                <div><dt class="text-muted-color">Unidad</dt><dd class="m-0">{{ document.unit }}</dd></div>
                <div><dt class="text-muted-color">Tipo y prioridad</dt><dd class="m-0">{{ document.type }} · {{ document.priority }}</dd></div>
            </dl>
        </section>
        <section class="card mb-0 min-w-0">
            <h2 class="text-xl font-semibold mt-0 mb-5">Hoja de ruta</h2>
            <dl class="flex flex-col gap-4 m-0">
                <div><dt class="text-muted-color">Código</dt><dd class="m-0 font-medium break-all">{{ sheet.code }}</dd></div>
                <div><dt class="text-muted-color">Responsable actual</dt><dd class="m-0">{{ sheet.responsible }}</dd></div>
                <div><dt class="text-muted-color">Estado</dt><dd class="m-0">{{ sheet.state }}</dd></div>
                <div><dt class="text-muted-color">Unidad vigente</dt><dd class="m-0">{{ sheet.currentUnit }}</dd></div>
                <div v-if="sheet.pendingUnit"><dt class="text-muted-color">Destino pendiente</dt><dd class="m-0">{{ sheet.pendingUnit }}</dd></div>
                <div><dt class="text-muted-color">Versión</dt><dd class="m-0">{{ sheet.version }}</dd></div>
            </dl>
            <p class="text-muted-color mt-6 mb-0">Los identificadores se conservan durante todo el recorrido.</p>
        </section>
    </div>

    <section v-for="workflow in workflows" :key="workflow.formKey" class="card">
        <h2 class="text-xl font-semibold mt-0 mb-5">{{ workflow.formLabel }}</h2>
        <SakaiForm v-bind="workflow" />
    </section>

    <section class="card" aria-label="QR de la hoja de ruta">
        <h2 class="text-xl font-semibold mt-0 mb-5">
            QR de la hoja de ruta
        </h2>

        <div class="flex flex-col sm:flex-row items-start gap-6">
            <img
                v-if="!qrFailed"
                :src="qr.imageUrl"
                :alt="`Código QR de la hoja ${sheet.code}`"
                width="320"
                height="320"
                loading="lazy"
                class="w-full max-w-xs h-auto"
                @error="qrFailed = true"
            />

            <div class="min-w-0">
                <p class="mt-0">
                    Escanea el código para consultar esta hoja de ruta.
                </p>

                <p class="text-muted-color">
                    Se requiere iniciar sesión y tener acceso al documento.
                    Consultarlo no confirma recepción ni cambia su estado.
                </p>

                <p v-if="qrFailed" role="alert" class="text-red-600">
                    No se pudo cargar el QR. Actualiza la página para reintentar.
                </p>

                <Button
                    as="a"
                    :href="qr.consultUrl"
                    label="Consultar hoja de ruta"
                    icon="pi pi-external-link"
                    severity="secondary"
                    outlined
                />
            </div>
        </div>
    </section>

    <section class="card">
        <h2 class="text-xl font-semibold mt-0 mb-3">
            Historial documental
        </h2>

        <p class="text-muted-color mb-5">
            Cada fila muestra un movimiento registrado en el expediente.
        </p>

        <DataTable
            :value="movements"
            dataKey="id"
            stripedRows
            tableStyle="min-width: 65rem"
        >
            <template #empty>
                No hay movimientos registrados para este documento.
            </template>

            <Column field="action" header="Acción" />
            <Column field="actor" header="Realizado por" />
            <Column field="originUnit" header="Unidad de origen" />
            <Column field="destinationUnit" header="Unidad de destino" />
            <Column field="date" header="Fecha y hora · Bolivia" />

            <Column header="Estado resultante">
                <template #body="{ data }">
                    <Tag :value="data.state" severity="info" />
                </template>
            </Column>

            <Column header="Motivo u observación">
                <template #body="{ data }">
                    <div class="max-w-sm whitespace-pre-wrap [overflow-wrap:anywhere]">{{ data.reason }}</div>
                </template>
            </Column>
        </DataTable>
    </section>
</template>
