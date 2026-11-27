for (const visor of document.querySelectorAll('[data-note-viewer]')) {
    const estado = visor.querySelector('[data-pdf-status]');
    let generando = false;
    visor.querySelector('[data-print-note]').addEventListener('click', () => {
        const marco = visor.querySelector('iframe');
        if (marco.contentDocument?.querySelector('article.hoja')) {
            if (!generando) estado.hidden = true;
            marco.contentWindow.print();
        } else {
            estado.hidden = false;
            estado.textContent = 'Espera a que aparezca la hoja y vuelve a pulsar Imprimir.';
        }
    });
    visor.addEventListener('click', async (event) => {
        const enlace = event.target.closest('[data-versioned-pdf]');
        if (!enlace || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
        event.preventDefault();
        if (generando) return;

        const revision = visor.dataset.revision;
        estado.hidden = false;
        estado.textContent = 'Generando PDF…';
        generando = true;

        try {
            const respuesta = await fetch(enlace.href, {
                headers: { Accept: 'application/json, application/pdf' },
                cache: 'no-store',
                redirect: 'error',
                signal: AbortSignal.timeout(25000),
            });
            if (respuesta.status === 409 || revision !== visor.dataset.revision) {
                throw new Error('La nota cambió. Revisa la hoja actualizada y vuelve a intentarlo.');
            }
            if (!respuesta.ok || !respuesta.headers.get('Content-Type')?.startsWith('application/pdf')) {
                throw new Error('El PDF no se pudo generar. Abre la hoja en el navegador para imprimirla o vuelve a intentar.');
            }
            const archivo = await respuesta.blob();
            if (await archivo.slice(0, 5).text() !== '%PDF-') {
                throw new Error('El archivo recibido no es un PDF válido. Vuelve a intentar.');
            }
            if (visor.hidden || revision !== visor.dataset.revision) {
                throw new Error('La nota cambió. Revisa la hoja actualizada y vuelve a intentarlo.');
            }
            const url = URL.createObjectURL(archivo);
            const descarga = document.createElement('a');
            const nombre = respuesta.headers.get('Content-Disposition')?.match(/filename="([^"]+)"/)?.[1];
            descarga.href = url;
            descarga.download = nombre ?? 'nota-interna.pdf';
            document.body.append(descarga);
            descarga.click();
            descarga.remove();
            setTimeout(() => URL.revokeObjectURL(url), 60000);
            estado.textContent = 'Descarga iniciada.';
        } catch (error) {
            estado.textContent = error instanceof TypeError || error.name === 'TimeoutError'
                ? 'No se pudo obtener el PDF. Puedes seguir leyendo la hoja y reintentar.'
                : error.message;
        } finally {
            generando = false;
        }
    });
}
