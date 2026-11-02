<script setup>
import { inject } from 'vue';
import { useLayout } from '@/layout/composables/layout';

const context = inject('correspondencia');
const { toggleMenu } = useLayout();
</script>

<template>
    <div class="layout-topbar">
        <div class="layout-topbar-logo-container">
            <button
                type="button"
                class="layout-menu-button layout-topbar-action"
                aria-label="Abrir o cerrar menú"
                @click="toggleMenu"
            >
                <i class="pi pi-bars"></i>
            </button>

            <a :href="context.documentsUrl" class="layout-topbar-logo">
                <i class="pi pi-folder"></i>
                <span class="text-lg sm:text-2xl">Correspondencia</span>
            </a>
        </div>

        <div class="layout-topbar-actions">
            <span class="hidden md:inline-block max-w-48 truncate" :title="context.userName">{{ context.userName }}</span>

            <form method="post" :action="context.logoutUrl">
                <input
                    type="hidden"
                    name="_token"
                    :value="context.csrfToken"
                >
                <button
                    type="submit"
                    class="layout-topbar-action"
                    aria-label="Cerrar sesión"
                    title="Cerrar sesión"
                >
                    <i class="pi pi-sign-out"></i>
                </button>
            </form>
        </div>
    </div>
</template>