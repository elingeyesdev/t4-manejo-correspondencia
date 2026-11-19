# Notas internas en Android — #46

Avance local de los primeros tres criterios, basado en el contrato del PR #49.
No acredita todavía el recorrido completo contra Laravel y Camunda reales.
La bandeja y el detalle ya aplican el diseño institucional verde elegido. La
[referencia compartida](../docs/diseno/referencia-institucional.md) queda para
comparar con la web del #48; esa comparación todavía está pendiente.

## Dónde entrar

En **Mi bandeja → Notas internas** aparecen **Por revisar**, **Por recibir**,
**Por atender** y **Copias**. Laravel decide qué notas son visibles para la cuenta.
Cada fila presenta asunto, CITE, origen, estado, fecha y acción disponible.
Abrir una nota consulta el detalle actualizado; leerla no la recibe ni aprueba.

- **Dar conformidad** confirma la revisión de la VÍA activa.
- **Confirmar recepción** registra la primera recepción de la nota.
- Con una hoja vinculada, se reutilizan los formularios existentes para recibir
  una derivación y registrar atención. Se consulta la versión de la hoja,
  que es distinta de la versión de la nota.
- **Ver expediente y adjuntos** abre las fotos y el historial del documento
  vinculado. Laravel vuelve a comprobar los permisos del recurso.
- **Copias** abre en modo de consulta, incluso al entrar al expediente vinculado.

## Confirmaciones y reintentos

La app solicita confirmación antes de revisar o recibir. Solo presenta éxito
cuando el servidor confirma un resultado válido. Un `202`, un fallo de red o una
respuesta ambigua conservan la clave y la versión originales en el almacenamiento
seguro del dispositivo. Se guarda antes de enviar el POST y se asocia al servidor,
la cuenta, la nota y la acción. No almacena contraseñas, tokens ni el contenido de la nota.
**Comprobar mismo intento** vuelve a enviar la misma solicitud, sin crear otra.
Mientras no se confirma, se bloquean otras acciones y se advierte antes de salir.
Al volver a abrir la nota, incluso tras cerrar completamente la app o renovar la
sesión con la misma cuenta, se recupera el intento y se consulta el estado actual.
Una conformidad se reconoce por el historial del mismo actor y una versión posterior;
la recepción, por la versión posterior y los identificadores vinculados de documento
y hoja. Si Laravel confirma que ya se aplicó, se actualiza la pantalla y se elimina
el intento. Si sigue pendiente, el reintento conserva la clave y versión originales.
Otra cuenta o servidor no puede recuperar ese intento. Los errores de almacenamiento
bloquean el envío de una acción nueva; dos pantallas no pueden sobrescribir la reserva.

Un `409` obliga a consultar la versión actual antes de confirmar una acción nueva.
Un `401`, `403` o `404` al cargar limpia la nota y su historial. Una actualización
fallida no habilita acciones sobre datos antiguos. Cambiar de bandeja descarta
respuestas tardías de la anterior; los reintentos de paginación conservan la página
que falló y no duplican filas.

## Archivos

- `lib/funciones/notas_internas/nota_interna.dart`: datos y bandejas del contrato.
- `lib/funciones/notas_internas/notas_api.dart`: consultas, recepción y conformidad.
- `lib/funciones/notas_internas/almacen_intentos_nota.dart`: persistencia protegida de intentos.
- `lib/funciones/notas_internas/bandeja_notas_page.dart`: listas y paginación.
- `lib/funciones/notas_internas/detalle_nota_page.dart`: detalle, confirmación y hoja.
- `test/notas_internas_test.dart`: pruebas del contrato y de las pantallas con HTTP simulado.
- `test/notas_reinicio_test.dart`: reinicios, 202 y respuestas perdidas para ambas acciones;
  comprobación de identidad, limpieza, almacenamiento fallido y concurrencia.

La entrega inicial aprobó 133 pruebas. La corrección del 18/11/2026 añade 12 casos
de regresión y conserva las 25 pruebas de nota interna: 37 pruebas focalizadas.
La suite completa se ejecuta con las tres integraciones de Laravel/PostgreSQL reales,
únicamente en `correspondencia_test`: sesión/registro/consulta, adjuntos y recorrido
histórico con QR/recepción/atención. Las acciones de la nueva nota interna y los
reinicios se verifican con HTTP controlado. No se presentan estas comprobaciones
como una prueba del flujo completo nuevo con teléfono y Camunda reales.

Resultado de esta revisión: **145 pruebas aprobadas**, análisis sin observaciones
y APK debug compilado. Los 12 casos nuevos se ejecutan con
`flutter test test/notas_reinicio_test.dart`; reconstruyen API y pantalla tras el
fallo, conservando únicamente el almacenamiento persistente simulado de la plataforma.

## Verificación pendiente en conjunto

Los PR #51 y #53 implementan emisión, CITE, VÍAs, Copias, primera recepción y la
relación con hoja y atención. Ambos están integrados en `develop` y esta rama
incorpora el #53. La comprobación conjunta con Android y Camunda real sigue pendiente.
La app presenta el error real del servidor: no sustituye respuestas por datos de
ejemplo. Los datos ficticios existen únicamente en las pruebas.

Tras integrar el servidor, comprobar el mismo CITE entre web y Android con cuentas
de emisor, dos VÍAs, destinatario y CC; primera recepción, derivación, atención,
fotos e historial. Repetir con pérdida de respuesta y pérdida de permiso.
Ese recorrido real corresponde también a la evidencia del #47.

Este avance no implementa Firebase, firma ni sello. Esas funciones requieren su
implementación coordinada y no quedan acreditadas por estas pruebas.

## Tareas y revisión

- **#46, Russel:** bandejas, acciones, mensajes, reintentos y diseño Android
  implementados y preparados para revisión cruzada. Falta comprobar las
  operaciones con el backend integrado por #53 y comparar el diseño con #48;
  no cerrar todavía.
- **#47, Russel:** recorrido completo, comprobaciones negativas y evidencia
  conjunta. Pendiente de la integración del servidor y la prueba con el teléfono.
- **#45, Mathew:** primera recepción, hoja de ruta, derivaciones, atención,
  respuesta y cierre de la nueva nota interna.
- **#48, Mathew:** diseño institucional web y comparación con Android. No impide
  preparar el diseño móvil con la referencia acordada.

La publicación de esta entrega solicita revisión a Mathew y relaciona el PR con
el #46. El issue permanece abierto hasta comprobar sus dependencias de integración.
