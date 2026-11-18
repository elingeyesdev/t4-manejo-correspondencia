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
respuesta ambigua conservan la clave y la versión del intento en esa pantalla.
**Comprobar mismo intento** vuelve a enviar la misma solicitud, sin crear otra.
Mientras no se confirma, se bloquean otras acciones y se advierte antes de salir.
Al volver a abrir la nota dentro de la misma sesión en ejecución, se recupera el
mismo intento. El intento no se conserva si se termina el proceso de la aplicación.

Un `409` obliga a consultar la versión actual antes de confirmar una acción nueva.
Un `401`, `403` o `404` al cargar limpia la nota y su historial. Una actualización
fallida no habilita acciones sobre datos antiguos. Cambiar de bandeja descarta
respuestas tardías de la anterior; los reintentos de paginación conservan la página
que falló y no duplican filas.

## Archivos

- `lib/funciones/notas_internas/nota_interna.dart`: datos y bandejas del contrato.
- `lib/funciones/notas_internas/notas_api.dart`: consultas, recepción y conformidad.
- `lib/funciones/notas_internas/bandeja_notas_page.dart`: listas y paginación.
- `lib/funciones/notas_internas/detalle_nota_page.dart`: detalle, confirmación y hoja.
- `test/notas_internas_test.dart`: pruebas del contrato y de las pantallas con HTTP simulado.

Comprobación local del 18/11/2026: 25 pruebas nuevas y suite Flutter de 130 pruebas
aprobadas. También se ejecutaron y aprobaron por separado las tres integraciones
optativas con Laravel/PostgreSQL reales, únicamente en `correspondencia_test`:
sesión/registro/consulta, adjuntos y recorrido histórico con QR/recepción/atención.
Total: 133 pruebas aprobadas. Las acciones de la nueva nota interna se verificaron
con el contrato y HTTP controlado; su recepción real depende del #45. No se
presentan estas comprobaciones como una prueba del flujo completo nuevo en teléfono.

## Verificación pendiente en conjunto

El PR #51 implementa emisión, CITE, VÍAs y Copias. El #45 debe completar la
primera recepción y la relación con hoja y atención. Hasta integrar esas rutas,
la app presenta el error real del servidor: no sustituye respuestas por datos de
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
  operaciones con la implementación real del #45 y comparar el diseño con #48;
  no cerrar todavía.
- **#47, Russel:** recorrido completo, comprobaciones negativas y evidencia
  conjunta. Pendiente de la integración del servidor y la prueba con el teléfono.
- **#45, Mathew:** primera recepción, hoja de ruta, derivaciones, atención,
  respuesta y cierre de la nueva nota interna.
- **#48, Mathew:** diseño institucional web y comparación con Android. No impide
  preparar el diseño móvil con la referencia acordada.

La publicación de esta entrega solicita revisión a Mathew y relaciona el PR con
el #46. El issue permanece abierto hasta comprobar sus dependencias de integración.
