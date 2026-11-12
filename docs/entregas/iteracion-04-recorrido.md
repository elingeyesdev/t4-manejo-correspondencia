# Iteración 04 — Recorrido web y Android (#34)

Corte: 12/11/2026. Registro preparado el 11/11/2026. Responsable: Russel; revisión cruzada: Mathew. EDT 3.3 (F) y 4.2 (N). Esto es la demostración de corte; la verificación ampliada de EDT 5.1 (G) corresponde a Iteración 05.

## Versión y trabajo relacionado

- Contrato: #29, PR #35.
- Derivación y recepción web/API: #30, PR #37.
- Atención: #31, PR #38.
- Respuesta y cierre: #32, PR #39, integrado en develop (`feb6011`).
- Cliente Android: #33, PR #40. Implementación y ajustes de revisión: PR #40, versión final `eb3532153640973bfe787a32ab534602e6649c5b`. Pendiente revisión e integración de Mathew.
- Fuentes editables de Tarea 9: [flujo web](../diseno/flujo-web-iteracion-04.md) y [flujo Android](../diseno/flujo-android-iteracion-04.md). Separan actores, pantallas, botones, datos, decisiones, errores y retornos; explican las tecnologías utilizadas. El PDF previo del 04/11 no se modifica.

## Resultados disponibles

- Flutter analyze: sin observaciones.
- Flutter test: 108 pruebas aprobadas tras retirar las pruebas exclusivas de los bocetos contra el backend de PR #39, con integraciones HTTP/Laravel/PostgreSQL activadas y ejecución secuencial. Incluye autorización de tercera unidad, derivación Android, lectura de hoja por referencia QR sin movimiento, recepción guardada con respuesta perdida y recuperación de la misma solicitud, atención, foto y comparación de bytes.
- APK debug compilado e instalado en el teléfono. Los binarios y registros de ejecución permanecen ignorados por Git.
- Revisión del backend PR #39: 95 pruebas y 686 aserciones locales; GitHub verificó además 2 pruebas PostgreSQL y 30 aserciones, compilación y auditoría. Son comprobaciones automatizadas del backend, no una demostración de navegador y teléfono de punta a punta.
- Demostración principal registrada abajo: confirmaciones específicas de Russel para QR, recepción, atención y consulta móvil posterior al cierre, contrastadas con historial persistido y navegador para respuesta y cierre. Se documenta en texto, sin capturas.

## Recorrido principal comprobado

Referencia del expediente: `5d16d521-db3e-43a2-9d81-e1205c152f73`. Hoja `b8c4923b-19bf-46f7-a276-8e0330ffca88`. Se omiten remitente, asunto y textos libres para no publicar contenido del expediente. La confirmación verbal del usuario y las lecturas del sistema se distinguen; no se presentan como capturas.

1. Derivación web de A a B: confirmada por Russel. Historial persistido: DERIVACION, versión 2; el documento pasó a PENDIENTE_RECEPCION.
2. QR y recepción Android: Russel informó que el QR abrió ese documento y confirmó recepción. Historial persistido: una sola RECEPCION, versión 3, responsable de B y estado RECIBIDA. El QR es consulta y no tiene un movimiento de escritura.
3. Atención Android: Russel informó que guardó una observación y apareció EN_ATENCION. Historial leído: una ATENCION en versión 4. Se conserva actor y texto en la base; no se copia aquí el texto libre.
4. Respuesta web: Russel informó que la vinculó. Se verificó una respuesta con ID `e57b5ceb-d42e-4444-a01c-6a17aa310153`, enlazada desde el original, y movimiento RESPUESTA en versión 5. El estado permaneció EN_ATENCION, como establece el contrato.
5. Cierre web: Russel informó que lo confirmó. La lectura de Laravel y del navegador mostró CERRADA en versión 6, un solo CIERRE y el vínculo a la respuesta. Se comprobó en el navegador la confirmación permanente Expediente cerrado y la ausencia de formularios de recorrido.
6. Consulta posterior: Russel confirmó expresamente que al actualizar ese documento en el teléfono aparece Cerrada y puede abrir su foto. En web se observaron el historial completo y un adjunto todavía consultable. Esto acredita la consulta del archivo existente; no se afirma haber observado una nueva captura física durante esta sesión.

Secuencia persistida comprobada: REGISTRO → DERIVACION → RECEPCION → ATENCION → RESPUESTA → CIERRE. Estado final CERRADA, versión 6, una respuesta y un cierre. No se ejecutó un segundo cierre para generar esta evidencia.

Versión final publicada: PR #40, `eb3532153640973bfe787a32ab534602e6649c5b`; móvil `2f9f6bf`, avisos web `eb35321`. Pruebas de permisos, idempotencia y recuperación de respuesta perdida: test/recorrido_real_test.dart del PR #40. Cámara QR denegada: prueba de widgets simulada, no permiso físico observado. Confirmaciones de atención, respuesta y cierre web: 17 pruebas y 236 aserciones; suite web completa posterior: 95 pruebas y 691 aserciones. No equivale a ejecutar esas denegaciones manualmente en el teléfono.

## Pendientes que Mathew debe contrastar

- Revisión e integración del #33 y nueva comprobación contra esa versión integrada.
- Registrar por escenario la captura nueva y permisos de cámara/QR físicos, incluido el rechazo. La afirmación general anterior del usuario no se convierte en resultados individuales no observados.
- Entradas alternativas de derivación Android/recepción web y unidad C: cubiertas parcialmente por pruebas automáticas, pero no registradas aquí como demostración manual entre navegador y teléfono.
- Revisión de resultados y ambos diagramas por Mathew. La aceptación docente no se presume.

El recorrido principal ya no está pendiente de documentar. Los casos adicionales conservan su condición real y el #34 no se cierra automáticamente con este PR.

## Reproducir las pruebas automáticas

Desde movil: `flutter analyze`, `flutter test --concurrency=1` y `flutter build apk --debug`. Las integraciones reales requieren `LARAVEL_TEST_PHP`, `LARAVEL_ADJUNTOS_BACKEND`, PostgreSQL local y la base aislada `correspondencia_test`, como describe `movil/RECORRIDO_MOVIL.md` del PR #40. Sin esas variables se omiten las integraciones; no interpretar esa ejecución como equivalente a las 108 pruebas con API real. No copiar ni publicar archivos de entorno.

La Tarea 10 de infraestructura Linux es otra entrega: todavía requiere su servidor, SSH, Docker Compose, Nginx, firewall y restauración. Este informe no la presenta como realizada.
