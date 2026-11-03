# QR de la hoja de ruta — #19 / T09

## Alcance y estado

Iteración 03, responsable Xmathewbruk. Rama `feature/19-qr-hoja-ruta`, desde develop actualizado a b2eec25. Generación de QR y consulta autorizada de una hoja existente. No implementa confirmación de recepción, derivación ni cambios del historial.

Estado actualizado al 03/11/2026: #19 completado. [PR #25](https://github.com/elingeyesdev/t4-manejo-correspondencia/pull/25) aprobado por RazzellRC e integrado en `develop` el 02/11/2026, merge `8e9d87fba06acd122670a42ee1a395d6077e386e`. La [aprobación](https://github.com/elingeyesdev/t4-manejo-correspondencia/pull/25#pullrequestreview-5743923932) precede al merge. Mathew confirmó que el QR escaneado desde el teléfono abre el documento mediante la dirección Wi-Fi del servidor. La evidencia de desarrollo inferior conserva sus ejecutores originales; esta actualización documental no repite esas pruebas ni acredita aceptación docente o cierre de toda la iteración.

## Referencia y contenido

Se reutiliza el UUID aleatorio de la hoja creado con `Str::uuid()` por RegisterDocument. No se crean tablas, referencias de acceso ni migraciones adicionales. El contenido es una URL absoluta `/hojas/{reference}`, donde reference es el UUID de la hoja, no el UUID del documento.

El QR no incluye nombres, asunto, credenciales ni tokens. Tener la referencia no concede acceso. La consulta web dirige al detalle del documento autorizado; la API devuelve el payload documental existente, con la hoja correcta.

## Contrato web y API

| Método | Ruta | Resultado |
|---|---|---|
| GET | `/hojas/{reference}` | Sesión web; redirección al detalle autorizado |
| GET | `/hojas/{reference}/qr.svg` | Sesión web; imagen SVG |
| GET | `/api/hojas/{reference}` | Bearer token; JSON documental con `hoja.id` |
| GET | `/api/hojas/{reference}/qr.svg` | Bearer token; imagen SVG |

Las cuatro rutas exigen autenticación y cuenta/unidad habilitadas. Se conserva la visibilidad documental: administrador global; recepción y funcionario en su unidad. Las respuestas usan caché privada sin almacenamiento. El SVG declara `image/svg+xml` y `nosniff`.

Una referencia inexistente, mal formada o no visible devuelve 404, evitando confirmar documentos ajenos. En rutas API válidas, falta de autenticación devuelve 401; cuenta/unidad no operativa, 403. La web solicita inicio de sesión. La consulta no guarda movimientos ni modifica el estado o versión de la hoja.

Para Android: reconocer la ruta de hoja de la instancia configurada, extraer el UUID y consultar la ruta propia `/api/hojas/{reference}` con el token de esa instancia. No transmitir el token a un origen obtenido libremente de un QR. El escáner integrado de Android no se modifica en este issue; coordinar el contrato con RazzellRC.

## Generación y diseño

Endroid QR Code 6.1.3, licencia MIT; dependencias BaconQrCode 3.1.1 y dasprid/enum 1.0.7. Fuentes: https://github.com/endroid/qr-code/tree/6.1.3 y licencias distribuidas en vendor, instalado desde composer.lock. La generación SVG no necesita instalar GD para PNG.

La tarjeta se incorpora al componente DocumentDetail de Sakai ya adoptado por el proyecto, reutilizando `card`, Button y estilos existentes. Conserva la procedencia de Sakai Vue 5.0.0 indicada en `sakai-web.md`. Se muestra antes del historial inicial, con mensaje de error de carga y enlace de consulta. Los componentes de adjuntos se conservan.

## Acceso local desde teléfono

La URL generada usa el origen con el que se solicita la imagen. Un QR obtenido desde `127.0.0.1` apunta al propio dispositivo que lo abre y no permite al teléfono acceder a la computadora.

Para comprobar en Wi-Fi, computadora y teléfono deben usar la misma red y la página de detalle debe abrirse desde la IP privada de la computadora. Se necesita abrir la página por esa dirección y volver a leer el QR, no reutilizar una captura generada con localhost. La IP puede cambiar; no está codificada en el servicio. Iniciar sesión en el origen Wi-Fi puede requerir una sesión distinta a la de localhost.

El arranque predeterminado `scripts/Servir-WebLocal.cmd` conserva loopback. Para la prueba de red de esta sesión, Codex inició temporalmente otro proceso PHP vinculado a la IPv4 Wi-Fi detectada, puerto 8000, con temporales privados, subida 10M, petición 12M y memoria 256M. No cambió firewall, .env ni php.ini global. El proceso usa el mismo router de Laravel y la misma base local. HTTPS y una dirección estable corresponden al entorno de despliegue; el HTTP de esta sesión es una prueba local.

## Evidencia del 02/11/2026

Ejecutor del desarrollo manual y las pruebas siguientes: Mathew, guiado por Codex, con salidas compartidas en el chat.

- Consultas iniciales: 6 pruebas y 22 aserciones.
- Suite específica RouteSheetQrTest: 11 pruebas y 45 aserciones; referencia correcta, SVG válido, visibilidad por unidad, funcionario, cuenta deshabilitada, referencias inválidas, redirección web y ausencia de cambios de hoja/movimientos.
- Suite completa SQLite en memoria: 64 pruebas, 348 aserciones.
- PostgreSQL local aislado mediante `scripts/test-postgres.php`: 64 pruebas, 348 aserciones; concurrencia: 1 prueba, 13 aserciones. No se usó la base habitual para estas pruebas.
- Compilación Vite aprobada; Pint aprobado sobre 61 archivos tras corregir formato.
- Navegador: tarjeta y SVG visibles en la captura compartida por Mathew. El usuario confirmó que el botón Consultar vuelve al mismo documento y que el teléfono reconoce el QR generado con localhost, aunque no podía abrir ese origen.
- Codex comprobó HTTP 200 en el acceso local y en el acceso Wi-Fi. Tras acceder por la dirección de red, Mathew confirmó expresamente, en respuesta a la comprobación del escaneo y apertura del mismo documento, «si funciona y abre el telefono». La evidencia física es una confirmación del usuario; no una ejecución directa de Codex.

No se simula prueba física de Codex, revisión del compañero ni aprobación anterior al merge.

## Comandos principales ejecutados por Mathew

Desde la raíz, `git switch develop`, `git pull --ff-only origin develop` y `git switch -c feature/19-qr-hoja-ruta`.

Desde web:

```powershell
php artisan make:controller RouteSheetQrController
composer require "endroid/qr-code:6.*"
composer show endroid/qr-code
php artisan route:list --path=hojas -v
php artisan test --filter=RouteSheetQrTest
npm.cmd run build
php artisan test
php vendor/bin/pint app/Http/Controllers/RouteSheetQrController.php app/Models/RouteSheet.php app/Services/RouteSheetQr.php routes/api.php routes/web.php tests/Feature/RouteSheetQrTest.php
php vendor/bin/pint --test
php ..\scripts\test-postgres.php
```

Codex realizó lecturas para orientar los cambios, levantó los servidores locales por solicitud del usuario y preparó esta documentación. Los comandos y sus resultados no se atribuyen a un integrante distinto de su ejecutor real.

