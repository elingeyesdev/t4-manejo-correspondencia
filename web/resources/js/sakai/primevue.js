import { createApp } from 'vue';
import PrimeVue from 'primevue/config';
import Aura from '@primeuix/themes/aura';

export function createSakaiApp(component, props) {
    const app = createApp(component, props);
    app.use(PrimeVue, {
        theme: {
            preset: Aura,
            options: { darkModeSelector: '.app-dark' },
        },
    });
    return app;
}
