<script setup>
import { onMounted, provide, ref } from 'vue';
import AppLayout from './layout/AppLayout.vue';
import Toast from 'primevue/toast';
import { useToast } from 'primevue/usetoast';

const props = defineProps({
    context: {
        type: Object,
        required: true,
    },
});

provide('correspondencia', props.context);

const contentHost = ref(null);
const toast = useToast();

onMounted(() => {
    const content = document.getElementById('laravel-content');

    if (content && contentHost.value) {
        contentHost.value.appendChild(content);
    }
    if (props.context.statusMessage) {
        toast.add({
            severity: 'success',
            summary: 'Operación completada',
            detail: props.context.statusMessage,
            life: 8000,
        });
        document.getElementById('operation-status')?.setAttribute('role', 'note');
    }
});
</script>

<template>
    <Toast position="top-right"
        :breakpoints="{ '640px': { width: 'calc(100% - 2rem)', right: '1rem' } }"
        :closeButtonProps="{ 'aria-label': 'Cerrar confirmación' }" />
    <AppLayout v-if="context.authenticated">
        <div ref="contentHost"></div>
    </AppLayout>

    <div
        v-else
        class="min-h-screen flex items-center justify-center p-6"
    >
        <div ref="contentHost" class="w-full max-w-md"></div>
    </div>
</template>