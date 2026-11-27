# Nota interna · Contrato funcional y de API

**Issue:** #42 · **Responsable:** Xmathewbruk · **Revisión técnica:** RazzellRC

**Estado:** borrador para validación. Los nombres de operaciones y las decisiones marcadas como propuestas requieren revisión antes de fijar el contrato.

## Objetivo y alcance

La nota nace en la unidad emisora. Puede pasar por una secuencia de VÍA antes de entregarse a A. CC recibe una copia informativa. Una vez recibida, la hoja de ruta documenta las derivaciones, la atención y el cierre del expediente. El Desafío UNIVALLE (págs. 1–5 y 9) describe estas relaciones. El contrato de la iteración 4 (#29) se reutiliza para las operaciones de hoja, el historial y los errores compatibles.

Las pruebas usan personas, unidades, textos, adjuntos y CITE ficticios. Los documentos de referencia reservados y sus datos quedan fuera del repositorio, de Camunda y de las evidencias.

## Actores y permisos propuestos

| Actor | Cuándo interviene | Acción y efecto |
|---|---|---|
| DE · emisor autenticado | Borrador y emisión | Redacta y emite desde su unidad. Consulta el progreso. Laravel obtiene el actor y la unidad de la sesión. |
| VÍA 1…n · autoridad identificada | Antes de entregar a A | Revisa en el orden indicado. Solo la VÍA activa puede dar conformidad. Registrar quién actuó sobre qué versión y cuándo. La devolución con motivo queda pendiente de validación. |
| A · destinatario | Tras la emisión directa o la última VÍA | Tiene la recepción pendiente. Un funcionario autorizado de destino confirma explícitamente. Abrir, escanear un QR o descargar un archivo no registra recepción. |
| CC · destinatario informativo | Al entregar la nota a A, como propuesta inicial | Consulta la nota y los adjuntos autorizados. Su lectura no habilita acciones sobre la hoja ni condiciona la entrega. La constancia de lectura queda por confirmar. |
| Responsable activo de la hoja | Desde la recepción | Registra atención, deriva según permisos y deja instrucciones. Puede vincular una respuesta o cerrar si tiene la facultad correspondiente. |
| Unidad de destino posterior | Mientras su recepción esté pendiente | Confirma la recepción para asumir la responsabilidad. El responsable anterior conserva la custodia hasta entonces, conforme al #29. |
| Unidad ajena | Siempre | El expediente no aparece en sus vistas. Una consulta directa devuelve 404. Aplicar lo mismo a historial, archivos y QR. |

**Propuesta para revisión:** asignar un CITE correlativo por unidad emisora y gestión al emitir. Confirmar la serie institucional, el formato y el tratamiento de anulaciones. Un reintento de emisión recupera el mismo CITE y proceso, sin generar un duplicado.

## Flujo y contrato entre aplicaciones

| Tramo | Estado visible | Acciones principales |
|---|---|---|
| Redacción | Borrador | Guardar / Emitir |
| Una o más VÍA | Pendiente de revisión | Dar conformidad. El destinatario no tiene recepción pendiente todavía. |
| Entrega directa o última conformidad | Pendiente de recepción | Confirmar recepción |
| Primera recepción | Recibida | Consultar hoja de ruta, derivar o atender según facultad |
| Derivación posterior | Pendiente de recepción | Confirmar en la nueva unidad. Mostrar por separado unidad vigente y destino pendiente. |
| Atención | En atención | Registrar atención, derivar, vincular respuesta o cerrar según facultad |
| Cierre | Cerrada | Consultar el expediente y su historial autorizado |

**Nuevas operaciones propuestas para acordar con Russel**

| Operación | Ruta propuesta | Entrada |
|---|---|---|
| Crear borrador | POST /api/notas-internas | asunto, cuerpo, destinatario_unidad_id, vias_usuario_ids en orden y cc_usuario_ids |
| Editar borrador | PATCH /api/notas-internas/{id} | Campos editables y version |
| Emitir | POST /api/notas-internas/{id}/emision | version, Idempotency-Key |
| Dar conformidad VÍA | POST /api/notas-internas/{id}/conformidades | version, Idempotency-Key |
| Confirmar primera recepción | POST /api/notas-internas/{id}/recepciones | version, Idempotency-Key. Devuelve la referencia de la hoja al confirmar. |
| Consultar bandeja | `GET /api/notas-internas` | `bandeja`, `page` y `per_page`. |
| Consultar detalle | `GET /api/notas-internas/{id}` | La API verifica los permisos y devuelve el detalle actualizado. |

Después de la primera recepción, usar las rutas de hoja y las operaciones de historial, adjuntos y respuesta del #29, conforme a sus contratos. En el detalle devolver id, cite, asunto, estado, version, fecha_ultimo_movimiento, unidad_actual, destino_pendiente cuando aplique, hoja_id y acciones_permitidas. La visibilidad depende del actor autenticado. No enviar identificadores de Camunda al cliente.

Camunda determina la siguiente tarea del proceso. Laravel valida la identidad y el permiso, conserva las constancias y presenta el estado confirmado. Un reintento con la misma clave y los mismos datos recupera el resultado. Datos distintos con la misma clave o una versión desactualizada devuelven 409. Ante una respuesta perdida, conservar la clave y evitar presentar éxito hasta confirmar el resultado. El #43 debe comprobar la reconciliación contra el motor real.

### Bandejas Android · propuesta para revisión

`GET /api/notas-internas?bandeja=por_recibir&page=1&per_page=15` usa el usuario autenticado. Laravel filtra por sus permisos. La página empieza en 1, el tamaño admite de 1 a 50 y toma 15 por defecto. Ordenar por último movimiento descendente y por ID como desempate. Parámetros inválidos devuelven `422`.

| Bandeja | Registros |
|---|---|
| `por_revisar` | Notas pendientes para la VÍA activa del usuario. |
| `por_recibir` | Primera recepción o recepción de una derivación pendiente para la unidad de destino, según permisos. |
| `por_atender` | Notas recibidas o en atención asignadas al responsable que puede actuar. |
| `copias` | Notas visibles como copia según la regla de CC. El momento exacto de visibilidad queda pendiente. |

Ejemplo de respuesta `200` con datos ficticios. Si la bandeja está vacía, se devuelve `data: []` con la misma estructura de paginación.

```json
{
  "data": [
    {
      "id": "30000000-0000-4000-8000-000000000001",
      "cite": "DEMO-ALFA-001",
      "asunto": "Solicitud ficticia de inventario",
      "unidad_origen": {"id": 1, "nombre": "Unidad Alfa"},
      "unidad_actual": {"id": 1, "nombre": "Unidad Alfa"},
      "destino_pendiente": {"id": 2, "nombre": "Unidad Beta"},
      "estado": "pendiente_recepcion",
      "version": 3,
      "fecha_ultimo_movimiento": "2026-11-18T16:00:00Z",
      "documento_id": null,
      "hoja_id": null,
      "acciones_permitidas": ["confirmar_primera_recepcion"]
    }
  ],
  "meta": {"current_page": 1, "per_page": 15, "total": 1, "last_page": 1}
}
```

Estados propuestos: `borrador`, `pendiente_revision`, `pendiente_recepcion`, `recibida`, `en_atencion` y `cerrada`. La lista de acciones puede incluir `dar_conformidad`, `confirmar_primera_recepcion`, `confirmar_recepcion_derivacion` o `registrar_atencion`. Puede estar vacía, por ejemplo en Copias. Android refresca bandeja y detalle al confirmar una acción. Laravel vuelve a comprobar el permiso al ejecutarla.

### Relación con fotos, historial y hoja de ruta

Para mantener los mismos campos en la tabla web y las filas Android, la adaptación
institucional local añade `unidad_destinataria: {id, nombre}` en lista y detalle.
El detalle añade `autor: {id, nombre}` para representar DE junto con
`unidad_origen`. Son campos adicionales de la misma nota autorizada: no cambian
los permisos, las acciones ni los identificadores existentes. Android permite
que falten al consultar una versión anterior del servidor; usa el destino
pendiente cuando existe y, en caso contrario, muestra «No indicada».

El `id` identifica la nota. La primera recepción devuelve `200` con el detalle actualizado, `documento_id` y `hoja_id`. Un reintento con la misma clave devuelve los mismos identificadores. Antes de la vinculación ambos son `null`. El detalle incluye los eventos previos autorizados en `movimientos_nota` con `id`, `accion`, `actor`, `fecha` y `estado_resultante`. La carga de fotos antes de la primera recepción queda pendiente de definición.

- Con `documento_id`, reutilizar `GET /api/documentos/{documento_id}/adjuntos` y `GET /api/documentos/{documento_id}/historial`. La carga usa `POST /api/documentos/{documento_id}/adjuntos` con el campo multipart `archivo` y los permisos existentes.
- Con `hoja_id`, consultar `GET /api/hojas/{hoja_id}` y usar la versión de la hoja en sus acciones. La primera recepción aparece una sola vez, como inicio de la hoja. El historial previo de la nota permanece disponible para quienes tengan permiso.
- Laravel comprueba el acceso a cada recurso por separado. El vínculo con la nota no concede permiso para ver, cargar ni descargar adjuntos.

### Firma y sello · propuesta para la demo

El detalle autenticado `GET /api/notas-internas/{id}` y la respuesta de recepción
incluyen `sello_recepcion`. Su valor es `null` hasta la primera recepción confirmada.
La constancia contiene `id` del movimiento inicial, `cite`, `unidad`, `funcionario`
y `fecha_hora` en ISO 8601. Un reintento devuelve la misma constancia. Las notas
recibidas antes de este cambio recuperan los datos a partir de su movimiento de
recepción inicial. La consulta conserva los permisos del detalle de Nota Interna.

El detalle también publica `constancias` de firma con `tipo`, `accion`, `version`,
`actor.nombre`, `unidad.nombre` y `fecha`. Solo incluye la firma del remitente
para la versión vigente/emitida y las conformidades VÍA confirmadas. No expone
trazos ni claves de reintento. La consulta autorizada de documento/hoja aporta
`nota_id` cuando esa misma cuenta puede abrir la Nota Interna vinculada.
- **Firma en pantalla.** Mostrar la acción y la versión del documento antes de firmar. Permitir borrar y volver a dibujar el trazo antes de confirmar. Laravel registra el usuario autenticado, el cargo o unidad, la acción, la versión y la hora del servidor. El trazo queda protegido y asociado a esa constancia. Una versión posterior requiere su propia constancia si la acción tiene firma habilitada.
- **Sello de recepción.** Generar una constancia visual al confirmar la recepción, con CITE, unidad receptora, fecha y hora del servidor e identificador de constancia. Mostrar **RECIBIDO · DEMOSTRACIÓN** en el detalle o PDF de prueba. La marca se genera con datos del registro confirmado y es de solo lectura. Mostrarla una sola vez si se repite la operación con la misma clave. La demo usa identidad y marca ficticias.
- **Validación institucional.** Confirmar qué acciones exigen firma, quién puede firmar o sellar, la plantilla aprobada y si el Concejo requiere firma digital certificada u otro mecanismo oficial. En el prototipo, el trazo y el sello visual se presentan como evidencia del flujo. Ver [Ley N.º 164, art. 78](https://plantilla-gob-bo.aads.upat.agetic.gob.bo/wp-content/uploads/2024/04/ley-n-164-comprimido.pdf).

#### API de firma para Android (#56, #61 y #62)

Usar el token de la sesión y `Accept: application/json`. Las respuestas exitosas a escrituras devuelven el detalle actualizado de la nota.

| Acción | Petición | Resultado |
| --- | --- | --- |
| Consultar **Por firmar** | `GET /api/notas-internas?bandeja=por_firmar` | `200` con `data` y `meta`. Incluye únicamente los borradores enviados a firma por el remitente autenticado en su unidad. |
| Abrir la vista previa | `GET /api/notas-internas/{id}` | `200` con `asunto`, `referencia`, `cuerpo`, `version`, `estado_firma` y `acciones_permitidas`. Capturar la versión del detalle que se muestra. |
| Enviar a firma | `POST /api/notas-internas/{id}/solicitud-firma` con `version` | `200`. Equivale a **Enviar a firma** en web. Repetir sobre el mismo borrador y versión conserva su estado. |
| Firmar como remitente | `POST /api/notas-internas/{id}/firmas` con `version`, `firma` e `Idempotency-Key` | `200`. Retira el borrador de **Por firmar** y habilita `emitir` en web y API. |
| Firmar y dar conformidad | `POST /api/notas-internas/{id}/conformidades` con `version`, `firma` e `Idempotency-Key` | `200` al confirmar el avance en Camunda. `202` si la conformidad sigue pendiente de confirmación. |

`estado_firma` es `sin_solicitar`, `pendiente` o `firmada` en el borrador editable. Fuera del borrador es `null`. Habilitar la captura del remitente con `firmar_borrador` y la de VÍA con `dar_conformidad`. Si se modifica la nota, hay que enviarla a firma nuevamente. Camunda inicia al emitir.

En el cuerpo JSON, `firma` contiene una lista de trazos. Cada trazo es una lista de puntos `[x, y]` de enteros entre 0 y 1000, normalizados respecto al ancho y alto del área de firma. Se permiten hasta 32 trazos y 2000 puntos en total, con al menos un segmento entre puntos distintos. `Idempotency-Key` es un UUID generado por el cliente para esa acción.

```json
{
  "version": 3,
  "firma": [[[180, 420], [310, 250], [460, 560]], [[530, 460], [720, 390]]]
}
```

Ante `202`, `503` o una respuesta perdida, reintentar con la misma clave, versión y firma. Ante `409`, recargar el detalle y pedir una firma nueva si cambió la versión. `422` indica validación, incluida la emisión sin firma vigente. `401` indica sesión inválida. `403` o `404` indica que la acción o la nota quedó fuera del alcance de la cuenta. Tras un `200`, actualizar las bandejas desde el servidor. Laravel asigna actor, unidad y hora del servidor. El trazo se guarda cifrado y queda fuera de las respuestas.

### Seguimiento del detalle web y Android

`GET /api/notas-internas/{id}` devuelve `seguimiento` en el detalle autenticado. El objeto contiene `etapa`, `etiqueta` y `unidad` con `id` y `nombre`. Las etapas son `preparacion`, `revision`, `recepcion`, `atencion` y `cierre`. En una revisión se muestra la unidad de la VÍA activa. Cuando hay una recepción pendiente, la barra señala la unidad de destino, mientras `unidad_actual` conserva la unidad que tiene la custodia. Este criterio se mantiene en cada derivación.

La web consulta su ruta de seguimiento cada dos segundos con el detalle visible. Android puede usar el detalle autenticado con el mismo intervalo y refrescar al volver a primer plano. La interfaz conserva el último estado confirmado si una consulta falla. La barra presenta el recorrido que Laravel registró tras la confirmación correspondiente.

Para verificar el objetivo de cinco segundos con datos ficticios, abrir la misma nota en web y Android. Confirmar desde otra sesión la recepción inicial, dos derivaciones con sus recepciones y el cierre. Medir desde cada confirmación hasta que aparezcan la nueva etapa y unidad en ambas pantallas. Registrar los tiempos por transición sin recargar ni cerrar el detalle.

## Notificaciones de Nota Interna

**Alcance para la entrega.** Una nota con una tarea disponible genera un aviso persistente en Laravel y un push a los dispositivos Android habilitados. Web y Android consultan el mismo historial de avisos y comparten el estado de lectura. El push de esta entrega es para Android. La web muestra el aviso y el contador al consultar la API o refrescar la vista.

### Eventos y destinatarios

Emitir el aviso cuando Laravel haya guardado la transición y confirmado el resultado de Camunda cuando corresponda. Resolver el destinatario con las mismas reglas que habilitan la acción en la bandeja.

| Evento | Quién recibe | Qué ve al abrir |
| --- | --- | --- |
| `revision_via_pendiente` | Solo la persona asignada a la VÍA activa. Con dos VÍAS, la segunda recibe el aviso tras la conformidad de la primera. | Detalle y acción de conformidad si sigue habilitada. |
| `recepcion_inicial_pendiente` | Funcionarios autorizados a recibir en la unidad A, tras un envío directo o la última conformidad por VÍA. | Detalle y acción de confirmar recepción. |
| `recepcion_derivacion_pendiente` | Funcionarios autorizados a recibir en la unidad a la que se deriva. | Detalle y acción de confirmar la recepción de la derivación. |
| `atencion_pendiente` | Responsable vigente cuando se le asigna la tarea de atención. Si la misma transición ya le generó un aviso accionable, conservar un solo aviso para esa persona. | Detalle de la nota y acceso a la hoja de ruta según permiso. |

CC conserva su bandeja de consulta. El push para CC queda pendiente de validación institucional. La emisión, recepción y cierre conservan su trazabilidad. Abrir o leer un aviso jamás ejecuta una acción del expediente.

### Mathew · Laravel y web

1. Guardar el aviso por destinatario y la orden de entrega en la misma transacción local que confirma el evento. Usar una restricción única por ID de transición y usuario. Si Camunda tiene resultado incierto, reconciliar antes de crear el aviso. Procesar el envío con un worker de Laravel después del commit. La indisponibilidad de FCM deja el aviso visible en las bandejas del sistema y el envío pendiente de reintento.
2. Registrar instalaciones y sus tokens FCM bajo la identidad y sesión autenticadas. Una cuenta puede tener varios dispositivos. Vincular cada instalación y token a una única cuenta activa, reemplazar el token al rotar y desactivar la instalación al revocar la sesión o salir. Android usa el endpoint de baja en un cierre normal de sesión. Laravel comprueba vigencia, permisos y pertenencia al destinatario antes de enviar. Eliminar o desactivar tokens que FCM reporte como `UNREGISTERED` y reintentar fallos transitorios con espera creciente y límite. Registrar resultado y hora sin exponer tokens ni contenido de la nota.
3. Enviar mediante FCM HTTP v1 con credenciales del servidor y por token de dispositivo. Las credenciales de envío se inyectan por entorno y se mantienen fuera de Git y del cliente. El texto del sistema es genérico, por ejemplo **Correspondencia · Tienes una nueva tarea**. Los datos del push se limitan a `notificacion_id` como texto. Usar ese ID como etiqueta estable del aviso en Android cuando el transporte lo permita y como clave de deduplicación en Flutter. Un reintento puede reenviar el push, pero el centro de avisos conserva una sola entrada por destinatario.
4. Mostrar en web un acceso al centro y su contador. Laravel omite avisos cuyo detalle dejó de ser visible para la cuenta. La lectura se comparte entre canales. Un aviso leído conserva su historial.

### API compartida

Todas las operaciones requieren autenticación y usan el usuario de la sesión. El cliente conserva la estructura de paginación acordada para las bandejas.

| Operación | Petición y resultado |
| --- | --- |
| Registrar o actualizar Android | `PUT /api/notificaciones/dispositivos/{instalacion_id}` con `token_fcm` y `plataforma: "android"`. `instalacion_id` es un UUID generado por la app y guardado localmente. Devuelve `204`. Repetir el mismo registro produce el mismo resultado. |
| Desvincular instalación | `DELETE /api/notificaciones/dispositivos/{instalacion_id}`. Devuelve `204` y solo afecta la vinculación de la cuenta autenticada. |
| Consultar avisos y contador | `GET /api/notificaciones?page=1&per_page=15`. Devuelve `200` con `data`, la paginación de bandejas y `no_leidas` para toda la cuenta. Cada elemento devuelve `id`, `tipo`, `nota_id`, `creada_en` y `leida_en` (`null` hasta leerse). Orden por fecha descendente e ID como desempate. |
| Resolver un push | `GET /api/notificaciones/{id}`. Devuelve `200` con el elemento autorizado o `404` si no existe o dejó de ser visible. El cliente usa `nota_id` devuelto por Laravel para consultar `GET /api/notas-internas/{id}`. |
| Marcar como leído | `PUT /api/notificaciones/{id}/lectura`. Devuelve `204` y conserva la primera hora de lectura aunque se repita. Devuelve `404` si el aviso dejó de estar disponible. |

Una sesión ausente o vencida recibe `401`. Parámetros inválidos reciben `422`. Abrir desde un push requiere resolver el aviso y cargar el detalle con la sesión vigente. Solo entonces se marca como leído. Si el aviso o la nota ya no están disponibles, mostrar «Esta notificación ya no está disponible» y volver a la bandeja. Si había una acción y otro funcionario ya la realizó, mostrar el estado actualizado y las acciones que Laravel todavía autoriza.

Antes de activar el envío del #59, configurar `FCM_PROJECT_ID` en Laravel y montar fuera del repositorio el archivo de cuenta de servicio en la ruta de `GOOGLE_APPLICATION_CREDENTIALS`, accesible por el proceso del programador. Mantener `FCM_ANDROID_CHANNEL=correspondencia` en coordinación con Android. Ejecutar `php artisan schedule:run` cada minuto, o iniciar un proceso supervisado con `php artisan schedule:work`. Para probar una ejecución desde el entorno de Laravel, usar `php artisan correspondencia:enviar-avisos`. Con `FCM_PROJECT_ID` vacío, los avisos persistentes siguen disponibles y las entregas quedan en espera.

### Russel · Flutter para Android

1. Configurar Firebase para el identificador de la app, agregar `firebase_core` y `firebase_messaging`, y crear el canal de correspondencia. Solicitar el permiso de notificaciones en Android 13 o posterior. Tras el inicio de sesión y con permiso concedido, registrar `getToken()` y actualizar el registro con `onTokenRefresh`. Desvincular al salir antes de revocar la sesión y evitar reutilizar avisos de otra cuenta al cambiar de usuario. Si se deniega el permiso, la bandeja y el centro de avisos siguen funcionando.
2. Con la app abierta, procesar `onMessage` para actualizar el centro y mostrar un solo aviso visual. En segundo plano o con el proceso terminado normalmente, Android muestra el push del sistema. Procesar la apertura con `onMessageOpenedApp` y el arranque en frío con `getInitialMessage()`. Cuando no haya sesión, pedir autenticación y resolver el aviso con la cuenta que inicie sesión. Si el usuario pulsa **Forzar detención** en Ajustes, debe volver a abrir la app antes de recibir mensajes. Cuando falte conexión o el proveedor no entregue un push, recuperar los avisos al volver a abrir o refrescar. El push complementa la bandeja persistente.
3. Refrescar los avisos al abrir o reanudar la app y tras marcar uno como leído. La pantalla bloqueada y los logs del dispositivo usan solo el texto genérico y el identificador opaco del aviso. CITE, nombres, asunto, cuerpo, fotos, firmas y sellos se obtienen en el detalle autenticado según permisos.

### Criterios de aceptación de las notificaciones

| Caso | Evidencia esperada |
| --- | --- |
| Directa y dos VÍAS | Una nota ficticia directa avisa a A. En el recorrido con dos VÍAS, se comprueba el orden VÍA 1, VÍA 2 y A. CC y una unidad ajena quedan fuera de los avisos accionables. |
| App abierta, en segundo plano y cerrada normalmente | En un Android con FCM operativo, permiso y conexión, probar un evento nuevo por estado. En primer plano se ve el aviso en la app. En segundo plano y con arranque en frío aparece el aviso del sistema. Al tocarlo se abre la nota autorizada. |
| Reintento, otro funcionario y cambio de sesión | Repetir una transición y comprobar una sola entrada por usuario. Abrir un aviso anterior tras completar la tarea con otro funcionario y comprobar que ya no ofrece esa acción. Cambiar de cuenta o retirar permisos y comprobar que se protege el detalle. |
| Permiso denegado, token rotado o inválido, desconexión | Verificar la bandeja aunque no haya push. Rotar el token y comprobar que se usa el nuevo. Simular `UNREGISTERED` y error temporal para verificar baja y reintento. Tras reconectar, sincronizar los avisos. |
| Lectura y privacidad | Abrir en Android y consultar el estado leído desde web. Capturar el aviso de pantalla bloqueada con datos ficticios y verificar que no expone datos de la nota. |

Guardar evidencia con evento, cuenta ficticia receptora, estado de la app, resultado del envío y de la apertura. Registrar por separado la aceptación del envío por FCM, la visualización en Android y la lectura del aviso. El #47 reúne la evidencia web y Android.

Referencias de implementación: [FCM en Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages), [envío HTTP v1](https://firebase.google.com/docs/cloud-messaging/send/v1-api), [gestión de tokens](https://firebase.google.com/docs/cloud-messaging/manage-tokens) y [permiso de notificaciones de Android](https://developer.android.com/develop/ui/compose/notifications/notification-permission).

## Interfaz institucional

Usar el template institucional compartido definido en #48. Las pantallas web de #44 y #45 y las pantallas Android de #46 usan la misma paleta, tipografía, espaciado, bordes, estados y nombres de acciones. Flutter adapta la disposición para pantallas pequeñas. El #47 compara ambos canales con el mismo expediente ficticio. La observación del ingeniero afecta la presentación de Sakai y las pantallas que verá el funcionario. Evaluar el resultado con una vista de bandeja y otra de detalle antes de extenderlo al resto.

- **Web:** cabecera discreta, navegación institucional sencilla y bandeja tabular. Usar columnas CITE, asunto, remitente o unidad de origen, fecha y estado. Mostrar la acción del rol en el detalle.
- **Android:** listas compactas para Por revisar, Por recibir, Por atender y Copias. Mostrar asunto, origen, fecha y estado, con un botón de acción cuando corresponda.
- **Estilo:** fondo blanco o gris claro, bordes finos, tipografía de sistema, una sola tonalidad sobria para acciones y color funcional para alertas. Usar títulos, tablas y formularios convencionales. Retirar degradados, tarjetas decorativas, iconos de adorno, indicadores de portada y animaciones que no ayuden a trabajar.
- Mantener contraste, etiquetas explícitas, foco visible y mensajes de error legibles. El aspecto administrativo puede ser austero y seguir siendo cómodo para consultar expedientes todo el día.

## Hoja institucional y constancias (#75)

Desde **Nueva Nota Interna**, elegir la unidad destinataria y revisar la hoja mientras se redacta. Después de guardar, seguir la acción indicada debajo de la vista previa. En una tarea de firma, conformidad o recepción, **Revisar firma y sello sobre la hoja** muestra los archivos elegidos como provisionales. La confirmación registra la acción. Para imprimir, abrir el PDF e imprimir desde el visor.

| Operación | Contrato para Android |
| --- | --- |
| Obtener la hoja paginada | `GET /api/notas-internas/{id}/documento.pdf?version={version}` con el token de la sesión y la versión obtenida en el detalle. Responde `application/pdf` y `X-Note-Version`. La versión es opcional al abrir el documento vigente. Si la versión solicitada cambió, responde `409`. |
| Previsualizar imágenes antes de actuar | `POST /api/notas-internas/{id}/vista-previa` en `multipart/form-data`, con `version` y `accion` (`firmar_borrador`, `dar_conformidad` o `confirmar_primera_recepcion`). Admite los campos de imagen y trazo descritos abajo. Devuelve un PDF provisional y conserva el estado del trámite. |
| Confirmar | Conservar las rutas `firmas`, `conformidades` y `recepciones`, el campo `version` y la cabecera `Idempotency-Key`. Se mantiene el cuerpo JSON para trazos. Con archivos, enviar `multipart/form-data` y, si corresponde, `firma` como arreglo de puntos codificado en JSON dentro de un campo de texto. |

`imagen_firma` e `imagen_sello` son archivos independientes. Se aceptan PNG y JPEG de hasta 512 KiB y 2000 × 2000 píxeles por archivo. La firma del remitente y la conformidad VÍA requieren el trazo o una imagen de firma. Adjuntar un sello es opcional en esos actos. Al confirmar recepción se genera la constancia **RECIBIDO** con el funcionario, la unidad, la fecha y la hora del servidor. La recepción también admite imágenes de firma y sello. Frente a una respuesta incierta, confirmar el resultado con la misma clave y la misma versión. Consultar el detalle y volver a obtener el PDF después de la confirmación.

La hoja emitida conserva el contenido y fija los nombres y unidades del encabezado al asignar el CITE. El modelo actual identifica el destino por unidad. Las notas emitidas antes de la migración conservan su contenido y recurren a los nombres disponibles en el registro. Para una autoridad VÍA, se incorporan las constancias confirmadas a medida que avanza el flujo. El acceso a la vista y al PDF usa las mismas reglas que el detalle de la nota.

### Configuración del PDF

Definir `DOCUMENT_CHROMIUM_BINARY` con la ruta absoluta al ejecutable Chromium compatible que esté instalado en el mismo entorno que Laravel. El proceso web debe poder ejecutarlo como usuario sin privilegios y escribir en `storage/app/private`. Instalar una fuente serif como Liberation Serif en el servidor. Aplicar las migraciones de #75 y reconstruir la caché de configuración si el entorno la usa.

Verificar que el ejecutable reproduce el membrete y el pie en todas las páginas y que el visor y la impresión muestran la misma distribución. Con la variable vacía, web ofrece lectura de la hoja en HTML y comunica que falta habilitar la exportación. Las rutas de PDF de Android requieren el generador configurado.

## Pruebas con datos ficticios

1. **Directa.** Unidad Alfa emite «Solicitud de inventario de prueba» a Unidad Beta sin VÍA. Beta confirma en Android. Web muestra el mismo estado y una única hoja. Repetir emisión y recepción con las claves originales. Verificar un CITE y un movimiento por acción.
2. **Con VÍA y CC.** Unidad Alfa emite «Solicitud de revisión de formulario» con dos autoridades ficticias en secuencia, A en Unidad Beta y CC en Unidad Gamma. La segunda VÍA no actúa antes de la primera. A recibe solo tras la segunda conformidad. CC consulta sin alterar el flujo. Beta deriva a Unidad Delta, que recibe, atiende y registra respuesta cuando corresponda. La autorización de cierre se comprueba según la regla acordada.
3. **Controles comunes.** Un usuario de Unidad Épsilon queda fuera del expediente y sus adjuntos. Web y Android muestran el mismo estado confirmado. Una pérdida de respuesta no produce una segunda constancia. Cada evidencia indica ejecutor, versión y resultado.

4. **Firma, sello y aviso.** Confirmar una acción ficticia con firma habilitada y verificar actor y versión. Confirmar recepción, consultar su sello y repetir la acción con la misma clave. Debe conservarse una sola constancia y un solo aviso por destinatario. Probar que un usuario sin permiso no puede abrir el detalle desde el aviso.

## Decisiones pendientes

- **Con el docente o el Concejo:** serie y momento del CITE, reglas de conformidad o devolución por VÍA, facultad de recepción por unidad, alcance y momento de CC, responsable del cierre, acciones que requieren firma, responsables y formato del sello, mecanismo aceptado para las constancias oficiales y reglas de notificación adicionales al alcance de la entrega, incluido el push para CC. La auditoría del prototipo registra actor, versión y hora del servidor. La aceptación institucional de ese mecanismo queda pendiente.
- **Con Russel:** confirmar endpoints y nombres, matriz de acciones por canal, modelo de errores, contrato de push y casos de prueba. Registrar la revisión cruzada antes de dar por acordado el contrato.
