# Validación inicial del servidor para la Iteración 06

Issue [#60](https://github.com/elingeyesdev/t4-manejo-correspondencia/issues/60). Prueba del 21 de noviembre de 2026, hora de Bolivia.

## Entorno comprobado

- Código de `develop` en el commit `461c9af1b7576d79d252f9a8f7e1e28631e944f0`.
- Web y API de Laravel en `127.0.0.1:8050`. Configuración y base SQLite aisladas, con datos ficticios y sin acceso desde la red.
- Camunda 8.9.28 en el proyecto Docker Compose existente `correspondencia-camunda-43`. Salud y topología devuelven HTTP 200. Definición activa del BPMN `nota_interna`, versión 1.

## Resultados

| Caso | CITE ficticio | Instancia Camunda | Resultado |
|---|---|---|---|
| Envío directo | `NI/DEMO/EMISOR/2026/000001` | `2251799813685687` | Emisión por formulario web con sesión y CSRF, mismo CITE en API, recepción, atención y cierre. |
| Dos VÍAS | `NI/DEMO/EMISOR/2026/000002` | `2251799813685701` | Emisión por API. La segunda VÍA recibió 404 antes de su turno. Ambas conformidades se registraron en orden, seguidas de recepción, derivación, segunda recepción, atención y cierre. |

En ambos casos, Laravel devolvió `cerrada`, Camunda devolvió `COMPLETED` y la ruta API usada al abrir un QR devolvió HTTP 200 para el funcionario autorizado. La búsqueda en Camunda por el UUID de cada nota devolvió una sola instancia. El [resultado de la prueba](resultado-inicial-servidor.json) registra identificadores ficticios y estados observados. Las cuentas, contraseñas, tokens y datos de conexión se gestionan fuera del repositorio.

## Instalación y verificación de la versión final

1. Preparar el entorno de destino con PHP y extensiones según `web/composer.lock`, Composer, Node.js, PostgreSQL y el servicio existente de Camunda. Registrar el commit de `develop` y las versiones de runtime.
2. En `web/`, instalar dependencias con `composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader`, luego ejecutar `npm ci` y `npm run build`. Confirmar que el despliegue incluya `public/build/manifest.json` y que el servidor web sirva `web/public`.
3. Configurar `APP_ENV=production`, `APP_DEBUG=false`, `APP_URL` con la URL HTTPS y los valores privados de PostgreSQL y `CAMUNDA_URL`. Preservar la `APP_KEY` de una instalación existente. Confirmar permisos de escritura de `storage` y `bootstrap/cache` para el usuario de la aplicación.
4. Respaldar la base y el almacenamiento privado antes de actualizar una instalación existente. Ejecutar `php artisan migrate --force` y registrar el resultado. Verificar la definición BPMN activa y las instancias en curso antes de desplegar una versión diferente del proceso.
5. Verificar `/up`, la pantalla `/acceso` y la autenticación API. Comprobar que la URL HTTPS sea accesible desde un Android físico sin USB y que el APK use esa misma URL. Registrar versión del APK y red de la prueba.
6. Repetir con Russel los casos directo y con dos VÍAS, incluyendo firma, emisión, conformidades, avisos, recepción con sello, derivación, seguimiento, cierre y consulta autorizada. Adjuntar evidencias con datos ficticios y el resultado de cada criterio.

La prueba de este documento corresponde al corte local inicial. Quedan pendientes la publicación de la versión final con los cambios de la Iteración 06 y la validación conjunta en el teléfono vinculada al [#65](https://github.com/elingeyesdev/t4-manejo-correspondencia/issues/65).
