<script setup>
import { ref } from 'vue';
import InputText from 'primevue/inputtext';
import Password from 'primevue/password';
import Button from 'primevue/button';
import Message from 'primevue/message';

const props = defineProps({
    action: { type: String, required: true },
    csrfToken: { type: String, required: true },
    initialEmail: { type: String, default: '' },
    errors: { type: Array, default: () => [] },
});

const email = ref(props.initialEmail);
const password = ref('');
const submitting = ref(false);
</script>

<template>
    <div
        class="bg-surface-50 dark:bg-surface-950 flex items-center justify-center min-h-screen p-6"
    >
        <div class="flex flex-col items-center justify-center w-full">
            <div
                class="w-full sm:w-auto"
                style="border-radius: 56px; padding: 0.3rem; background: linear-gradient(180deg, var(--primary-color) 10%, rgba(33, 150, 243, 0) 30%)"
            >
                <div
                    class="w-full bg-surface-0 dark:bg-surface-900 py-20 px-8 sm:px-20"
                    style="border-radius: 53px"
                >
                    <div class="text-center mb-8">
                        <i
                            class="pi pi-folder text-primary text-5xl mb-6"
                            aria-hidden="true"
                        ></i>
                        <h1
                            class="text-surface-900 dark:text-surface-0 text-3xl font-medium mb-4"
                        >
                            Correspondencia
                        </h1>
                        <span class="text-muted-color font-medium">
                            Inicia sesión con tu cuenta institucional
                        </span>
                    </div>

                    <Message
                        v-if="errors.length"
                        severity="error"
                        class="mb-6"
                        role="alert"
                    >
                        <ul class="m-0 pl-5 list-disc">
                            <li v-for="error in errors" :key="error">
                                {{ error }}
                            </li>
                        </ul>
                    </Message>

                    <form
                        method="post"
                        :action="action"
                        @submit="submitting = true"
                    >
                        <input
                            type="hidden"
                            name="_token"
                            :value="csrfToken"
                        >

                        <label
                            for="email"
                            class="block text-surface-900 dark:text-surface-0 text-xl font-medium mb-2"
                        >
                            Correo electrónico
                        </label>

                        <InputText
                            id="email"
                            v-model="email"
                            name="email"
                            type="email"
                            autocomplete="username"
                            placeholder="Correo electrónico"
                            class="w-full sm:w-[30rem] mb-8"
                            required
                            autofocus
                        />

                        <label
                            for="password"
                            class="block text-surface-900 dark:text-surface-0 text-xl font-medium mb-2"
                        >
                            Contraseña
                        </label>

                        <Password
                            v-model="password"
                            inputId="password"
                            name="password"
                            placeholder="Contraseña"
                            class="mb-8"
                            fluid
                            toggleMask
                            :feedback="false"
                            :inputProps="{
                                name: 'password',
                                required: true,
                                autocomplete: 'current-password',
                            }"
                        />

                        <Button
                            type="submit"
                            label="Ingresar"
                            icon="pi pi-sign-in"
                            class="w-full"
                            :loading="submitting"
                            :disabled="submitting"
                        />
                    </form>
                </div>
            </div>
        </div>
    </div>
</template>