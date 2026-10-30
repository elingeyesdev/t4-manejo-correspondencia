# Adaptación visual móvil — Sakai / PrimeVue

Corrección visual solicitada por el equipo el 28/10/2026. No se presenta como
una funcionalidad nueva del planner ni como aceptación docente. Cambios locales
en `codex/diseno-sakai-movil`, pendientes de revisión del compañero.

## Fuente y reutilización

- Demo original: https://sakai.primevue.org/
- Repositorio: https://github.com/primefaces/sakai-vue
- Revisión consultada: `ec6b6ef53ad4fa7f2861277f50f2d9e236c40372`.
- Se adaptan a Flutter la composición de tarjetas, el encabezado, la separación
  entre contenido y fondo, y los acentos de los componentes `StatsWidget.vue`
  y `NotificationsWidget.vue`. Sus originales se conservan, sin ejecutar Vue,
  en `assets/sources/sakai/`. No se incorpora el logo comercial de Sakai.
- Iconos originales PrimeIcons, revisión
  `aed1ddac1f001b0889679dca9821539bc1a69cc9`, incluidos en
  `assets/fonts/primeicons.ttf`. Fuente: https://github.com/primefaces/primeicons
- Los avisos de autoría y licencias MIT se distribuyen en `assets/licenses/` y
  se pueden consultar desde Cuenta → Acerca de la aplicación → Ver licencias.

Es una adaptación visual nativa: Sakai es Vue/PrimeVue, no una plantilla Flutter.
No se afirman componentes Vue ejecutándose en Android. Las imágenes generadas en
el chat orientaron la selección visual; no son capturas de Sakai ni evidencia de
ejecución. La adaptación fue realizada con asistencia de Codex, no se atribuye
falsamente su programación manual al estudiante. La aceptación de esta adaptación
frente a la consigna de plantillas corresponde al docente.

## Acuerdo de apariencia para web y móvil

Fondo slate 100 `#F1F5F9`, tarjetas blancas, texto slate 900 `#0F172A` y texto
secundario slate 500 `#64748B`. Esmeralda 500 `#10B981` identifica la marca;
botones y texto pequeño utilizan esmeralda 700 `#047857` para mantener contraste.
Consulta y bandeja usan azul sobre azul claro; gestión documental usa violeta;
fechas e historial usan ámbar. Los estados incluyen texto: no dependen del color.

La pantalla de Inicio usa accesos sobre tarjetas, no contadores ficticios. La
bandeja obtiene documentos del mismo servicio Laravel, conserva la paginación y
el modo de reintento corregido. Su buscador filtra solo los documentos cargados y
lo indica en pantalla; no se presenta como búsqueda global del servidor. Los
colores de los iconos dependen del tipo documental, no de estados inventados.
El detalle muestra identificadores y eventos devueltos por la API; no inventa un
responsable ni archivos adjuntos. Registro conserva validación e idempotencia.

La barra inferior permite Inicio, Bandeja, Consulta y Cuenta. El Drawer conserva
las otras opciones y los permisos; Atrás vuelve a Inicio desde una sección y pide
confirmación al salir. Cámara, QR, recepción, atención y derivación continúan
como diseños aislados. La apariencia no implementa esas operaciones.

## Archivos para explicar el cambio

- `lib/theme/sakai_theme.dart`: colores, estilos compartidos y glifos originales.
- `lib/widgets/sakai_widgets.dart`: tarjetas, iconos, estados, campos y fechas.
- `lib/pages/`: adaptación de las pantallas existentes.
- `lib/main.dart`: tema global, navegación y cuenta.
- `test/sakai_interfaz_test.dart`: navegación, espacio reducido y búsqueda local.

## Verificación

Desde `movil/`: `flutter pub get`, `flutter analyze`, `flutter test` y
`flutter build apk --debug`. La prueba real Laravel se habilita con
`LARAVEL_TEST_PHP` y una base PostgreSQL de pruebas separada. Los resultados
ejecutados de esta sesión se comunican al terminar, sin reutilizar números de
pruebas de la entrega anterior.

Capturas de revisión optativas: ejecutar
`flutter test test/sakai_interfaz_test.dart --dart-define=CAPTURAR_SAKAI=true`.
Se guardan en `build/revision/sakai/`, sin versionar. Usan datos controlados para
inspección visual, no acreditan registro contra la API real.

### Resultado ejecutado — 28/10/2026

- Flutter analyze: sin observaciones.
- Flutter test --concurrency=1: 69 pruebas aprobadas, incluida la integración real
  Laravel/PostgreSQL en correspondencia_test. La primera ejecución paralela tuvo
  un fallo de acceso al servicio de prueba; el caso aislado y la suite final
  secuencial pasaron. No se modificó la API para forzar su resultado.
- Tres pruebas específicas de interfaz aprobadas; capturas de Inicio, bandeja y
  detalle inspeccionadas con datos controlados, no generadas por IA.
- Flutter build apk --debug --no-pub: APK compilado correctamente.
- git diff --check: correcto. Sin diferencias en web/ ni lib/services/.
- build/ y .dart_tool/ siguen ignorados. No se versiona el APK.
- No había teléfono/emulador conectado al terminar; no se acredita instalación
  ni recorrido manual de esta nueva versión en Android físico.

### Navegación por gesto

Se puede deslizar entre Inicio, Bandeja, Consulta y Cuenta, en el orden de la
barra inferior. Los botones siguen disponibles. Cada sección conserva sus datos
y desplazamiento; el Drawer se abre desde el borde izquierdo. El registro se
mantiene separado para evitar abandonarlo con un gesto lateral accidental.

Comprobación posterior al gesto: 27 pruebas de interfaz, retroceso y contrato Laravel aprobadas; flutter analyze sin observaciones. Se conserva el resultado previo de 69 pruebas completas como evidencia anterior al cambio de navegación.
