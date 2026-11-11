# Iteración 04 — Recorrido web y Android (#34)

Corte: 12/11/2026. Registro preparado el 11/11/2026. Responsable: Russel; revisión cruzada: Mathew. EDT 3.3 (F) y 4.2 (N). Esto es la demostración de corte; la verificación ampliada de EDT 5.1 (G) corresponde a Iteración 05.

## Versión y trabajo relacionado

- Contrato: #29, PR #35.
- Derivación y recepción web/API: #30, PR #37.
- Atención: #31, PR #38.
- Respuesta y cierre: #32, PR #39, integrado en develop (`feb6011`).
- Cliente Android: #33, PR #40. Implementación `6b2d650`; documentación `c88c665`. Pendiente revisión e integración de Mathew.
- Fuentes editables de Tarea 9: [flujo web](../diseno/flujo-web-iteracion-04.md) y [flujo Android](../diseno/flujo-android-iteracion-04.md). Separan actores, pantallas, botones, datos, decisiones, errores y retornos; explican las tecnologías utilizadas. El PDF previo del 04/11 no se modifica.

## Resultados disponibles

- Flutter analyze: sin observaciones.
- Flutter test: 108 pruebas aprobadas el 11/11 contra el backend de PR #39, con integraciones HTTP/Laravel/PostgreSQL activadas y ejecución secuencial. Incluye autorización de tercera unidad, derivación Android, lectura de hoja por referencia QR sin movimiento, recepción guardada con respuesta perdida y recuperación de la misma solicitud, atención, foto y comparación de bytes.
- APK debug compilado e instalado en el teléfono. Los binarios y registros de ejecución permanecen ignorados por Git.
- Revisión del backend PR #39: 95 pruebas y 686 aserciones locales; GitHub verificó además 2 pruebas PostgreSQL y 30 aserciones, compilación y auditoría. Son comprobaciones automatizadas del backend, no una demostración de navegador y teléfono de punta a punta.
- Demostración informada por Russel: derivación en web y recepción en el teléfono con resultado RECIBIDA. Posteriormente confirmó haber realizado las pruebas del teléfono, sin aportar capturas ni resultados separados de cada escenario. Se conserva esa diferencia de evidencia.

## Demostración de corte que debe registrarse antes del cierre

Usar información ficticia y tres unidades A, B y C, con cuentas habilitadas. No publicar correos privados, contraseñas, tokens ni capturas de credenciales. No reutilizar datos personales como evidencia pública.

1. A registra y deriva a B desde web. Anotar guía, responsable, versión y estado pendiente. Confirmar que A conserva la responsabilidad hasta la recepción.
2. B abre desde Android por bandeja y QR. Registrar versión y número de movimientos antes y después del QR: no cambian. Comprobar también QR inválido y permiso denegado sin recepción accidental.
3. B confirma recepción con acción explícita. Web y Android muestran RECIBIDA, el mismo responsable y un movimiento. Reintentar la misma solicitud conserva movimiento y versión.
4. B captura con permiso, revisa y sube una foto; comprobar el mismo archivo desde web. Registrar atención y comprobar observación/autor/fecha en ambos. Un fallo de foto no repite atención; una foto incierta se comprueba sin reenviar.
5. Desde web, B vincula una respuesta con ID propio y cierra con motivo y confirmación. Registrar CERRADA y el mismo historial desde Android y web. Los archivos previos siguen consultables y las acciones de recorrido ya no se ofrecen.
6. C intenta consultar ese expediente: recurso no disponible. Verificar sesión vencida, conflicto y pérdida de conexión sin presentar un falso éxito.
7. Usar otro expediente ficticio para probar las entradas alternativas: derivación desde Android y recepción desde web.
8. Registrar fecha, versión, dispositivo, referencias del expediente ficticio, resultado y evidencia de cada paso. Mathew revisa los resultados y ambos diagramas antes de integrar.

## Pendientes reales

- [ ] Registrar con evidencia el recorrido completo hasta respuesta/cierre entre navegador y teléfono y las entradas alternativas.
- [ ] Detallar los escenarios físicos de cámara/QR y sus resultados; no sustituirlos por pruebas con permisos simulados.
- [ ] Revisión cruzada e integración del #33.
- [ ] Revisión de Mathew de resultados y diagramas del #34.

Este informe no acredita la aceptación docente ni cierra el milestone. Se publica como preparación para revisión, conservando los pendientes anteriores.

## Reproducir las pruebas automáticas

Desde movil: `flutter analyze`, `flutter test --concurrency=1` y `flutter build apk --debug`. Las integraciones reales requieren `LARAVEL_TEST_PHP`, `LARAVEL_ADJUNTOS_BACKEND`, PostgreSQL local y la base aislada `correspondencia_test`, como describe `movil/RECORRIDO_MOVIL.md` del PR #40. Sin esas variables se omiten las integraciones; no interpretar esa ejecución como equivalente a las 108 pruebas con API real. No copiar ni publicar archivos de entorno.

La Tarea 10 de infraestructura Linux es otra entrega: todavía requiere su servidor, SSH, Docker Compose, Nginx, firewall y restauración. Este informe no la presenta como realizada.
