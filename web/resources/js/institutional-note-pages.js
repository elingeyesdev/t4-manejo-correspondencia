(() => {
    const original = document.querySelector('article.hoja');
    const pages = document.createElement('div');
    pages.className = 'paginas';
    original.after(pages);

    function addPage() {
        const page = document.createElement('article');
        page.className = 'hoja pagina';
        const content = document.createElement('div');
        content.className = 'contenido-pagina';
        page.append(content);
        pages.append(page);
        return content;
    }

    const fits = (content) => content.scrollHeight <= content.clientHeight;

    function appendBlock(content, block) {
        content.append(block);
        if (fits(content)) return content;
        if (content.childElementCount === 1) throw new Error('Un bloque excede el área imprimible.');

        const next = addPage();
        next.append(block);
        if (!fits(next)) throw new Error('Un bloque excede el área imprimible.');
        return next;
    }

    function appendFields(content, fields) {
        let group = fields.cloneNode();
        content.append(group);
        for (const field of fields.children) {
            const copy = field.cloneNode(true);
            group.append(copy);
            if (!fits(content)) {
                copy.remove();
                if (!group.childElementCount) group.remove();
                group = fields.cloneNode();
                group.append(copy);
                content = appendBlock(addPage(), group);
            }
        }
        return content;
    }

    function fillBody(content, block) {
        const text = block.textContent;
        const segmenter = new Intl.Segmenter('es', { granularity: 'grapheme' });
        const offsets = [...Array.from(segmenter.segment(text), ({ index }) => index), text.length];
        let start = 0;
        while (start < offsets.length - 1) {
            const part = block.cloneNode();
            content.append(part);
            part.textContent = text.slice(offsets[start]);
            if (fits(content)) return content;

            part.classList.add('continua');
            let low = start;
            let high = offsets.length - 1;
            while (low + 1 < high) {
                const middle = Math.floor((low + high) / 2);
                part.textContent = text.slice(offsets[start], offsets[middle]);
                if (fits(content)) low = middle;
                else high = middle;
            }

            // Preserve whitespace and prefer a natural boundary over splitting a word.
            const fragment = text.slice(offsets[start], offsets[low]);
            const boundary = Math.max(fragment.lastIndexOf(' '), fragment.lastIndexOf('\n'), fragment.lastIndexOf('\t'));
            if (boundary >= 0) low = offsets.indexOf(offsets[start] + boundary + 1, start + 1);
            if (low <= start) {
                part.remove();
                if (!content.childElementCount) throw new Error('La página no admite una línea de texto.');
            } else {
                part.textContent = text.slice(offsets[start], offsets[low]);
                start = low;
            }
            content = addPage();
        }
        return content;
    }

    function scalePages() {
        const width = pages.firstElementChild.offsetWidth;
        if (width > 0) pages.style.zoom = Math.min(1, (document.documentElement.clientWidth - 16) / width);
    }

    document.fonts.ready.then(() => {
        if (!window.matchMedia('screen').matches) return;
        try {
            let content = addPage();
            for (const block of original.children) {
                if (block.matches('.cuerpo') && block.textContent.length) {
                    content = fillBody(content, block);
                } else if (block.matches('dl')) {
                    content = appendFields(content, block);
                } else {
                    content = appendBlock(content, block.cloneNode(true));
                }
            }
            pages.classList.add('lista');
            original.classList.add('original-paginado');
            scalePages();
            window.addEventListener('resize', scalePages);
        } catch (error) {
            pages.remove();
            console.error(error);
        }
    });
})();
