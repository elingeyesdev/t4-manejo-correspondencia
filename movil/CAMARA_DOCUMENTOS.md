# Cámara y adjuntos de correspondencia — #21

Implementación móvil en `feature/21-movil-adjuntos`, asistida con Codex. Conserva el tema Sakai existente. No acredita revisión del compañero ni aceptación docente.

## Recorrido

Mi bandeja → abrir un documento → Adjuntos → Adjuntar foto → Abrir cámara → Tomar foto → Usar foto → Subir foto.

- Consejos de encuadre, luz y legibilidad antes y después de capturar.
- Permiso nativo de Android, solicitado solo al abrir la cámara. Respeta el permiso vigente y permite abrir ajustes si se bloqueó.
- Cámara trasera cuando existe; solo fotografía, sin grabación de audio. Vista previa, repetir y descartar.
- La foto se conserva al desplazarse por el detalle; salir sin enviarla requiere confirmar su descarte.
- Subida real, con botón deshabilitado durante la operación. No se permite salir del detalle mientras termina.
- Confirmación solo tras HTTP 201 y metadatos válidos del mismo documento, nombre, MIME y tamaño enviados.
- Listado paginado y actualización de adjuntos reales; abrir imágenes permite ampliar. Los PDF se descargan autenticados y se abren con el lector del teléfono. Si no hay lector, se informa sin afirmar que se abrió el archivo.
- Recepción y administrador pueden capturar/subir; funcionario solo consulta. El backend vuelve a verificar la autorización.

## Contrato utilizado

Backend de Mathew, PR #23, commit `91860f2175353e9641074d1400c95aca40c39d26`:

- POST `/api/documentos/{id}/adjuntos`, multipart campo `archivo`, HTTP 201.
- GET `/api/documentos/{id}/adjuntos?page=1`, paginación en `data`, `current_page`, `last_page`.
- GET `/api/documentos/{id}/adjuntos/{adjunto}/descarga`, binario autenticado.
- Formatos: JPEG, PNG y PDF; máximo 10 MiB. La cámara sube JPEG/PNG y el listado puede abrir los tres formatos.

Todas las peticiones llevan el token vigente. El móvil construye la ruta propia de descarga y no sigue `descarga_url` hacia otros orígenes ni redirecciones. Verifica MIME y longitud del contenido recibido. Se manejan rechazo 422, permisos 403, sesión vencida 401, conexión y respuesta incompleta.

## Respuesta perdida y duplicados

El backend no hace idempotente la carga. El móvil bloquea pulsaciones repetidas y nunca repite automáticamente un POST.

Cada captura recibe un nombre único antes del envío. Si no se confirma la respuesta, Comprobar subida busca ese nombre entre las páginas y compara el contenido descargado con los bytes originales antes de confirmar. Volver a enviar exige una confirmación explícita por el riesgo de duplicar una petición cuyo resultado aún no se conoce.

## Archivos locales

Las capturas son temporales y privadas: se eliminan al descartarlas, sustituirlas o confirmar el guardado. No son una cola persistente de envíos. Al terminar el proceso Android puede retirar su caché; la app no promete conservar fotos no enviadas tras cerrar el documento.

Los PDF se entregan al visor mediante una copia en caché privada, no en Descargas ni en una URL pública. La caché puede ser retirada por Android. Una vez abierto, el visor externo puede mantener su propia copia; no se publica una clave ni se entrega el token al visor.

## Backend local actual

Los commits originales del PR #23 se incorporaron por avance directo únicamente a la rama local `feature/21-movil-adjuntos`, conservando la autoría de Mathew. No se aprobó ni fusionó su PR en GitHub, ni se modificó develop.

Móvil y web se ejecutan ahora desde la carpeta habitual `web/`. La copia temporal de ejecución ya no se utiliza. Se añadió el panel de adjuntos web sin cambiar los componentes de acceso, registro o navegación existentes.

La base local habitual y `web/storage/app/private/attachments` conservan los mismos datos. La clave `ATTACHMENTS_KEY_V1` sigue en `.env`, excluida de Git. No cambiar la clave de los archivos ya guardados.

El servidor utiliza temporales privados, `upload_max_filesize=10M`, `post_max_size=12M` y `memory_limit=256M`. Está disponible en loopback y en la IP Wi-Fi actual `192.168.1.72:8000`. Para ver los mismos registros, ambos clientes deben usar esa misma instancia; otra computadora con su propia base no comparte datos por publicar el código en GitHub.

## Comprobaciones y evidencia

