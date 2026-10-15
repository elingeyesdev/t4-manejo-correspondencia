# P04 móvil — Consulta de envío por número de guía

Issue #9. Como destinatario quiero consultar un envío con el número de guía para saber en qué estado está.

## Qué hace

Inicio y Drawer permiten abrir Consultar envío. Se ingresa una guía y se pulsa Consultar. Flutter realiza un GET real al backend y muestra guía, estado y fecha del último movimiento recibidos. Una guía vacía no se envía, una inexistente muestra un aviso y un fallo de conexión conserva la entrada para reintentar. Campo y botón se bloquean mientras se consulta; no hay reintentos automáticos ni envíos simultáneos.

Se conserva Material 3, verde #8BC34A y #456B2F, blanco y gris claro, con Material Icons. No hay datos simulados en la aplicación.

## Ejecutar y probar manualmente

En una terminal, desde la raíz del repositorio:

```powershell
node server.js
```

Abrir http://localhost:3000 y registrar una correspondencia ficticia desde el formulario web. Copiar la guía generada. En otra terminal:

```powershell
cd movil
flutter pub get
flutter devices
flutter run -d ID_DEL_DISPOSITIVO
```

En un Android Emulator, la URL predeterminada es http://10.0.2.2:3000. Está centralizada en lib/config/api_config.dart. Para un teléfono USB, puede utilizarse el enlace ADB sin exponer el servidor a la red:

```powershell
adb reverse tcp:3000 tcp:3000
flutter run -d ID_DEL_TELEFONO --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

Para un teléfono por red local, configurar explícitamente HOST=0.0.0.0 al iniciar Node y API_BASE_URL con la IP del PC, en la misma red local. El puerto y acceso de red deben coincidir. La app no necesita acceso directo al archivo JSON.

Pruebas manuales:

1. Consultar sin guía: mensaje obligatorio, sin solicitud.
2. Consultar la guía creada: guía, estado y fecha reales.
3. Comparar con GET /api/correspondencia/guia/{guia} y data/correspondencia.json.
4. Consultar una guía inexistente: aviso claro, sin resultado anterior.
5. Apagar Node y consultar: mensaje de conexión, guía conservada.
6. Iniciar Node y repetir: recuperación.
7. Pulsar varias veces Consultar durante el envío: una sola consulta.

## Contrato implementado

GET /api/correspondencia/guia/{guia}, puerto 3000 por defecto. La guía se envía como segmento codificado; el backend admite espacios exteriores y mayúsculas/minúsculas.

- 200: registro con id, guia, remitente, destinatario, fecha, asunto, creadoEn, estado, fechaUltimoMovimiento.
- 404 y codigo GUIA_NO_ENCONTRADA: no existe la guía.
- 400: guía obligatoria o codificación incorrecta.
- 409: registro antiguo sin estado/fecha de seguimiento. La app explica que existe, pero no tiene seguimiento.
- Otros errores, timeout, JSON ilegible y falta de conexión: mensajes legibles; no se muestra JSON ni stack trace.

El backend ahora persiste Registrado y fechaUltimoMovimiento al crear una correspondencia. Es el primer movimiento real: el registro. No se inventan estados Entregado o En tránsito. No se agregaron cambios de estado, login, OCR ni funciones ajenas a la ficha.

Los registros anteriores sin esos campos no se modifican automáticamente ni se presentan con datos inventados. La app muestra el aviso correspondiente.

Las fechas UTC del servidor se convierten a la zona horaria del Android. El emulador utilizado usa GMT; 21:30 GMT corresponde a 17:30 en Bolivia para la evidencia tomada. El instante es el mismo.

## Estructura y dependencias

- lib/main.dart: tema y navegación, con cierre del cliente HTTP al salir.
- lib/config/api_config.dart: URL y construcción de la ruta.
- lib/models/envio_consulta.dart: validación de la respuesta real.
- lib/pages/: Inicio y consulta.
- lib/services/consulta_envio_service.dart: GET HTTP, timeout y errores.
- test/widget_test.dart: comportamiento de interfaz con casos controlados.
- test/consulta_envio_api_test.dart: contrato, codificación y errores HTTP.
- test/consulta_real_test.dart: widgets + servicio de producción + sockets reales + Node + comparación con JSON persistido; incluye servidor apagado.

Se usa package:http y flutter_localizations del SDK. No se añadieron gestores de estado ni arquitecturas adicionales. Internet se permite en el manifiesto principal; usesCleartextTraffic está únicamente en src/debug/AndroidManifest.xml. Para producción se requiere HTTPS.

## Verificaciones y evidencia

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Las pruebas reales arrancan Node desde ../server.js; necesitan node disponible en PATH. No sustituyen su respuesta por datos de MockClient. Usan almacenamiento temporal aislado y lo eliminan al terminar.

Además se instaló el APK normal en Medium_Phone (Android Emulator con WHPX) y se verificaron guía vacía, guía real, estado y fecha, inexistencia y servidor apagado. Las capturas reales están en ../docs/evidencia/.

APK normal: build/app/outputs/flutter-apk/app-debug.apk, sin versionar. Los datos de prueba y los registros de diagnóstico quedan bajo build/revision, también ignorados. Las capturas incorporadas en docs/ son evidencia revisable, no un APK ni una caché.
