# Notas internas en Android — #46

Recorrido funcional comprobado con Laravel, PostgreSQL y Camunda reales el
19/11/2026, basado en el contrato del PR #49.
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
cuando el servidor confirma un resultado válido. Un `202`, `429`, fallo de red o una
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

## Verificación real del 19/11/2026

Pasó el recorrido en Android Studio (Medium_Phone, API 36): emisión desde los
formularios web, envío directo, dos VÍAs en orden, recepción y atención en Android,
derivación a otra unidad, respuesta y cierre web, y actualización en Android con
el mismo CITE, documento y hoja. Copias conserva la consulta de su nota aunque no
tenga acceso al expediente vinculado; no recibe permisos para modificarlo.

El ensayo usa widgets reales de Android, formularios HTTP con sesión y CSRF, y
el motor Camunda real. No se presenta como navegación manual completa del navegador.
Las dos instancias de los casos finales terminaron una sola vez en COMPLETED.

Se corrigieron el bloqueo de atención con respuesta demorada, la consulta de CC
con hoja restringida y la zona horaria de la conexión PostgreSQL. Se agregó Cerrar
sesión al encabezado web de Nota Interna.

Validación: 151 pruebas Flutter aprobadas, 41 focalizadas de notas/reintentos,
102 pruebas Laravel (811 aserciones), análisis Flutter, formato PHP y build web.
La compatibilidad del verificador web con data-state tiene cuatro pruebas
adicionales aprobadas. No se repitió toda la suite por ese cambio del verificador.

El informe y los resultados están en
[recorrido-real-18-19-11.md](../docs/evidencia/iteracion-05/recorrido-real-18-19-11.md).
Los requisitos y el comando reproducible están en
[integration_test/README.md](integration_test/README.md).

## Pendientes separados

El template web #48 y su comparación con Android siguen pendientes. Se priorizó
la conectividad y el recorrido funcional. Los issues #46/#47 no deben marcarse
completos en sus criterios visuales antes de esa comparación.

La recuperación tras reiniciar el proceso Android real no se acredita en este
corte. Los reintentos persistentes y la secuencia 202 → 429 → misma clave tienen
regresiones HTTP controladas en test/notas_reinicio_test.dart. No confundirlas
con una prueba de caída física de conexión. La imagen del ensayo verifica sus
bytes en web y Android; no acredita cámara ni escaneo QR físicos.

Firebase, firma y sello no están implementados por esta entrega.