- Pruebas backend del PR #23 sobre PostgreSQL aislado: 46 aprobadas, 257 aserciones; concurrencia: 1 aprobada, 13 aserciones.
- `test/adjuntos_api_test.dart`: multipart, token, rutas propias, validación de respuesta/binarios, permisos, respuesta perdida, paginación y sesión reemplazada.
- `test/adjuntos_widget_test.dart`: no duplicar pulsaciones, impedir salida durante subida, abrir imagen guardada, conservar foto rechazada y restringir captura por rol.
- `test/camara_documento_test.dart`: permisos, consejos, repetición, navegación y descarte.
- `test/adjuntos_real_test.dart`: servicio Flutter + HTTP real + Laravel del PR #23 + PostgreSQL `correspondencia_test`. Sube un JPEG, lista, descarga y compara bytes; comprueba metadatos, cifrado y contenido descifrado en BD/almacenamiento. Verifica lectura por funcionario y rechazo de su carga. Usa actores/documentos ficticios y almacenamiento temporal; los elimina al terminar.

Para la prueba real se requieren `LARAVEL_TEST_PHP` y `LARAVEL_ADJUNTOS_BACKEND` con la ruta absoluta al backend del PR #23. La fixture rechaza cualquier conexión que no sea PostgreSQL local `correspondencia_test`.

```text
flutter analyze
flutter test --concurrency=1
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.72:8000
```

La prueba física de captura → subida → apertura se realiza desde Android Studio con el teléfono del usuario. No se inició ningún emulador para esta integración. La prueba automática de cámara nativa `integration_test/camara_dispositivo_test.dart` permanece separada de los tests de contrato y no acredita una ejecución ya realizada.

## Antes de cerrar #21

- Recorrido completo del usuario en el teléfono y evidencia de esa ejecución.
- Revisión cruzada del compañero y PR móvil.
- Revisar/integrar por separado el PR #23 según el flujo acordado.

La sección web complementaria permite subir, ver y descargar los mismos archivos; su alcance y comprobaciones se documentan en `docs/diseno/adjuntos-web-movil.md`. QR #19 e historial #20 mantienen sus revisiones y entregables independientes.

## Fuentes

- Cámara oficial: https://pub.dev/packages/camera
- Permisos compatibles con este proyecto: https://pub.dev/packages/permission_handler/versions/12.0.1
- Apertura nativa de PDF: https://pub.dev/packages/open_filex
- Caché privada: https://pub.dev/packages/path_provider
- Tema y licencias existentes: DISENO_SAKAI.md.

## Resultado final — 02/11/2026

- flutter analyze: sin observaciones.
- Suite móvil completa, habilitando las dos pruebas Laravel reales: 90 pruebas aprobadas, ninguna omitida ni fallida. Registro en build/adjuntos-pruebas.log (ignorado).
- JPEG enviado desde el servicio Flutter: persistencia en PostgreSQL, archivo cifrado, descarga idéntica byte a byte y control de roles comprobados.
- APK debug compilado para API_BASE_URL=http://192.168.1.72:8000. No se instaló ni ejecutó en emulador o teléfono durante esta integración.
- Backend local responde HTTP 200 en loopback y Wi-Fi. La prueba física del usuario sigue pendiente.
- Se añadió el panel web de adjuntos. Sin nuevos commits, push, aprobación ni merge de PR en GitHub.


## Comprobación conjunta del panel web

- Móvil: 90 pruebas aprobadas nuevamente, con las dos pruebas Laravel reales activadas y el backend de la misma carpeta web/.
- Backend completo: 53 pruebas y 303 aserciones aprobadas en PostgreSQL aislado; concurrencia: 1 prueba y 13 aserciones aprobadas.
- Compilación Vite y Pint correctos.
- Navegador: sesión web real, selección de JPEG y formulario multipart con CSRF; mensaje de guardado correcto, archivo listado después de recargar y disposición revisada a 390 px sin desbordamiento horizontal.
- Cuentas, documentos y archivos de esa revisión utilizaron correspondencia_test y una carpeta temporal; se retiraron al terminar. La bandeja habitual no recibió registros de ejemplo.
- Continúa pendiente la ejecución del recorrido completo por el usuario en su teléfono y la revisión cruzada antes de publicar.


### Foto opcional al registrar

En Nueva correspondencia, Adjuntar foto permite tomar y revisar una imagen antes de guardar. Quitar foto permite continuar sin adjunto. La cámara solo solicita permiso al abrirla.

Registrar correspondencia conserva el registro idempotente existente; con su identificador confirmado se sube la foto. Si falla el archivo, la guía permanece visible y la recuperación del adjunto no crea otra correspondencia. Si la respuesta se pierde, Comprobar subida verifica el archivo antes de reenviarlo. El registro sin foto conserva su funcionamiento.
