const trackingBar = document.querySelector('[data-note-tracking]');

if (trackingBar) {
    const stages = trackingBar.querySelectorAll('[data-tracking-stage]');
    const label = trackingBar.querySelector('[data-tracking-label]');
    const unit = trackingBar.querySelector('[data-tracking-unit]');
    const message = trackingBar.querySelector('.note-tracking-message');
    const badge = document.querySelector('.note-heading .note-state');
    const cite = document.querySelector('[data-tracking-cite]');
    const current = document.querySelector('[data-tracking-current]');
    const destination = document.querySelector('[data-tracking-destination]');
    let timer;
    let running = false;
    let stopped = false;

    function setText(element, value) {
        if (element.textContent.trim() !== value) {
            element.textContent = value;
        }
    }

    function showMessage(value) {
        setText(message, value);
        message.hidden = value === '';
    }

    function render(data) {
        const progress = data.seguimiento;
        for (const stage of stages) {
            const active = stage.dataset.trackingStage === progress.etapa;
            if (active && !stage.hasAttribute('aria-current')) {
                stage.setAttribute('aria-current', 'step');
            } else if (!active && stage.hasAttribute('aria-current')) {
                stage.removeAttribute('aria-current');
            }
        }
        setText(label, progress.etiqueta);
        setText(unit, progress.unidad.nombre);
        badge.dataset.state = data.estado;
        setText(badge, data.etiqueta_estado);
        setText(cite, data.cite ?? 'Por asignar');
        setText(current, data.unidad_actual.nombre);
        setText(destination.querySelector('dd'), data.destino_pendiente?.nombre ?? '');
        destination.hidden = data.destino_pendiente === null;
    }

    async function refresh() {
        clearTimeout(timer);
        if (running || stopped || document.hidden) {
            return;
        }
        running = true;
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 4000);
        try {
            const response = await fetch(trackingBar.dataset.noteTracking, {
                headers: { Accept: 'application/json' },
                cache: 'no-store',
                signal: controller.signal,
            });
            if (response.redirected || [401, 403, 404].includes(response.status)) {
                stopped = true;
                showMessage('El seguimiento ya no está disponible para esta sesión.');
            } else if (!response.ok) {
                throw new Error('Seguimiento no disponible');
            } else {
                render(await response.json());
                showMessage('');
            }
        } catch {
            showMessage('No se pudo actualizar el seguimiento. Reintentando…');
        } finally {
            clearTimeout(timeout);
            running = false;
            if (!stopped && !document.hidden) {
                timer = setTimeout(refresh, 2000);
            }
        }
    }

    document.addEventListener('visibilitychange', refresh);
    timer = setTimeout(refresh, 2000);
}
