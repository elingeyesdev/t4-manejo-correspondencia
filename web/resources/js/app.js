import './bootstrap';
import './sakai/assets/styles.scss';
import { createSakaiApp } from './sakai/primevue';

async function mountWidget(element, loader, attribute = 'props') {
    if (!element) return;
    const data = JSON.parse(element.dataset[attribute]);
    const props = attribute === 'context' ? { context: data } : data;
    const { default: component } = await loader();
    createSakaiApp(component, props).mount(element);
}

async function boot() {
    // El layout coloca el HTML de Laravel antes de montar sus controles.
    await mountWidget(
        document.getElementById('sakai-app'),
        () => import('./sakai/SakaiApp.vue'),
        'context',
    );

    await Promise.all([
        mountWidget(document.getElementById('login-form'), () => import('./sakai/LoginForm.vue')),
        mountWidget(document.getElementById('documents-table'), () => import('./sakai/DocumentsTable.vue')),
        mountWidget(document.getElementById('document-detail'), () => import('./sakai/DocumentDetail.vue')),
        ...Array.from(document.querySelectorAll('[data-sakai-form]'), (element) =>
            mountWidget(element, () => import('./sakai/SakaiForm.vue')),
        ),
    ]);
}

boot().catch((error) => {
    console.error('No se pudo iniciar la interfaz.', error);
    const notice = document.createElement('div');
    notice.setAttribute('role', 'alert');
    notice.className = 'm-4 p-4 rounded-border bg-red-50 text-red-900';
    notice.textContent = 'No se pudo cargar la pantalla. Actualiza la página para intentarlo de nuevo.';
    document.body.prepend(notice);
});
