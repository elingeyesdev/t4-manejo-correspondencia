# Android · Seguimiento y constancias de Nota Interna (#63)

Contrato de integración del 23/11/2026, sobre `develop` con los PR #69, #71 y #72.

## Seguimiento

El detalle autorizado se consulta cada tres segundos mientras la pantalla está
visible y la aplicación está en primer plano. Se pausa durante firmas,
operaciones, respuestas inciertas y uso de otras pantallas. Al perder conexión,
conserva el último estado confirmado; al perder permiso, retira el contenido.

`GET /api/notas-internas/{id}` entrega `seguimiento`, con `etapa`, `etiqueta` y
`unidad: {id, nombre}`. Las etapas son preparación, revisión VÍA, recepción,
atención y cierre. El sobre y la unidad corresponden al estado confirmado por
Laravel y Camunda; no se inventan pasos completados.

## Sello real de #58

El detalle y la respuesta de primera recepción incluyen `sello_recepcion`, nulo
hasta confirmar la recepción. Se consumen los campos reales de #72:

```json
{"id":"IDENTIFICADOR_INTERNO","cite":"CITE_DE_PRUEBA","unidad":"Unidad receptora",
 "funcionario":"Receptor ficticio","fecha_hora":"2026-11-23T15:00:00Z"}
```

Flutter muestra **RECIBIDO · DEMOSTRACIÓN**, receptor, unidad y fecha y hora de
Bolivia. No muestra el identificador interno ni crea una constancia si falta.
Un reintento conserva el sello del servidor. Este sello acredita la primera
recepción; no representa una nueva constancia por cada derivación posterior.

## Constancias de firma y QR

Este cambio añade al detalle autorizado `constancias` con `tipo: firma`,
`accion`, `version`, `actor: {nombre}`, `unidad: {nombre}` y `fecha` ISO 8601.
Se devuelve la firma del remitente de la versión vigente o emitida y las firmas
VÍA cuya conformidad fue confirmada. Una firma VÍA pendiente de Camunda no se
presenta como conformidad registrada. No se entregan trazos cifrados, claves de
reintento ni identificadores de constancias.

La API de documento/hoja añade `nota_id` solo si la cuenta puede consultar esa
nota. Al resolver un QR, Android abre la nota vinculada y comprueba otra vez su
permiso. Para documentos sin nota autorizada, mantiene la consulta del expediente.
No se amplían permisos para mostrar un QR o un sello.

## Interfaz y entrega

El contenido y las constancias tienen prioridad en el detalle y la vista previa.
Se ocultan códigos DOC/COR, UUID, claves de Camunda y versiones técnicas. El CITE
se conserva como referencia documental. Al cerrar el trámite aparece
**Trámite finalizado**, con **Volver al inicio**, sin cerrar la sesión.

Las notificaciones de #64 ya están integradas en #71. Su configuración y evidencia
están en [notificaciones Android](notificaciones-android.md).

La prueba física de #63 confirmó recepción, derivación y cierre automáticamente,
con latencias entre 1193 y 1669 ms y sello real. Las mediciones se registran en
[la evidencia](../evidencia/iteracion-06/seguimiento-sello-23-11/README.md).
#65 corresponde a repetir el recorrido sin USB contra el servidor Ubuntu
publicado por Mathew y entregar el manual. Esa validación es independiente del
ensayo local Wi-Fi y sigue pendiente.