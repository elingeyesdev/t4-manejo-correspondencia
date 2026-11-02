<script setup>
import { nextTick, reactive, ref } from 'vue';
import InputText from 'primevue/inputtext';
import Textarea from 'primevue/textarea';
import Password from 'primevue/password';
import Select from 'primevue/select';
import Button from 'primevue/button';

const props = defineProps({
    action: { type: String, required: true },
    csrfToken: { type: String, required: true },
    formKey: { type: String, required: true },
    formLabel: { type: String, required: true },
    fields: { type: Array, required: true },
    initial: { type: Object, default: () => ({}) },
    errors: { type: Object, default: () => ({}) },
    hidden: { type: Object, default: () => ({}) },
    method: { type: String, default: 'POST' },
    submitLabel: { type: String, default: 'Guardar' },
    cancelUrl: { type: String, default: '' },
    help: { type: String, default: '' },
});

const values = reactive(Object.fromEntries(props.fields.map((field) => [
    field.name,
    field.type === 'password' ? '' : (props.initial[field.name] ?? ''),
])));
const localErrors = reactive({});
const submitting = ref(false);
const fieldId = (field) => props.formKey + '-' + field.name;
const errorFor = (field) => localErrors[field.name] || props.errors[field.name]?.[0];

async function submit(event) {
    Object.keys(localErrors).forEach((key) => delete localErrors[key]);
    for (const field of props.fields) {
        if (field.required && (values[field.name] === '' || values[field.name] == null)) {
            localErrors[field.name] = 'Completa ' + field.label.toLowerCase() + '.';
        }
    }
    if (values.password && values.password !== values.password_confirmation) {
        localErrors.password_confirmation = 'Las contraseñas no coinciden.';
    }
    if (Object.keys(localErrors).length) {
        event.preventDefault();
        await nextTick();
        document.getElementById(props.formKey + '-' + Object.keys(localErrors)[0])?.focus();
        return;
    }
    if (submitting.value) {
        event.preventDefault();
        return;
    }
    submitting.value = true;
}
</script>

<template>
    <!-- Adaptación del patrón de campos de uikit/FormLayout.vue de Sakai. -->
    <form :action="action" method="post" :aria-label="formLabel" @submit="submit">
        <input type="hidden" name="_token" :value="csrfToken">
        <input v-if="method !== 'POST'" type="hidden" name="_method" :value="method">
        <input type="hidden" name="_form" :value="formKey">
        <input v-for="(value, name) in hidden" :key="name" type="hidden" :name="name" :value="value">

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div v-for="field in fields" :key="field.name"
                class="flex flex-col gap-2 min-w-0" :class="{ 'md:col-span-2': field.wide }">
                <label :for="fieldId(field)" class="font-medium">
                    {{ field.label }}<span v-if="field.required" aria-hidden="true"> *</span>
                </label>

                <template v-if="field.type === 'select'">
                    <Select v-model="values[field.name]" :inputId="fieldId(field)"
                        :options="field.options" optionLabel="label" optionValue="value"
                        :aria-label="field.label" placeholder="Selecciona una opción"
                        :filter="field.options.length > 8" :invalid="Boolean(errorFor(field))"
                        :aria-describedby="errorFor(field) ? fieldId(field) + '-error' : undefined"
                        class="w-full" />
                    <input type="hidden" :name="field.name" :value="values[field.name]">
                </template>

                <Textarea v-else-if="field.type === 'textarea'"
                    v-model="values[field.name]" :id="fieldId(field)" :name="field.name"
                    :required="field.required" :maxlength="field.maxLength" rows="4" autoResize
                    :invalid="Boolean(errorFor(field))" class="w-full"
                    :aria-describedby="errorFor(field) ? fieldId(field) + '-error' : undefined" />

                <Password v-else-if="field.type === 'password'"
                    v-model="values[field.name]" :inputId="fieldId(field)" :name="field.name"
                    :feedback="false" toggleMask fluid :invalid="Boolean(errorFor(field))"
                    :inputProps="{ name: field.name, required: field.required, minlength: field.minLength,
                        autocomplete: 'new-password', 'aria-describedby': errorFor(field) ? fieldId(field) + '-error' : undefined }" />

                <InputText v-else v-model="values[field.name]" :id="fieldId(field)"
                    :name="field.name" :type="field.type || 'text'" :required="field.required"
                    :maxlength="field.maxLength" :pattern="field.pattern"
                    :invalid="Boolean(errorFor(field))" class="w-full"
                    :aria-describedby="errorFor(field) ? fieldId(field) + '-error' : undefined" />

                <small v-if="field.help" class="text-muted-color">{{ field.help }}</small>
                <small v-if="errorFor(field)" :id="fieldId(field) + '-error'" class="text-red-600" role="alert">
                    {{ errorFor(field) }}
                </small>
            </div>
        </div>

        <p v-if="help" class="text-muted-color mt-6 mb-0">{{ help }}</p>
        <div class="flex flex-wrap items-center gap-3 mt-6">
            <Button type="submit" :label="submitLabel" icon="pi pi-check"
                :loading="submitting" :disabled="submitting" />
            <Button v-if="cancelUrl" as="a" :href="cancelUrl" label="Volver" severity="secondary" outlined />
        </div>
    </form>
</template>
