<script setup>
import { onMounted, provide, ref } from 'vue';
import AppLayout from './layout/AppLayout.vue';

const props = defineProps({
    context: {
        type: Object,
        required: true,
    },
});

provide('correspondencia', props.context);

const contentHost = ref(null);

onMounted(() => {
    const content = document.getElementById('laravel-content');

    if (content && contentHost.value) {
        contentHost.value.appendChild(content);
    }
});
</script>

<template>
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