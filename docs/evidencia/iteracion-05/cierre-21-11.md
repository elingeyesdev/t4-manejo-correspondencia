# Iteración 05 — validación final del 21/11/2026

Ejecutor: Codex, en el equipo de Russel. Android físico: POCO F3
(M2012K11AG), Android 13, conectado por USB a Laravel/PostgreSQL locales y
Camunda 8.9.28 real. Base de código: `4da6559`, más los cambios del PR que
adjunta este informe. Hora de las pruebas y capturas: Bolivia.

## Resultado

Los criterios funcionales y visuales de #46/#47 se verificaron. El recorrido
completo aprobó en el teléfono; el motor confirmó una única instancia finalizada
para cada nota. Se restauró la aplicación normal al finalizar.

- **Envío directo:** nota `01a1ff99-9173-729c-a763-f012e6372234`, CITE terminado
  en `000028`; emisión web, recepción/atención Android, cierre web y consulta
  Cerrada en Android. Instancia Camunda `2251799813719795`, COMPLETED.
- **Dos VÍAs:** nota `01a1ff99-9dc9-7121-b9d6-10a26d9f74ea`, CITE terminado
  en `000029`; conformidades Android en orden, recepción y atención, derivación
  web a otra unidad, segunda recepción y atención Android, adjunto, respuesta,
  cierre web y consulta final en Android. Instancia `2251799813719807`, COMPLETED.
- **Copias:** la cuenta CC consultó la misma nota e historial sin acciones de
  conformidad, recepción o atención; la falta de permiso sobre el expediente
  vinculado no borró la nota autorizada.
- **Permisos:** peticiones reales devolvieron 401 sin sesión, 404 al intentar
  adelantar la segunda VÍA, 403 al recibir desde una cuenta CC de otra unidad
  y 422 al intentar dirigir una nota a otra institución.

Los formularios y las consultas web usaron sesiones/CSRF reales. Las pantallas
Android y su API no simularon Laravel ni Camunda. Los datos, notas e imágenes
son ficticios. El navegador de pruebas fue Edge/Playwright con un perfil nuevo,
separado del navegador personal.

## Recuperación e idempotencia

En la nota ficticia «xd» (`NI/DEMO/RECEPCION/2026/000001`), se interrumpió de
forma controlada la entrega de una respuesta HTTP 200 después de que Laravel
y Camunda confirmaron la recepción. El cliente no recibió un éxito y conservó
el intento en FlutterSecureStorage real. Al recrear la pantalla y el servicio,
consultó el estado, reconoció la recepción aplicada y limpió el intento sin
reenviar la operación. Después registró atención desde Android.

La consulta independiente a PostgreSQL confirmó una sola RECEPCION y una sola
ATENCION para esa hoja. Es una prueba de fallo controlado del transporte con
servidor/motor reales y reconstrucción de pantalla, no una caída simulada del
motor ni un resultado atribuido a un reinicio del sistema operativo.

## Comparación visual

La comparación final utiliza la misma nota `000029`, la misma cuenta CC y el
estado Cerrada en web y teléfono. Se verificaron CITE, asunto, DE/A, unidades,
fecha, estado, contenido, historial y acciones permitidas. Web usa tabla y
Android filas compactas; ambos comparten blanco, verdes #20B72C/#12682A,
bandera de Santa Cruz, jerarquía de texto, bordes y estados.

La comparación detectó que el borde superior de AppBar quedaba bajo la barra
de estado Android. Se pintó el filete dentro del área segura y se repitieron
las capturas reales y las pruebas de interfaz. El filete quedó visible.

- [Bandeja web](cierre-21-11/comparacion_bandeja_web.png).
- [Bandeja Android](cierre-21-11/comparacion_bandeja_android.png).
- [Detalle web](cierre-21-11/comparacion_detalle_web.png).
- [Detalle Android](cierre-21-11/comparacion_detalle_android.png).

Son capturas de la aplicación ejecutándose, no bocetos ni imágenes generadas.
También se abrió y verificó la decodificación de un adjunto ficticio en el
teléfono y se comprobó el recurso QR protegido durante el recorrido.

## Evidencia y comprobaciones

- [Recorrido Android y recuperación](cierre-21-11/resultado-android.json).
- [Mismo CITE/documento/hoja/estado en API y web](cierre-21-11/comparacion-final-web-api.json).
- [Estados, historial y número de recepciones](cierre-21-11/estado-final-db.json).
- [Instancias reales finalizadas, sin duplicados](cierre-21-11/camunda-final.json).
- [Rechazos reales por permisos](cierre-21-11/permisos.json).
- [Comparación web](cierre-21-11/comparacion-web.json) y
  [comparación Android](cierre-21-11/comparacion-android.json).

La hoja del caso con dos VÍAs conservó los siete movimientos esperados:
RECEPCION, ATENCION, DERIVACION, RECEPCION, ATENCION, RESPUESTA y CIERRE.
Las dos recepciones corresponden a unidades sucesivas; la recuperación de «xd»
conservó una sola recepción.

Validación local: **157 pruebas Flutter**, **104 pruebas Laravel con 852
aserciones**, análisis Dart, formato y Pint aprobados. Los casos optativos que
requieren su propio entorno se ejecutaron mediante los targets reales de
integración; no se cuentan como ejecutados por el simple resultado de la suite.
Tras el ajuste visual se repitieron siete pruebas de interfaz y la captura en
el teléfono. Las contraseñas, tokens y APK de integración permanecen fuera de Git.

## Reproducción

Ver [los targets de integración](../../../movil/integration_test/README.md).
`cierre_iteracion5_local_test.dart` combina la recuperación de la nota local
con los casos directo y dos VÍAs. `comparacion_institucional_real_test.dart`
captura la nota cerrada en Copias con las mismas credenciales ficticias.
Los archivos de parámetros privados se suministran mediante
`--dart-define-from-file`; al finalizar se compila e instala `lib/main.dart`
sin esas constantes.
