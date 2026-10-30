<script setup>
import { computed, inject } from 'vue';
import AppMenuItem from './AppMenuItem.vue';

const context = inject('correspondencia');

const model = computed(() => [
    {
        label: 'Correspondencia',
        items: [
            {
                label: 'Documentos',
                icon: 'pi pi-fw pi-inbox',
                url: context.documentsUrl,
            },
            {
                label: 'Nueva correspondencia',
                icon: 'pi pi-fw pi-file-plus',
                url: context.createUrl,
                visible: context.canRegister,
            },
        ],
    },
    {
        label: 'Administración',
        visible: context.isAdmin,
        items: [
            {
                label: 'Administración',
                icon: 'pi pi-fw pi-cog',
                url: context.adminUrl,
                visible: context.isAdmin,
            },
        ],
    },
]);
</script>

<template>
    <ul class="layout-menu">
        <template v-for="item in model" :key="item.label">
            <AppMenuItem
                v-if="item.visible !== false"
                :item="item"
                :root="true"
            />
        </template>
    </ul>
</template>