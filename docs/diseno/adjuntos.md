# Adjuntos cifrados — #18 / T08

## Estado

Implementación local en la rama `feature/18-adjuntos-cifrados`.

Validación observada en las salidas compartidas por Mathew: suite configurada con SQLite en memoria, 46 pruebas aprobadas y 237 aserciones. Incluye cifrado, almacenamiento, permisos, formatos y recuperación simulada.

Pendientes: comprobación con PostgreSQL y servidor local, integración Android, revisión cruzada y PR hacia `develop`. Este registro no acredita aceptación docente.

## Contrato para Android — #21

Todas las operaciones requieren `Authorization: Bearer <token>` y una cuenta/unidad habilitadas.

| Operación | Ruta | Resultado |
|---|---|---|
| Subir | POST `/api/documentos/{id}/adjuntos` | 201 con datos del adjunto |
| Listar | GET `/api/documentos/{id}/adjuntos?page=1` | 200 con listado paginado en `data` |
| Descargar | GET `/api/documentos/{id}/adjuntos/{adjunto}/descarga` | 200 con contenido binario original |

La carga utiliza `multipart/form-data`, campo `archivo`, y `Accept: application/json`. El cliente HTTP debe generar el encabezado multipart con su delimitador.

Se permiten PDF, JPEG y PNG según el MIME detectado por el servidor. Tamaño: al menos un byte y máximo 10 485 760 bytes (10 MiB). La detección MIME no equivale a una validación estructural completa del formato.

La respuesta de carga contiene: `id`, `document_id`, `nombre`, `mime`, `tamano_bytes`, `creado_en` y `descarga_url`.

La descarga también requiere el token. Android debe descargar mediante una petición autenticada y abrir una copia local mediante el mecanismo de archivos de la aplicación. Abrir únicamente la URL en un visor externo no transmite automáticamente el token.

## Permisos y errores

Administrador y recepción pueden subir a documentos autorizados. Funcionario puede listar y descargar documentos visibles de su unidad. Administrador tiene visibilidad global.

- 401: falta autenticación o el token no es válido.
- 403: operación no permitida o cuenta/unidad deshabilitada.
- 404: documento no visible/inexistente o adjunto ajeno al documento.
- 422: validación; consultar `errors.archivo`.
- 503: fallo al guardar o recuperar el adjunto.

La carga todavía no implementa idempotencia: repetir una petición puede crear otro adjunto. Ante una respuesta perdida, consultar el listado antes de repetir automáticamente.

## Cifrado y almacenamiento

Los archivos se cifran mediante el servicio de cifrado de Laravel con AES-256-CBC y comprobación de integridad. Se guardan en el disco privado `attachments`, sin descarga automática.

La tabla conserva metadatos, ubicación privada y versión de clave. Las respuestas excluyen ubicación y versión de clave.

La versión activa es `v1`; su clave procede de `ATTACHMENTS_KEY_V1`. Esta clave es exclusiva del servidor: no se entrega al móvil ni se publica en Git.

## Respaldo y recuperación

Respaldar de forma coherente la base de datos y `storage/app/private/attachments`. Conservar las claves correspondientes a cada `key_version` en un respaldo protegido y separado del código.

Para recuperar: restaurar los metadatos, los archivos cifrados en sus mismas ubicaciones y las claves originales; limpiar la caché de configuración y comprobar una descarga autenticada.

Generar otra clave bajo el mismo nombre no recupera los archivos anteriores. Una rotación futura debe conservar las claves antiguas bajo sus versiones.

La prueba automatizada verifica pérdida y restauración simuladas de clave/archivo. El procedimiento operativo de respaldo y restauración con PostgreSQL sigue pendiente de comprobación.

Si falla el registro tras escribir el archivo, se intenta eliminarlo. Un fallo de limpieza queda registrado y requiere conciliación; la base de datos y el almacenamiento no forman una transacción única.

## Ejecución y trazabilidad

Mathew ejecutó manualmente el desarrollo guiado y compartió la salida de `php artisan test` con 46 pruebas aprobadas y 237 aserciones. El código y las pruebas fueron preparados con asistencia de Codex. Esto no acredita una sesión de programación en pareja ni la revisión del compañero.

La documentación y la entrada vacía `ATTACHMENTS_KEY_V1=` de `web/.env.example` fueron preparadas por Codex por solicitud expresa de Mathew. No se publica la clave real.

## Verificación autónoma de Codex — 02/11/2026

Por solicitud de Mathew, Codex creó este documento y añadió la variable vacía a `web/.env.example`. La comprobación de formato detectó diferencias; Codex aplicó Pint únicamente a los doce archivos PHP del #18 y volvió a verificar.

Comandos ejecutados desde `web`:

```powershell
php vendor/bin/pint app/Http/Controllers/AttachmentController.php app/Http/Requests/StoreAttachmentRequest.php app/Models/Attachment.php app/Services/AttachmentCipher.php app/Services/StoreAttachment.php config/attachments.php config/filesystems.php database/migrations/2026_11_02_050843_create_attachments_table.php routes/api.php tests/Feature/AttachmentApiTest.php tests/Feature/AttachmentCipherTest.php tests/Feature/StoreAttachmentTest.php
php artisan test
php vendor/bin/pint --test
```

