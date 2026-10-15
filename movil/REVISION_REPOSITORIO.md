# Revisión y cierre funcional P04 móvil

Repositorio: elingeyesdev/t4-manejo-correspondencia. Rama: feature/9-movil-consulta-guia. Issue #9, responsable RazzellRC, movil, Iteración 02.

## Base y colaboración

El repositorio estaba vacío al iniciar la preparación móvil. Después se publicó develop (5daeed2) y la rama feature/7-web-registro-correspondencia (da9e181), con registro web y PR #8. La rama móvil partió de develop conservando sus 33 archivos, verificados con SHA-256.

El PR #10 inicial era un borrador porque todavía faltaban consulta por guía, estado y fecha del último movimiento. La primera revisión identificó correctamente ese bloqueo, pero la tarea de la ficha no estaba completa.

## Autorización y cambio final

El usuario autorizó completar el soporte mínimo del backend y la app para cumplir la ficha, probar de verdad y publicar únicamente después de verificarlo.

Se recuperaron server.js, public/index.html, INICIAR.cmd y las pruebas originales de la rama del compañero, sin fusionar ni aprobar su PR. El formulario conserva su comportamiento. Se extendió el servidor con consulta individual y persistencia del estado inicial y su fecha real al registrar. No se tocaron datos reales; todas las pruebas usaron almacenamiento aislado.

Consulta: GET /api/correspondencia/guia/{guia}. Puerto 3000; host local por defecto. Guía inexistente: 404; inválida/vacía: 400; registro anterior sin seguimiento: 409. La respuesta correcta incluye guia, estado y fechaUltimoMovimiento guardados.

## Cumplimiento de la ficha

- Campo de guía obligatorio, sin solicitud vacía.
- Consulta real desde Flutter mediante HTTP, sin datos simulados.
- Estado actual y fecha del último movimiento del backend visibles.
- Aviso de guía inexistente.
- Mensaje de conexión, sin JSON ni stack traces al usuario.
- Carga y bloqueo de doble consulta.
- Material 3 e interfaz institucional conservados.

El único movimiento de esta entrega es el registro inicial. El servidor lo persiste como Registrado con la hora UTC del registro. No se simulan entregas, derivaciones ni atención. Los registros anteriores sin esos datos conservan su contenido y muestran una advertencia.

## Pruebas realizadas

Node: 15 pruebas aprobadas, incluyendo las originales del compañero y consulta, persistencia y registros antiguos.

Flutter: pruebas de interfaz y servicio HTTP, más una prueba conjunta que arranca Node, registra un dato ficticio, consulta con el servicio real, compara con el JSON y verifica la pantalla. También prueba inexistencia, servidor apagado y doble consulta.

Android: APK normal instalado en Medium_Phone, emulator-5554. Se comprobó la guía COR-2026-000001 con estado Registrado y fecha 2026-10-15T21:30:54.727Z, comparada con el JSON aislado. El emulador está en GMT y muestra 15/10/2026 21:30, el mismo instante. Se comprobaron además campo vacío, inexistencia y error al apagar el backend. Capturas auténticas en docs/evidencia/.

La prueba Android por integration_test SDK se descartó por un fallo de descarga/certificados de Java de su dependencia; no se desactivó TLS ni se cambió la seguridad del equipo. La verificación en Android se realizó instalando el APK normal y operándolo mediante ADB. Ese paquete adicional no forma parte de las dependencias finales.

Project: la credencial continúa sin permiso read:project; no se creó otro tablero ni se movieron tarjetas. El Issue #9 permanece abierto para revisión; no se fusiona ni aprueba el propio PR.

## Resultado final

- node --test: 15 pruebas aprobadas.
- flutter pub get: correcto.
- flutter analyze: sin observaciones.
- flutter test: 20 pruebas aprobadas, incluida la prueba conjunta con HTTP real.
- APK debug normal instalado y probado en Android Emulator; evidencia visible en docs/evidencia/.
- Flujo real verificado: Flutter → HTTP → Node → búsqueda por guía → respuesta del JSON → pantalla.
- Publicación autorizada por el usuario únicamente después de cumplir y verificar la funcionalidad; se actualiza el PR existente para revisión, sin aprobarlo ni fusionarlo.
