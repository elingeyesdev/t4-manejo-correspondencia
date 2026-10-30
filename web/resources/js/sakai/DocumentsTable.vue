<script setup>
import DataTable from 'primevue/datatable';
import Column from 'primevue/column';
import Tag from 'primevue/tag';
import Button from 'primevue/button';
import Paginator from 'primevue/paginator';

defineProps({
    records: { type: Array, required: true },
    total: { type: Number, required: true },
    pageSize: { type: Number, required: true },
    currentPage: { type: Number, required: true },
    canRegister: { type: Boolean, default: false },
    createUrl: { type: String, required: true },
});

function changePage(event) {
    const url = new URL(window.location.href);
    url.searchParams.set('page', String(event.page + 1));
    window.location.assign(url.href);
}
</script>

<template>
    <div class="card">
        <div class="flex flex-wrap items-center justify-between gap-4 mb-6">
            <div>
                <h1 class="text-2xl font-semibold m-0">
                    Correspondencia registrada
                </h1>
                <p class="text-muted-color mt-2 mb-0">
                    Documentos dentro de tu alcance de acceso · {{ total }} registros
                </p>
            </div>

            <Button
                v-if="canRegister"
                as="a"
                :href="createUrl"
                label="Nueva correspondencia"
                icon="pi pi-plus"
            />
        </div>

        <DataTable
            :value="records"
            dataKey="id"
            stripedRows
            tableStyle="min-width: 60rem"
        >
            <template #empty>
                No hay documentos disponibles dentro de tu alcance de acceso.
            </template>

            <Column header="Documento / guía">
                <template #body="{ data }">
                    <div class="font-medium break-all">{{ data.code }}</div>
                    <small class="text-muted-color break-all">
                        {{ data.guide }}
                    </small>
                </template>
            </Column>

            <Column header="Asunto y remitente">
                <template #body="{ data }">
                    <div class="font-medium">{{ data.subject }}</div>
                    <small class="text-muted-color">{{ data.sender }}</small>
                </template>
            </Column>

            <Column field="unit" header="Unidad" />

            <Column header="Estado">
                <template #body="{ data }">
                    <Tag :value="data.state" severity="info" />
                </template>
            </Column>

            <Column header="Consulta">
                <template #body="{ data }">
                    <Button
                        as="a"
                        :href="data.detailUrl"
                        label="Ver detalle"
                        icon="pi pi-arrow-right"
                        text
                    />
                </template>
            </Column>
        </DataTable>

        <Paginator
            v-if="total > 0"
            :rows="pageSize"
            :totalRecords="total"
            :first="(currentPage - 1) * pageSize"
            @page="changePage"
        />
    </div>
</template>