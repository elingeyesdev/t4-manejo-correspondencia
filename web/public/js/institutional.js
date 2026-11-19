const forms = document.querySelectorAll('[data-institutional-form]');

for (const form of forms) {
    const fileInput = form.querySelector('[data-attachment]');

    const validateAttachment = () => {
        const file = fileInput.files[0];
        let error = '';
        if (file && file.size === 0) {
            error = 'El archivo está vacío.';
        } else if (file && file.size > 10 * 1024 * 1024) {
            error = 'El archivo no debe superar los 10 MiB.';
        } else if (file?.type && !['application/pdf', 'image/jpeg', 'image/png'].includes(file.type)) {
            error = 'Selecciona un archivo PDF, JPG o PNG.';
        }
        fileInput.setCustomValidity(error);
    };

    if (fileInput) {
        fileInput.addEventListener('change', validateAttachment);
        form.addEventListener('reset', () => fileInput.setCustomValidity(''));
    }

    form.addEventListener('input', (event) => event.target.setCustomValidity?.(''));
    form.addEventListener('submit', (event) => {
        for (const field of form.querySelectorAll('[data-max-code-points]')) {
            const limit = Number(field.dataset.maxCodePoints);
            const length = Array.from(field.value.trim()).length;
            if (field.required && !length) {
                field.setCustomValidity('Completa este campo.');
            } else if (length > limit) {
                field.setCustomValidity('Escribe hasta ' + limit + ' caracteres.');
            }
        }
        if (fileInput) {
            validateAttachment();
        }
        if (!form.reportValidity() || form.dataset.submitting === 'true') {
            event.preventDefault();
            return;
        }
        form.dataset.submitting = 'true';
        form.querySelector('button[type="submit"]').disabled = true;
    });
}

window.addEventListener('pageshow', (event) => {
    if (!event.persisted) {
        return;
    }
    for (const form of forms) {
        delete form.dataset.submitting;
        form.querySelector('button[type="submit"]').disabled = false;
    }
});
