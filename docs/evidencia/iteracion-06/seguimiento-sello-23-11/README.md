# #63 · Integración del sello y seguimiento

23/11/2026, hora de Bolivia. Base: `a165362` (`develop` con #72 integrado).

## Comprobado

- Adaptación Android al `sello_recepcion` real de #72, sin mostrar su ID interno.
- Constancias de firma desde el detalle autorizado: versión válida del remitente
  y conformidades VÍA ya confirmadas. No se publican trazos ni claves de reintento.
- El QR de una hoja añade el vínculo a la nota solo para una cuenta autorizada.
- Suite Flutter completa en serie: 206 pruebas aprobadas y cuatro pruebas
  optativas omitidas. También pasaron 59 pruebas focalizadas y el analizador. Incluyen
  actualización automática, permiso retirado, desconexión, vista previa, sello,
  QR, retorno al inicio y las regresiones de notificaciones de #71.
- 110 pruebas Laravel aprobadas; después se repitieron las nueve del flujo con
  335 aserciones para comprobar firmas antiguas, pendientes y metadatos vigentes.
- APK arm64 debug compilado, `versionCode` 2001. SHA-256:
  `3a486a7523689b0405670612d49167ebc581f063e14f91d0e28ee88f6cb26106`.

La primera ejecución concurrente falló por conexión en la prueba histórica de
Node. Ese caso pasó aislado y en la ejecución completa en serie.

## Recorrido contra el servidor real

Se creó una nota ficticia por el formulario HTTP web con sesión y CSRF. La firma
preparatoria usó trazos ficticios por la API. La emisión, primera recepción,
derivación, segunda recepción, atención y cierre se ejecutaron por formularios
HTTP web. No se presentan como interacción manual con un navegador.

Laravel/PostgreSQL y Camunda fueron reales. Después de cada transición se
comparó el seguimiento de la ruta web con el detalle API que consume Android.
El resultado final fue `cerrada`/`cierre` y Camunda `COMPLETED`. El sello apareció
renderizado en web y en la API, permaneció idéntico después de derivar y cerrar,
y repetir la primera recepción con su clave y versión originales devolvió el
mismo sello. Se conservaron cinco movimientos de hoja.

Se comprobó el recurso QR autorizado y que la hoja resuelve la misma nota.
[Resultados del servidor](resultado-servidor.json).

Los tiempos `tiempo_http_ms` miden el formulario y las lecturas HTTP de ese ensayo.
**No son la latencia de la barra en el teléfono** y no acreditan el objetivo móvil
de hasta cinco segundos. El backend utilizado fue la instalación local Wi-Fi;
esta ejecución no acredita el servidor Ubuntu final de #65.

## Antes de publicar y cerrar #63

Instalar este APK en el teléfono físico, abrir la misma nota en web y Android y
comprobar el sello real y la actualización automática de recepción, derivación y
cierre, midiendo cada cambio sin tocar Actualizar ni reabrir. El teléfono dejó de
aparecer conectado antes de instalar esta compilación. #63 permanece abierto y
este trabajo se conserva local hasta completar esa validación.