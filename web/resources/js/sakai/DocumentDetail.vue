<script setup>
import Button from 'primevue/button';
import Tag from 'primevue/tag';
import DataTable from 'primevue/datatable';
import Column from 'primevue/column';

defineProps({
    document: { type: Object, required: true },
    sheet: { type: Object, required: true },
    movements: { type: Array, required: true },
    indexUrl: { type: String, required: true },
});
</script>

<template>
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
                <div><dt class="text-muted-color">Versión</dt><dd class="m-0">{{ sheet.version }}</dd></div>
            </dl>
            <p class="text-muted-color mt-6 mb-0">Los identificadores se conservan durante todo el recorrido.</p>
        </section>
    </div>

    <section class="card">
        <h2 class="text-xl font-semibold mt-0 mb-5">Historial inicial</h2>
        <DataTable :value="movements" dataKey="id" stripedRows tableStyle="min-width: 42rem">
            <template #empty>No hay movimientos disponibles.</template>
            <Column field="action" header="Acción" />
            <Column field="actor" header="Actor" />
            <Column field="date" header="Fecha y hora · Bolivia" />
            <Column header="Estado">
                <template #body="{ data }"><Tag :value="data.state" severity="info" /></template>
            </Column>
        </DataTable>
    </section>
</template>
