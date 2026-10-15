# P04 — Consulta móvil de envío por número de guía

Issue: [#9 — Implementar consulta de envío por número de guía](https://github.com/elingeyesdev/t4-manejo-correspondencia/issues/9).
Responsable: RazzellRC. Etiqueta: movil. Milestone: Iteración 02, la misma entrega P04 del registro web #7.
Rama: feature/9-movil-consulta-guia, preparada desde develop actualizado (5daeed2).

## Alcance real

Como destinatario quiero consultar un envío con el número de guía para saber en qué estado está.

La interfaz, validación, carga y manejo de resultados están preparados. La consulta móvil real sigue PENDIENTE: el backend publicado por el compañero registra y lista correspondencias, pero no expone consulta por guía ni datos de estado o último movimiento.

La aplicación normal no utiliza datos de ejemplo ni presenta resultados ficticios: ante una guía válida informa que el servicio está pendiente de conexión. No se reutilizó la API del proyecto anterior.

## Ejecutar la aplicación

Requisitos: Flutter 3.47.6, Dart 3.13.5, Android SDK y un dispositivo o emulador Android funcional.

```powershell
cd C:\Users\ElniComp2023\Downloads\t4-manejo-correspondencia\movil
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter devices
flutter run -d ID_DEL_DISPOSITIVO
```

APK: build/app/outputs/flutter-apk/app-debug.apk. Si el emulador no tiene aceleración por hardware, usar un teléfono con depuración USB o habilitar la aceleración; esto no impide compilar ni ejecutar las pruebas de widgets.

## Flujo

1. Inicio muestra el acceso Consultar envío y el Drawer permite navegar entre ambas pantallas.
2. Ingresar una guía y pulsar Consultar o la búsqueda del teclado.
3. Una guía vacía o con espacios muestra Ingrese el número de guía y no llama al servicio.
4. Durante la consulta se bloquean el campo y el botón y aparece Consultando...
5. Cuando se conecte la API, se mostrarán únicamente la guía, el estado y la fecha/hora del último movimiento recibidos del servicio.
6. El resultado inexistente muestra No se encontró un envío con ese número de guía.
7. Un fallo de conexión conserva la guía y permite reintentar.
8. En esta versión, la consulta informa que falta conectar el servicio. Este aviso NO significa que la guía no exista.

Cambiar la guía borra el resultado anterior para evitar confusiones. La fecha se muestra en la zona horaria local del dispositivo. Solo se eliminan espacios exteriores: no se imponen prefijos ni reglas no acordadas.

Diseño: Material 3, verde principal #8BC34A, verde oscuro #456B2F, blanco, texto oscuro y gris claro; iconos Material, sin estadísticas ni funcionalidades simuladas.

## Código

- lib/main.dart: aplicación, tema y Drawer.
- lib/config/api_config.dart: URL base centralizada mediante API_BASE_URL, sin valor predeterminado inventado.
- lib/models/envio_consulta.dart: datos necesarios por la pantalla; no es un contrato JSON confirmado.
- lib/pages/home_page.dart: Inicio.
- lib/pages/consulta_envio_page.dart: formulario, resultado y mensajes.
- lib/services/consulta_envio_service.dart: interfaz y adaptador pendiente de conectar.
- test/widget_test.dart: nueve pruebas controladas; los datos de ejemplo están solo en test/.

ConsultaEnvioService recibe la guía y devuelve EnvioConsulta, null para inexistente o un error conocido. El adaptador de producción ConsultaEnvioApi siempre lanza ConsultaNoDisponible hasta acordar la API. No hace solicitudes ni inventa un resultado. Definir API_BASE_URL por sí solo no habilita la consulta.

Dependencias: Flutter, flutter_localizations del SDK y las herramientas flutter_test/flutter_lints. No se añadió http todavía porque no existe un endpoint adecuado que consumir. No se agregaron arquitecturas ni gestores de estado innecesarios.

Android incluye android.permission.INTERNET. No se habilitó tráfico HTTP sin cifrar; si la futura API local lo requiere, se limitará esa excepción a debug. Producción debe usar HTTPS.

## API real encontrada y dependencia pendiente

Código revisado: rama remota feature/7-web-registro-correspondencia, commit da9e181, asociada al Issue #7 y PR #8 del compañero. Ese PR todavía no está fusionado en develop y no se incorporó a la rama móvil.

Tecnología: Node.js con módulos estándar. Puerto predeterminado 3000 y escucha en 127.0.0.1. Almacenamiento: data/correspondencia.json, configurable mediante DATA_DIR.

Operaciones reales:

- POST /api/correspondencia: requiere remitente, destinatario y fecha; asunto opcional; genera guia y devuelve HTTP 201.
- GET /api/correspondencia: devuelve el listado completo, del más reciente al más antiguo.

Campos reales: id, guia, remitente, destinatario, fecha, asunto y creadoEn.

No existe ruta de detalle/consulta por guía, ni campos de estado o fecha del último movimiento. No se asumió que creadoEn fuera un movimiento ni se generó un estado a partir del registro. Tampoco se usó el listado completo para presentar una consulta de seguimiento incompleta como si cumpliera la ficha.

El compañero debe exponer o acordar una consulta de un solo envío por su guia real, preferentemente GET, definiendo ruta, parámetro, respuesta, estados, fecha del último movimiento con zona horaria, inexistencia, errores y autenticación. No se eligió una ruta ficticia.

El servidor actual escucha solo en el equipo local. Antes de una prueba Android debe acordarse también el acceso desde el emulador o teléfono (enlace ADB o escucha de red controlada), sin modificar a ciegas el servidor del compañero.

## Evidencia y limitaciones

Las nueve pruebas cubren guía vacía, éxito controlado, inexistencia, conexión, doble consulta, servicio pendiente, navegación, limpieza de resultado anterior y respuesta después de cerrar la pantalla. Sus casos exitosos no son evidencia de integración real.

Se ejecutó el server.js publicado por el compañero sin cambiar su lógica, en una copia bajo build/revision y con almacenamiento de prueba aislado. Se verificaron POST 201 y GET 200 con una guía generada por ese backend. La respuesta confirmó que no incluye estado ni último movimiento. No se tocaron datos reales ni archivos de su rama.

Prueba móvil de extremo a extremo: PENDIENTE del contrato de consulta. Antes de declarar completada la historia deben conectarse el adaptador y probarse una guía real, una inexistente y el servidor inaccesible, contrastando estado y fechas con el backend.

No se han marcado criterios como completados ni movido la historia a Hecho.

## Entrega Git

Se conservaron los 33 archivos móviles locales al preparar la rama definitiva desde origin/develop. No se modificaron los tres archivos base del compañero (.gitignore, README.md y package.json), ni se integró su rama web.

Esta entrega se prepara con commits LOCALES separados por implementación, pruebas y documentación. El push lo hará el usuario manualmente cuando termine de revisar. No se crea PR ni se hace merge o aprobación en esta etapa.

Antes de una entrega funcional completa: acordar e implementar la API pendiente, repetir pruebas reales y verificaciones, revisar los archivos excluidos y solicitar revisión del compañero. Si se abre un PR mientras la API falta, debe describirse esa limitación y dejar el Issue #9 abierto; no debe prometer que la integración está terminada.
