# Contrato del recorrido documental web y Android

**Alcance funcional aprobado · Revisión técnica pendiente · [Issue #29](https://github.com/elingeyesdev/t4-manejo-correspondencia/issues/29) · Iteración 04**
Mathew prepara el contrato. Russel revisa su compatibilidad con Android. Trazabilidad en EDT 3.3 (F) y 4.2 (N), CU-05/06/07/09/10 y HU-08 a HU-11 y HU-13/14.

## Validación funcional del 9 de noviembre de 2026

Mathew confirmó que el docente aprobó los cinco puntos tal como se plantearon. El acuerdo cubre el alcance funcional de la Iteración 04.

1. **Derivación y recepción (#30 y #33).** Se deriva a una unidad habilitada con motivo obligatorio. El primer funcionario habilitado de destino que confirma la recepción pasa a ser responsable. El responsable de origen conserva su función mientras se espera. Durante la espera se bloquean otra derivación y la atención.
2. **Consulta y QR (#30 y #33).** La unidad de registro conserva acceso de consulta. El funcionario habilitado de destino puede abrir la hoja mientras está pendiente y quien confirma conserva el acceso como responsable. Las unidades ajenas quedan fuera del expediente salvo que tengan permiso. Escanear el QR permite abrir la hoja bajo esas reglas. Recibir requiere una confirmación explícita.
3. **Atención y adjuntos (#31 y #33).** El responsable activo registra una observación obligatoria tras recibir. Puede adjuntar una foto cuando el trámite lo requiera. El historial conserva el autor y la fecha de cada observación.
4. **Respuesta, cierre y archivo (#32).** La respuesta se registra desde web como documento con ID propio vinculado al original cuando el trámite la requiere. Si el trámite no requiere respuesta, se puede cerrar sin una. El responsable cierra con motivo obligatorio y sin recepción pendiente. Se conserva la consulta autorizada del expediente y se bloquean nuevos cambios de recorrido.
5. **Demostración del corte (#34).** Mostrar un expediente derivado en web, recibido y atendido en Android, respondido cuando corresponda y cerrado en web. Verificar historial, rechazo de acceso a una unidad ajena y una sola recepción ante un reintento. La búsqueda y el reporte básico se entregan en la Iteración 05.

## Qué reutilizamos

Laravel ya ofrece registro, bandeja, detalle, consulta por guía, lectura de QR, historial y adjuntos. La visibilidad actual de usuarios no administradores se basa en la unidad donde se registró el documento. El documento y su hoja tienen UUID distintos. La hoja ya guarda el responsable, la unidad pendiente y la versión. Este contrato define la ampliación de las reglas para mover el expediente entre unidades y conserva las rutas de consulta existentes. [API en develop](https://github.com/elingeyesdev/t4-manejo-correspondencia/blob/develop/web/routes/api.php) · [Regla de visibilidad](https://github.com/elingeyesdev/t4-manejo-correspondencia/blob/develop/web/app/Models/Document.php)

La **unidad de registro** identifica dónde ingresó el documento. La **unidad vigente** empieza ahí y cambia al confirmar una recepción. La **unidad pendiente** indica a quién se envió una hoja que todavía espera recepción. Laravel determina estos datos y el actor a partir del expediente y de la sesión. Cada hoja tiene un solo responsable activo.

## Regla institucional para la primera versión

Cada instalación representa una institución y utiliza las unidades y los usuarios configurados para ella. Para derivar, se elige la unidad por su identificador. Los nombres de las oficinas y de las personas se usan para mostrar información en pantalla.

La hoja se deriva a una **unidad**, que queda pendiente de recepción. Puede recibirla un usuario habilitado con rol de funcionario en esa unidad. La primera confirmación válida asigna la responsabilidad a esa persona y deja constancia de su identidad y la hora del servidor. Mientras la recepción esté pendiente, la unidad y el responsable de origen conservan la responsabilidad.

El caso de prueba será una solicitud registrada en **Mesa de Partes** y derivada a **Asesoría Jurídica**. **Contabilidad** será la tercera unidad que intenta acceder sin permiso. Estos nombres son datos de ejemplo. La misma regla se puede comprobar con otras unidades configuradas en la instalación.

## Quién puede consultar y actuar

Para cualquier acceso, la cuenta y su unidad deben estar habilitadas. Un usuario puede reunir varias condiciones de la tabla, por ejemplo pertenecer a la unidad de registro y ser responsable activo. Laravel verifica la autorización sobre el expediente en cada ruta y al resolver adjuntos. [OWASP API Security](https://api-security.owasp.org/editions/2023/en/0xa1-broken-object-level-authorization/)

| Actor | Consulta | Acción |
| --- | --- | --- |
| Usuario de la unidad de registro | Conserva la consulta existente en bandeja, detalle, guía, QR, historial y adjuntos. | Puede actuar si además reúne el permiso específico de la operación. |
| Responsable activo de la hoja | Puede consultar el expediente aunque se haya registrado en otra unidad. | Deriva, atiende, vincula respuesta o cierra según el estado. Su unidad debe coincidir con la unidad vigente. |
| Usuario con rol `funcionario` de la unidad pendiente | Mientras la hoja espera recepción, puede consultarla en su bandeja, detalle, guía, QR, historial y adjuntos de ese expediente. | Puede confirmar la recepción. El primero que confirma queda como responsable activo. |
| Administrador | Conserva el alcance de consulta existente. | Para cambiar el recorrido aplica la misma regla de actor y estado. |
| Usuario de una unidad ajena, incluida una unidad intermedia que ya entregó la hoja y carece de otro permiso | La hoja se excluye de la bandeja. Una consulta directa devuelve `404`. | Sin acceso a la operación. |

La visibilidad temporal por unidad pendiente termina al recibir. El nuevo responsable conserva acceso por su asignación. La unidad de registro conserva su consulta aunque ya no tenga la responsabilidad. Leer el QR abre la hoja bajo estas reglas. **Solo el botón Confirmar recepción inicia la escritura.**

Para HU-07, la foto es opcional y se autoriza la carga al responsable activo durante `RECIBIDA` o `EN_ATENCION`, además del permiso de carga que ya tienen recepción y administración sobre expedientes accesibles. Cada descarga se autoriza de nuevo y el archivo debe pertenecer al documento solicitado. Para una hoja `CERRADA` se conserva el acceso autorizado a los archivos existentes y se bloquea la carga. La ruta de adjuntos y su contrato de recuperación de subidas inciertas siguen los acuerdos de #21. [Permiso de carga actual](https://github.com/elingeyesdev/t4-manejo-correspondencia/blob/develop/web/app/Http/Requests/StoreAttachmentRequest.php) · [Integración de adjuntos](https://github.com/elingeyesdev/t4-manejo-correspondencia/issues/21)

## Ejemplo de configuración de cuentas

Un administrador habilitado configura las unidades y asigna a cada cuenta el rol y la unidad en Administración. El sistema conserva los roles del núcleo. El rol se registra en `role`, la unidad en `unit_id` y la habilitación en `enabled`. Laravel comprueba la cuenta, su rol, su unidad y el expediente en cada operación. [Administración del núcleo](api.md#operaciones-implementadas)

| Cuenta de ejemplo | Rol y unidad | Resultado en el recorrido |
| --- | --- | --- |
| Ana | `recepcion`, Mesa de Partes (1), habilitada | Registra la carta y puede derivarla mientras sea la responsable activa. |
| Bruno | `funcionario`, Asesoría Jurídica (2), habilitado | Puede recibir cuando la hoja está pendiente para su unidad. Al confirmar pasa a ser responsable. |
| Carla | `funcionario`, Contabilidad (3), habilitada | Carece de acceso a esta hoja. |
| Diego | `funcionario`, Asesoría Jurídica (2), deshabilitado | Carece de acceso aunque pertenezca a la unidad de destino. |

## Atención y subida de foto

Laravel confirma primero la observación y su movimiento. La foto opcional se sube aparte a `POST /api/documentos/{id}/adjuntos`. Si la foto falla, la atención permanece guardada. La interfaz indica «Atención guardada. Foto pendiente» y el reintento se limita al adjunto, con la captura conservada durante el flujo. El reintento de foto no vuelve a enviar la observación ni genera otro movimiento de atención.

Ante un rechazo confirmado de la carga, se puede corregir el problema y reenviar solo la foto. Si el resultado es incierto por pérdida de conexión o de respuesta, Android debe comprobar los adjuntos del documento antes de decidir. Busca la foto por nombre, MIME y tamaño y confirma que sus bytes coinciden. Si la encuentra, recupera su ID y muestra la foto como guardada. Si el resultado sigue incierto, conserva la foto pendiente y permite volver a comprobar. La carga existente carece de una clave de idempotencia. La comprobación y el bloqueo del reenvío mientras el resultado sea incierto son criterios del #33. [Adjuntos compartidos](adjuntos-web-movil.md)

## Operaciones y transiciones

Las rutas de hoja reciben el UUID de la hoja. La ruta de respuestas recibe el UUID del documento original. La web conserva sesión y CSRF. Android utiliza el token de la API. La columna Entrada indica los campos JSON. En las escrituras también se envía la cabecera `Idempotency-Key`. El formulario web puede enviar el campo `request_key` de la misma forma que el registro existente.

| Operación y ruta del contrato | Entrada | Regla y resultado |
| --- | --- | --- |
| `GET /api/hojas/{id}/destinos` | UUID de hoja | Si el actor puede derivar, devuelve `200` y `data` con unidades habilitadas distintas de la vigente. Cada unidad contiene `id` y `nombre`. |
| `POST /api/hojas/{id}/derivaciones` | `destino_unidad_id` entero, `motivo` obligatorio, `version` entera | El responsable activo puede derivar desde `REGISTRADA`, `RECIBIDA` o `EN_ATENCION`. Confirma `201`, pasa a `PENDIENTE_RECEPCION`, conserva responsable y unidad vigente y registra el destino. Laravel verifica otra vez que el destino esté habilitado y sea distinto. |
| `POST /api/hojas/{id}/recepciones` | `version` entera | Un funcionario autorizado de la unidad pendiente puede recibir. Confirma `201`, pasa a `RECIBIDA`, asigna al actor como responsable, cambia la unidad vigente y limpia el destino pendiente. |
| `POST /api/hojas/{id}/atenciones` | `observacion` obligatoria, `version` entera | El responsable activo atiende desde `RECIBIDA` o `EN_ATENCION`. Confirma `201`, queda `EN_ATENCION` y registra un evento. Una corrección agrega otro evento. |
| `POST /api/documentos/{id}/respuestas` | `remitente`, `asunto`, `fecha` en formato `YYYY-MM-DD`, `tipo_id`, `prioridad_id`, `version` de la hoja original | Operación de web para el responsable activo desde `RECIBIDA` o `EN_ATENCION`. Laravel determina la unidad y crea la respuesta con ID propio, vínculo y evento en una transacción. Confirma `201`. Conserva el estado de la hoja e incrementa su versión. |
| `POST /api/hojas/{id}/cierre` | `motivo` obligatorio, `version` entera | Operación de web para el responsable activo desde `RECIBIDA` o `EN_ATENCION`, sin recepción pendiente. La interfaz solicita confirmación. Laravel devuelve `200` y la hoja queda `CERRADA`. |

Las versiones son enteros positivos. El `motivo` de derivación y cierre admite de 1 a 500 caracteres. La `observacion` de atención admite de 1 a 2 000 caracteres. Web, Flutter y Laravel quitan espacios, tabulaciones y saltos de línea al principio y al final, y cuentan puntos de código Unicode en el texto resultante. Un campo vacío o que excede el límite devuelve `422` con el error del campo. Se reutilizan los campos y validaciones del [registro existente](api.md) para el alta de la respuesta. El servidor genera actor, hora, movimiento y estado. Las lecturas conservan los campos vigentes. El detalle agrega `acciones_permitidas`, una lista de acciones aplicables al usuario y al estado. Usa los valores `derivar`, `recibir`, `atender`, `responder` y `cerrar`. Android presenta las tres primeras cuando correspondan. Respuesta y cierre se operan desde web. La API valida de nuevo el permiso al escribir.

Entre las operaciones del recorrido, con `PENDIENTE_RECEPCION` solo procede confirmar recepción. El responsable puede cerrar sin respuesta vinculada cuando el trámite no la requiere. Con `CERRADA`, el expediente y su historial permanecen consultables según permisos. Una solicitud posterior de cierre por el responsable autorizado devuelve el cierre existente con `200` y conserva el motivo y evento originales.

## Consulta del detalle para web y Android

`GET /api/documentos/{id}` recibe el UUID del documento. La consulta por QR usa `GET /api/hojas/{referencia}` con el UUID de la hoja y devuelve la misma forma de detalle. Laravel conserva los campos existentes de lectura y añade la unidad vigente, el nombre del responsable y las acciones calculadas para el usuario autenticado. El QR no cambia el estado.

Este es un ejemplo completo de respuesta `200` que recibe Bruno al abrir la hoja pendiente. `unidad` conserva la unidad de registro. `hoja.unidad_vigente` identifica la unidad que todavía tiene la responsabilidad y `hoja.responsable` identifica a la persona. Los campos `responsable_id` y `unidad_vigente_id` coinciden con los IDs de sus objetos. `acciones_permitidas` está en la raíz del detalle y es una lista vacía cuando el usuario solo puede consultar. Los datos son ficticios.

```json
{
  "id": "60702041-a32c-4237-a67c-d251eeb1ed31",
  "codigo": "DOC-001",
  "guia": "GUIA-001",
  "remitente": "Persona de prueba",
  "asunto": "Solicitud de revisión",
  "fecha": "2026-11-09",
  "unidad": {
    "id": 1,
    "institution_id": 1,
    "code": "MESA",
    "name": "Mesa de Partes",
    "enabled": true,
    "created_at": "2026-11-01T13:00:00.000000Z",
    "updated_at": "2026-11-01T13:00:00.000000Z"
  },
  "tipo": {
    "id": 4,
    "kind": "tipo",
    "code": "CARTA",
    "name": "Carta",
    "enabled": true,
    "created_at": "2026-11-01T13:00:00.000000Z",
    "updated_at": "2026-11-01T13:00:00.000000Z"
  },
  "prioridad": {
    "id": 6,
    "kind": "prioridad",
    "code": "NORMAL",
    "name": "Normal",
    "enabled": true,
    "created_at": "2026-11-01T13:00:00.000000Z",
    "updated_at": "2026-11-01T13:00:00.000000Z"
  },
  "estado": "PENDIENTE_RECEPCION",
  "fechaUltimoMovimiento": "2026-11-09T14:15:00.000000Z",
  "hoja": {
    "id": "b1e2b746-45b7-4b21-bf78-28d80db3ed6a",
    "codigo": "HR-001",
    "responsable_id": 12,
    "responsable": {
      "id": 12,
      "nombre": "Ana"
    },
    "unidad_vigente_id": 1,
    "unidad_vigente": {
      "id": 1,
      "nombre": "Mesa de Partes"
    },
    "destino_pendiente_id": 2,
    "version": 2
  },
  "acciones_permitidas": [
    "recibir"
  ],
  "movimientos": [
    {
      "id": "8c44dabb-3af8-4fdc-b148-e5318018d725",
      "route_sheet_id": "b1e2b746-45b7-4b21-bf78-28d80db3ed6a",
      "actor_id": 12,
      "origin_unit_id": 1,
      "destination_unit_id": 1,
      "action": "REGISTRO",
      "resulting_state": "REGISTRADA",
      "reason": null,
      "occurred_at": "2026-11-09T14:10:00.000000Z"
    },
    {
      "id": "8c44dabb-3af8-4fdc-b148-e5318018d726",
      "route_sheet_id": "b1e2b746-45b7-4b21-bf78-28d80db3ed6a",
      "actor_id": 12,
      "origin_unit_id": 1,
      "destination_unit_id": 2,
      "action": "DERIVACION",
      "resulting_state": "PENDIENTE_RECEPCION",
      "reason": "Revisión jurídica",
      "occurred_at": "2026-11-09T14:15:00.000000Z"
    }
  ]
}
```

En Android, `derivar` habilita **Derivar**, `recibir` habilita **Confirmar recepción** y `atender` habilita **Registrar atención**. Bruno solo ve **Confirmar recepción** antes de recibir. Tras confirmarla, debe refrescar el detalle. Ahora la unidad vigente es Asesoría Jurídica, el responsable es Bruno, el destino pendiente es `null` y el estado es `RECIBIDA`. El servidor vuelve a validar los permisos al guardar cualquier acción.

## Ejemplo de recepción para implementar y probar

Ana, responsable en Mesa de Partes (A), deriva a Asesoría Jurídica (B) con la versión 1. Laravel guarda `PENDIENTE_RECEPCION` y devuelve versión 2. Bruno, funcionario de B, escanea el QR y abre la hoja. Al pulsar **Confirmar recepción**, Android envía esta solicitud de ejemplo con una clave generada para esa operación.

```http
POST /api/hojas/b1e2b746-45b7-4b21-bf78-28d80db3ed6a/recepciones
Accept: application/json
Content-Type: application/json
Authorization: Bearer <token>
Idempotency-Key: 7d59fca0-33cb-40d0-bde5-e623583dc024

{"version":2}
```

Laravel devuelve `201`. Todas las escrituras del recorrido usan la misma estructura. La vinculación de respuesta añade `respuesta_id` al resultado. Este ejemplo contiene datos ficticios.

```json
{
  "documento_id": "60702041-a32c-4237-a67c-d251eeb1ed31",
  "hoja": {
    "id": "b1e2b746-45b7-4b21-bf78-28d80db3ed6a",
    "estado": "RECIBIDA",
    "version": 3,
    "responsable_id": 17,
    "unidad_vigente_id": 2,
    "destino_pendiente_id": null
  },
  "movimiento": {
    "id": "8c44dabb-3af8-4fdc-b148-e5318018d727",
    "accion": "RECEPCION",
    "actor_id": 17,
    "unidad_origen_id": 1,
    "unidad_destino_id": 2,
    "fecha": "2026-11-09T14:25:00Z"
  }
}
```

Si Android pierde la respuesta, reenvía la misma clave y el mismo cuerpo. Recibe `200` con el resultado confirmado, incluido el mismo ID de movimiento. Después refresca el detalle para ver si hubo otro cambio desde esa confirmación.

## Reintentos, conflictos y errores

- **Una confirmación efectiva.** Laravel verifica cuenta, expediente y acción. En una transacción, bloquea la hoja, verifica reintento y versión, y guarda juntos el estado, la responsabilidad, la nueva versión, el movimiento y el resultado de la solicitud. Un fallo al registrar el movimiento revierte la operación.
- **Reintento reconocido.** La clave se distingue por actor y operación. Con los mismos datos, versión y recurso, se recupera el resultado anterior si el actor conserva acceso. Se verifica este caso antes de rechazar una versión antigua o una acción que ya no corresponde al nuevo estado. Usar la misma clave con otro contenido o recurso devuelve `409`. Una intención nueva lleva una clave nueva.
- **Dos personas confirman a la vez.** La primera confirmación válida es la única que cambia la hoja y registra recepción. La segunda recibe `409` si conserva acceso o `404` si, al desaparecer la asignación pendiente, queda fuera del alcance. Laravel decide con el estado efectivo al procesar la solicitud.

| HTTP | Código propuesto | Acción de web y Android |
| --- | --- | --- |
| `401` | `SESION_REQUERIDA` | Volver a iniciar sesión. |
| `403` | `ACCION_NO_PERMITIDA` | Mostrar que la acción requiere permiso sobre ese expediente. |
| `404` | `RECURSO_NO_DISPONIBLE` | Informar que la hoja no está disponible. Usar la misma respuesta para recurso ajeno o inexistente. |
| `409` | `VERSION_DESACTUALIZADA` o `ESTADO_INCOMPATIBLE` | Recargar el detalle y mostrar la situación confirmada por Laravel. |
| `409` | `CLAVE_REUTILIZADA` | Informar el conflicto. Generar una clave nueva para una intención nueva. |
| `422` | `VALIDACION_FALLIDA` | Mostrar los campos que requieren corrección. |
| `5xx` o sin respuesta | Error de servicio o conexión | Conservar los datos ingresados. Si el resultado es incierto, reutilizar la clave al reintentar. |

En las rutas nuevas, el cuerpo de error incluye `codigo` y `message`, con `errors` por campo para validación. La interfaz decide por código y puede mostrar un mensaje legible. Los contratos de error vigentes de las rutas de consulta se conservan. [Semántica HTTP, RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html#section-15)

## Pruebas de aceptación

| Caso | Resultado que debe comprobar el equipo |
| --- | --- |
| Derivar de A a B y consultar con cuentas de A, B y C | A conserva al responsable. B ve la hoja pendiente. C carece de acceso por bandeja, detalle, guía, QR, historial y adjuntos. |
| Abrir QR con una cuenta habilitada de B | Abre el detalle. Estado, versión y cantidad de movimientos permanecen iguales. |
| Recibir desde Android y consultar desde web | La misma hoja queda `RECIBIDA`, con B como unidad vigente y un solo evento de recepción. |
| Reintentar la recepción tras perder la respuesta | Se recupera el mismo ID de movimiento y no sube la versión por segunda vez. |
| Enviar dos recepciones o dos derivaciones sobre la misma versión en PostgreSQL | Solo una operación cambia el expediente. La otra se rechaza. |
| Intentar guardar una observación vacía, atender mientras se espera recepción o simular un fallo del historial | No se modifica el recorrido y la interfaz muestra el resultado real. |
| Atender con observación válida, con y sin captura | Ambos casos registran atención. Si se adjunta una foto, queda accesible según permisos. |
| Enviar motivo de 500 y 501 caracteres y observación de 2 000 y 2 001 | Se acepta el máximo y se rechaza el exceso con `422`. Un campo compuesto solo por espacios se rechaza. |
| Guardar atención y provocar un fallo confirmado de la foto | La observación sigue guardada. Al reintentar solo la foto quedan una atención y un adjunto. |
| Guardar la foto en el servidor y perder la respuesta | La comprobación recupera el mismo adjunto. No se reenvía la foto ni se repite la atención. |
| Vincular una respuesta cuando corresponda y cerrar | El original y su respuesta se consultan por sus propios identificadores. Un trámite que no requiere respuesta puede cerrar sin adjuntarla. El cierre se registra una sola vez y bloquea cambios posteriores. |

## Preparación para la Iteración 05

La búsqueda reutilizará código, asunto, intervalo de fechas, estado y paginación bajo la misma regla de consulta. El reporte reutilizará identificadores, estado, historial autorizado y fecha de generación. La entrega y verificación ampliadas de ambos corresponden a la Iteración 05.

## Revisión para cerrar el issue

- [x] Alcance funcional aprobado por el docente el 09/11/2026, según confirmación de Mathew.
- [ ] Mathew y Russel revisan el ejemplo de A a B y contrastan el contrato técnico con los casos de prueba, incluida una tercera unidad sin acceso.
- [ ] Russel confirma que Flutter puede usar los UUID, campos, respuestas, estados y códigos de error definidos. Las correcciones se incorporan al contrato.
- [ ] Se registra la revisión de Russel en el PR hacia `develop` y se enlaza su evidencia al #29.

El [#30](https://github.com/elingeyesdev/t4-manejo-correspondencia/issues/30) implementa primero derivación y recepción. El [#33](https://github.com/elingeyesdev/t4-manejo-correspondencia/issues/33) utiliza el mismo contrato desde Flutter.
