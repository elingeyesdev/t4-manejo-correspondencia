# Adjuntos compartidos entre web y Android

Complemento de los issues #18 y #21 sobre el backend de Xmathewbruk, commit 91860f2175353e9641074d1400c95aca40c39d26. Implementación asistida con Codex en `feature/21-movil-adjuntos`.

Estado actualizado al 03/11/2026: el backend PR #23 fue aprobado e integrado; [PR #24](https://github.com/elingeyesdev/t4-manejo-correspondencia/pull/24) se integró después, el 02/11/2026, merge `b2eec25f4af1292a27f4aec6a44dbcdb699981ae`. La revisión formal de Mathew fue posterior al merge y quedó como `COMMENTED`, sin aprobación formal previa en GitHub. #21 figura cerrado; #18 continúa abierto por la aprobación e integración de la recuperación operativa publicada en PR #27. No se acredita el cierre de toda la Iteración 03.

## Uso

En la web, abrir una correspondencia y bajar hasta Adjuntos. Recepción y administrador pueden seleccionar un PDF, JPG o PNG de hasta 10 MiB y pulsar Subir archivo. Después del guardado, el archivo aparece en la lista, con botones Ver y Descargar. Funcionario puede consultar y abrir los archivos autorizados, pero no recibe el formulario de subida.

En Android, se puede adjuntar una foto al registrar una correspondencia o abrir el mismo documento en Mi bandeja, tomar/revisar una foto y pulsar Subir foto. La imagen guardada aparece en Archivos guardados. Lo enviado desde cualquiera de los dos clientes se consulta desde el otro si utilizan la misma instancia y su cuenta tiene permiso. Cerrar las aplicaciones no elimina los adjuntos del servidor.

## Implementación

- Las rutas web de subida y lectura exigen sesión y cuenta/unidad habilitadas. Las cargas llevan CSRF.
- AttachmentWebController reutiliza la validación, autorización, cifrado y descarga de AttachmentController/StoreAttachment. No duplica un almacén ni cambia el contrato API del móvil.
- Ver utiliza contenido original con disposición inline y tipo MIME conservado; Descargar mantiene disposición attachment. Ambos conservan los controles de acceso y no publican rutas físicas.
- El panel AttachmentsPanel.vue se carga solo en el detalle del documento y conserva los componentes y colores Sakai existentes. La lista se pagina en servidor, usando adjuntos_page.
- No se descargan todas las imágenes al abrir la lista. El archivo se obtiene cuando el usuario lo solicita. La lista muestra nombre, tamaño y fecha.
- Los mensajes de pantalla son instrucciones, confirmaciones y errores de uso; no contienen notas de desarrollo ni de validación técnica.
- El formulario impide pulsaciones repetidas; usa redirección después del POST para no reenviar el archivo al actualizar la página. El campo archivo no se deshabilita al enviar, para conservarlo en el multipart.

## Evidencia técnica

Los siguientes resultados corresponden al desarrollo registrado por el autor en PR #24 y la documentación móvil; esta actualización no vuelve a ejecutarlos. La revisión posterior distingue las pruebas reproducidas por Mathew de las pruebas Flutter declaradas por el autor.

- 53 pruebas de backend y 303 aserciones aprobadas con PostgreSQL de pruebas; 1 prueba de concurrencia y 13 aserciones aprobadas.
- AttachmentWebTest comprueba API → web y web → API, igualdad del contenido original, visualización/descarga, rol funcionario, otras unidades, vínculo con documento, rechazo de archivos, fallo de almacenamiento y paginación.
- 94 pruebas móviles aprobadas con Laravel real y PostgreSQL local aislado, además del análisis limpio y APK compilado ya registrados en movil/CAMARA_DOCUMENTOS.md.
- Navegador: carga real con una cuenta y documento aislados, confirmación y persistencia al recargar; revisión de disposición a 390 px. Datos de revisión retirados al finalizar.
- npm run build y Pint correctos; recursos generados, claves y datos no se versionan.

## Revisión y pendientes — 03/11/2026

RazzellRC integró PR #24 a las 12:49:30 y Mathew registró la [revisión `COMMENTED`](https://github.com/elingeyesdev/t4-manejo-correspondencia/pull/24#pullrequestreview-5740157133) a las 12:55:53 del 02/11/2026, hora de Bolivia (UTC−4). La [aclaración de #21](https://github.com/elingeyesdev/t4-manejo-correspondencia/issues/21#issuecomment-6583168840) conserva esa secuencia; no se atribuye aprobación formal previa al merge.

Mathew reprodujo las pruebas backend con SQLite y PostgreSQL, concurrencia, compilación web y Pint. No reprodujo Flutter sobre el commit exacto por la diferencia de SDK; las 94 pruebas Flutter y el APK siguen identificados como resultados declarados por el autor. La prueba física de cámara y consulta de archivos fue reportada por RazzellRC y transmitida por Mathew; la prueba automatizada nativa de cámara no fue ejecutada.

Sigue abierto el [hilo P2](https://github.com/elingeyesdev/t4-manejo-correspondencia/pull/24#discussion_r4445201593) para parametrizar la conexión PostgreSQL de la prueba móvil real y poder reproducirla en otro equipo. El seguimiento se registra en [#28](https://github.com/elingeyesdev/t4-manejo-correspondencia/issues/28), asignado a RazzellRC y pendiente de corrección y revisión cruzada. No transforma la revisión posterior en aprobación previa.

QR #19 e historial #20 se completaron posteriormente mediante PR #25 y PR #26, con sus propias aprobaciones. #18 / PR #27 conserva la revisión de recuperación pendiente; el milestone no se declara completo.

