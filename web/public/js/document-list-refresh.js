const list = document.querySelector('[data-refresh-list]');

if (list) {
    let refreshing = false;
    async function refreshList() {
        if (refreshing || document.hidden || list.contains(document.activeElement)) return;
        refreshing = true;
        try {
            const response = await fetch(location.href, {
                cache: 'no-store',
                signal: AbortSignal.timeout(5000),
            });
            if (response.redirected && new URL(response.url).pathname === '/acceso') {
                location.assign(response.url);
                return;
            }
            if (!response.ok || response.redirected) return;
            const page = new DOMParser().parseFromString(await response.text(), 'text/html');
            const next = page.querySelector('[data-refresh-list]');
            if (next && next.innerHTML !== list.innerHTML && !list.contains(document.activeElement)) {
                list.replaceChildren(...next.childNodes);
            }
        } catch {
            // La próxima consulta mantiene disponible la última lista cargada.
        } finally {
            refreshing = false;
        }
    }

    window.setInterval(refreshList, 5000);
    document.addEventListener('visibilitychange', refreshList);
}
