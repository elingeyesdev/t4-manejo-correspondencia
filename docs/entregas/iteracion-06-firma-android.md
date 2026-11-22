# Firma en Android · tareas #61 y #62

Implementación y validación del 22 de noviembre de 2026. Base: PR #67 de Mathew,
integrado a `develop` en `f4dee7d28bc37ceadaa4edf388b0dc118138d6be`.

## Implementado

- Bandeja **Por firmar**: consulta los borradores autorizados al servidor.
- **Firmar borrador**: muestra asunto, origen, destino, referencia, contenido y
  versión antes de capturar el trazo.
- **Firmar y dar conformidad**: reutiliza la misma pantalla para la VÍA activa.
- Captura normalizada al formato del contrato, con limpieza y rechazo de firmas
  vacías. Cancelar no envía nada. Confirmar dos veces no abre dos operaciones.
- El trazo, la versión y la clave del intento se guardan en almacenamiento seguro
  antes del POST, separados por servidor, cuenta, nota y acción.
- Reintentos por resultado pendiente, desconexión, 503 y 429 conservan los datos.
  Un borrador editado exige revisar y firmar su nueva versión.
- Una firma de remitente confirmada no necesita aumentar la versión de la nota.
  La emisión sigue realizándose desde web; Android no la ejecuta automáticamente.

## Revisión y comprobaciones

- PR #67: comprobaciones de Laravel en GitHub en verde al revisar.
- `InternalNoteFlowTest`: 6 pruebas, 194 aserciones, con motor simulado.
- Suite completa de Flutter: 174 pruebas aprobadas. Incluye pruebas
  existentes con Laravel y PostgreSQL aislado y una captura visual opcional
  omitida por no proporcionarse su referencia.
- Subconjunto de notas y firmas: 60 pruebas aprobadas, con bandejas, captura,
  permisos, versión, reintentos y recuperación.
- Analizador de Dart sobre `lib`, `test` e `integration_test`: sin observaciones.
- Regresión del táctil: los trazos verticales lentos reproducían el desplazamiento
  de la página antes del cambio. El área de firma captura el gesto desde el
  primer contacto; los dos bordes aceptan trazos y el documento sigue desplazándose
  fuera del recuadro.
- `firma_dos_vias_real_test.dart`: ejecución aprobada en el teléfono físico con
  web, Laravel, PostgreSQL y Camunda reales. Las credenciales se proporcionaron
  desde un archivo privado. La sesión normal se conservó mediante un almacén
  separado y se restauró el APK normal al terminar.
- El ensayo anterior `notas_camunda_real_test.dart` se adaptó a los botones de
  firma; la nueva ejecución específica de firma es la evidencia de este cambio.

## Recorrido comprobado en Android y web

1. Borrador creado y enviado a firma mediante los formularios HTTP de la web.
2. Remitente autenticado en Android: **Notas internas → Por firmar**, revisión
   y firma del borrador. Web habilitó **Emitir**.
3. Edición por formulario web: la emisión devolvió 422 hasta solicitar otra firma
   y firmar la nueva versión desde Android. Se emitió después desde web.
4. Segunda VÍA autenticada antes de su turno: no vio la nota y su intento API
   recibió 404. Primera VÍA firmó y dio conformidad desde Android.
5. Segunda VÍA pudo entonces abrir, firmar y dar conformidad desde Android. Web
   mostró ambas conformidades y el estado **Pendiente de recepción** con el mismo CITE.
6. Consulta independiente de Camunda: dos tareas `RevisarVia` completadas en orden,
   asignadas a usuarios distintos, y tarea `RecibirNota` activa. La base conservó
   cuatro firmas cifradas: dos versiones del remitente y una de cada VÍA.

[Resultado y capturas del mismo ensayo](../evidencia/iteracion-06/firmas-android-22-11/resultado.json).

Capturas: [remitente firmado](../evidencia/iteracion-06/firmas-android-22-11/remitente_firmado_android.png),
[primera VÍA](../evidencia/iteracion-06/firmas-android-22-11/primera_via_confirmada_android.png),
[segunda VÍA](../evidencia/iteracion-06/firmas-android-22-11/segunda_via_confirmada_android.png) y
[resultado web](../evidencia/iteracion-06/firmas-android-22-11/web_dos_vias_confirmadas.png).

El USB se usó para instalar y controlar la automatización. La API se consumió por
Wi-Fi local. La prueba corresponde al servidor Windows del equipo de desarrollo;
la validación del servidor desplegado de Mathew y la entrega final permanecen en
#60/#65. La firma capturada es evidencia del prototipo. #63/#64 cubren seguimiento,
constancias y avisos; la revisión cruzada de estas dos tareas corresponde a Mathew.
