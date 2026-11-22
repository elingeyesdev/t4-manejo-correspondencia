for (const form of document.querySelectorAll('[data-note-signature]')) {
    const canvas = form.querySelector('canvas');
    const input = form.elements.firma;
    const error = form.querySelector('[data-signature-error]');
    const context = canvas.getContext('2d');
    context.lineWidth = 2;
    context.lineCap = 'round';
    const strokes = [];
    let pointer = null;
    let points = 0;

    function position(event) {
        const bounds = canvas.getBoundingClientRect();
        return [
            Math.round(1000 * Math.min(1, Math.max(0, (event.clientX - bounds.left) / bounds.width))),
            Math.round(1000 * Math.min(1, Math.max(0, (event.clientY - bounds.top) / bounds.height))),
        ];
    }

    canvas.addEventListener('pointerdown', (event) => {
        if (pointer !== null || event.button !== 0 || strokes.length >= 32 || points >= 2000) {
            return;
        }
        pointer = event.pointerId;
        canvas.setPointerCapture(pointer);
        strokes.push([position(event)]);
        points++;
        error.hidden = true;
    });

    canvas.addEventListener('pointermove', (event) => {
        if (pointer !== event.pointerId || points >= 2000) {
            return;
        }
        const stroke = strokes.at(-1);
        const previous = stroke.at(-1);
        const point = position(event);
        if (point[0] === previous[0] && point[1] === previous[1]) {
            return;
        }
        context.beginPath();
        context.moveTo(previous[0] * canvas.width / 1000, previous[1] * canvas.height / 1000);
        context.lineTo(point[0] * canvas.width / 1000, point[1] * canvas.height / 1000);
        context.stroke();
        stroke.push(point);
        points++;
    });

    canvas.addEventListener('lostpointercapture', () => {
        if (strokes.at(-1)?.length === 1) {
            strokes.pop();
            points--;
        }
        pointer = null;
    });

    form.querySelector('[data-signature-clear]').addEventListener('click', () => {
        if (pointer !== null) {
            canvas.releasePointerCapture(pointer);
            pointer = null;
        }
        context.clearRect(0, 0, canvas.width, canvas.height);
        strokes.length = 0;
        points = 0;
        input.value = '';
        error.hidden = true;
    });

    form.addEventListener('submit', (event) => {
        if (pointer !== null || !strokes.some((stroke) => stroke.length > 1)) {
            event.preventDefault();
            error.textContent = 'Dibuja la firma antes de confirmar.';
            error.hidden = false;
            return;
        }
        input.value = JSON.stringify(strokes);
    });
}
