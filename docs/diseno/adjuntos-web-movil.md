# Adjuntos compartidos entre web y Android

Complemento de los issues #18 y #21 sobre el backend de Xmathewbruk, commit 91860f2175353e9641074d1400c95aca40c39d26. Implementación asistida con Codex en la rama local feature/21-movil-adjuntos. Revisión cruzada pendiente; no acredita cierre de toda la Iteración 03.

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

- 53 pruebas de backend y 303 aserciones aprobadas con PostgreSQL de pruebas; 1 prueba de concurrencia y 13 aserciones aprobadas.
- AttachmentWebTest comprueba API → web y web → API, igualdad del contenido original, visualización/descarga, rol funcionario, otras unidades, vínculo con documento, rechazo de archivos, fallo de almacenamiento y paginación.
- 94 pruebas móviles aprobadas con Laravel real y PostgreSQL local aislado, además del análisis limpio y APK compilado ya registrados en movil/CAMARA_DOCUMENTOS.md.
- Navegador: carga real con una cuenta y documento aislados, confirmación y persistencia al recargar; revisión de disposición a 390 px. Datos de revisión retirados al finalizar.
- npm run build y Pint correctos; recursos generados, claves y datos no se versionan.

## Pendientes de entrega

El usuario revisa desde Android Studio con su teléfono; no se inició ningún emulador. Mathew debe revisar estos cambios en el PR antes de la integración acordada. Los issues #19 (QR) y #20 (historial) siguen siendo entregables independientes de Mathew, con sus propios criterios; añadir adjuntos no los completa ni lleva por sí solo el milestone al 100 %.
