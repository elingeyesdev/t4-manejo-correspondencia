function conectarVistaPrevia({ form, frame, estado, ruta, preparar, alError }) {
    let generado;
    let actual = 0;
    let enCurso = false;
    let solicitado = false;
    let temporizador;

    async function generar() {
        if (enCurso) {
            solicitado = true;
            return;
        }
        enCurso = true;
        const revision = actual;
        const datos = new FormData(form);
        datos.delete('_method');
        preparar(datos);
        estado.textContent = 'Preparando la hoja…';
        try {
            const respuesta = await fetch(ruta, {
                method: 'POST',
                body: datos,
                headers: { Accept: 'application/json, application/pdf' },
                redirect: 'error',
                signal: AbortSignal.timeout(25000),
            });
            if (revision !== actual) return;
            if (!respuesta.ok) {
                if (respuesta.status === 409) throw new Error('La nota cambió. Actualiza la página antes de confirmar.');
                if (respuesta.status === 429) throw new Error('Espera unos segundos y vuelve a solicitar la vista previa.');
                if (respuesta.status === 422) throw new Error('Revisa los datos o las imágenes seleccionadas.');
                throw new Error('No se pudo preparar la hoja. Vuelve a intentar.');
            }
            const tipo = respuesta.headers.get('Content-Type');
            if (!tipo?.startsWith('application/pdf') && !tipo?.startsWith('text/html')) {
                throw new Error('El servidor no entregó una vista previa.');
            }
            const pdf = await respuesta.blob();
            if (revision !== actual) return;
            if (generado) URL.revokeObjectURL(generado);
            generado = URL.createObjectURL(pdf);
            frame.src = generado;
            frame.hidden = false;
            estado.textContent = tipo.startsWith('text/html')
                ? 'Vista web. La paginación PDF estará disponible al configurar la exportación en el servidor.'
                : '';
        } catch (error) {
            if (revision === actual) {
                estado.textContent = error.name === 'TimeoutError' ? 'La vista previa tardó demasiado.' : error.message;
                alError?.();
            }
        } finally {
            enCurso = false;
            if (solicitado) {
                solicitado = false;
                generar();
            }
        }
    }

    window.addEventListener('pagehide', (event) => {
        if (!event.persisted && generado) URL.revokeObjectURL(generado);
    });

    return (espera = 0) => {
        actual++;
        clearTimeout(temporizador);
        estado.textContent = 'Actualizando la vista previa…';
        temporizador = setTimeout(generar, espera);
    };
}

const borrador = document.querySelector('[data-draft-preview]');
if (borrador) {
    const reintentar = document.querySelector('[data-draft-retry]');
    const actualizar = conectarVistaPrevia({
        form: borrador,
        frame: document.querySelector('[data-draft-frame]'),
        estado: document.querySelector('[data-draft-status]'),
        ruta: borrador.dataset.draftPreview,
        preparar(datos) {
            if (borrador.dataset.draftId) datos.set('borrador', borrador.dataset.draftId);
            reintentar.hidden = true;
        },
        alError() { reintentar.hidden = false; },
    });
    borrador.addEventListener('input', () => actualizar(1000));
    const filtro = borrador.querySelector('[data-copy-search]');
    const opciones = borrador.querySelectorAll('[data-copy-option]');
    filtro.addEventListener('input', (event) => {
        event.stopPropagation();
        const consulta = filtro.value.trim().toLocaleLowerCase('es');
        for (const opcion of opciones) {
            opcion.hidden = !opcion.textContent.toLocaleLowerCase('es').includes(consulta);
        }
    });
    reintentar.addEventListener('click', () => actualizar());
    actualizar();
}

for (const panel of document.querySelectorAll('[data-action-preview]')) {
    const form = panel.closest('form');
    const actualizar = conectarVistaPrevia({
        form,
        frame: panel.querySelector('iframe'),
        estado: panel.querySelector('[data-preview-status]'),
        ruta: panel.dataset.actionPreview,
        preparar(datos) { datos.set('accion', panel.dataset.operation); },
    });
    panel.addEventListener('toggle', () => { if (panel.open) actualizar(); });
    panel.querySelector('[data-preview-refresh]').addEventListener('click', () => actualizar());
    form.addEventListener('constancias-cambiaron', () => { if (panel.open) actualizar(400); });
    form.addEventListener('change', () => { if (panel.open) actualizar(400); });
}