Resultados: 46 pruebas aprobadas, 257 aserciones; revisión de formato aprobada. Este resultado corresponde a la ejecución directa de Codex y se distingue del resumen histórico compartido por Mathew.

Desde la raíz se ejecutaron `git status --short --branch`, `git diff --check` y `git check-ignore web/.env`. Rama confirmada: `feature/18-adjuntos-cifrados`; sin errores de espacios reportados; `web/.env` permanece excluido. Git advierte que normalizará los finales CRLF de `.env.example` a LF. No se ejecutó migración sobre la base habitual, ni commit, push o integración.

## Verificación PostgreSQL — 02/11/2026

Ejecutor real: Codex, por solicitud de continuar la comprobación. Se confirmó con `git ls-files --error-unmatch web/.env` que `.env` no está versionado y con `git check-ignore -v web/.env` que la regla de exclusión sigue activa.

PostgreSQL estaba detenido. Se ejecutó `scripts/Iniciar-PostgresLocal.cmd`; el servidor completó su recuperación y quedó disponible en la interfaz local. Antes de las pruebas se comprobó por PDO que la conexión era local, que no había una DB_URL que redirigiera la conexión, que la base habitual era distinta y que `current_database()` devolvía `correspondencia_test`.

Comando desde la raíz:

```powershell
php scripts/test-postgres.php
```

Resultado PostgreSQL: 46 pruebas aprobadas, 257 aserciones. Concurrencia: 1 prueba aprobada, 13 aserciones. El ejecutor utiliza la base aislada `correspondencia_test`.

Comando de consulta desde `web`:

```powershell
php artisan migrate:status --no-ansi
```

Resultado: las migraciones previas de la base habitual están aplicadas; `2026_11_02_050843_create_attachments_table` está pendiente. En esta comprobación no se aplicó la migración a la base habitual. Siguen pendientes el recorrido HTTP local, la integración Android y la revisión cruzada. La verificación automatizada de recuperación no sustituye una restauración operativa de respaldos.

## Recorrido HTTP local observado — 02/11/2026

Ejecutor: Mathew, mediante comandos guiados y salidas compartidas en el chat. La migración `2026_11_02_050843_create_attachments_table` se aplicó a la base habitual con resultado DONE. Se inició sesión por POST /api/sesiones, se consultó la bandeja y se subió `tests/Fixtures/adjunto.jpg` al documento ficticio de revisión.

El primer intento falló con HTTP 422 y `validation.uploaded`: PHP informó que no podía crear el archivo temporal. Se reinició el servidor con `php artisan serve --host=127.0.0.1 --port=8000 --no-reload`. La siguiente carga se registró correctamente (JPEG, 669 bytes). La descarga autenticada a un archivo temporal y la comparación SHA-256 con el original dieron `Contenido identico: True`. Este resultado acredita el recorrido local del JPEG pequeño; no acredita integración Android ni el límite superior mediante HTTP.

Codex revisó `php --ini` y los valores efectivos de PHP: upload_max_filesize=2M, post_max_size=8M y memory_limit=128M. Esos límites impedían cubrir el máximo de la API con el arranque anterior.

Se añadió `scripts/Servir-WebLocal.cmd`, que configura únicamente el proceso del servidor local: upload_max_filesize=10M, post_max_size=12M, memory_limit=256M y una carpeta temporal en `.local/uploads-temp` (excluida de Git). Usa el router incluido en Laravel y escucha en 127.0.0.1:8000. No modifica php.ini ni .env.

Arranque recomendado desde web, después de detener el servidor anterior:

```powershell
..\scripts\Servir-WebLocal.cmd
```

Pendiente: ejecutar este arranque y verificar mediante HTTP el límite superior, además de revisión cruzada e integración Android.

## Límites HTTP y revisión final — 02/11/2026

Mathew ejecutó `scripts/Servir-WebLocal.cmd` y verificó con una petición multipart autenticada que un JPEG de prueba con relleno hasta 10 485 760 bytes se acepta y registra ese tamaño. La petición de 10 485 761 bytes fue rechazada y el total paginado de adjuntos se mantuvo sin cambios (`Sin nuevo adjunto: True`). Estas pruebas comprueban el transporte y los límites usando contenido de prueba, no una fotografía natural de ese tamaño.

El rechazo por el límite de PHP devolvía `validation.uploaded`. Mathew añadió el mensaje español `archivo.uploaded` y precisó la unidad MiB en `archivo.max`. Después compartió la ejecución de `php artisan test --filter=AttachmentApiTest`: 12 pruebas aprobadas, 85 aserciones. Codex ajustó únicamente el formato de ese archivo con Pint y comprobó de nuevo el formato y la suite de API.

Estado actualizado: migración local aplicada, recorrido HTTP de JPEG pequeño con SHA-256 coincidente y límites de transporte comprobados. Falta revisión cruzada, publicación e integración del PR y prueba Android con el responsable del #21. La restauración operativa de respaldos sigue pendiente; solo está verificada la recuperación simulada en pruebas.
