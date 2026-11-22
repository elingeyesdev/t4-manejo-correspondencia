# Ensayo de nota interna con servidor y motor reales

## Firma y dos autoridades VÍA · #61 y #62

`firma_dos_vias_real_test.dart` usa un borrador ficticio ya enviado a firma,
su remitente y dos cuentas VÍA distintas. Firma desde los widgets de Android,
edita por formulario web, exige volver a firmar, emite en web y completa ambas
conformidades en su turno. La segunda VÍA se comprueba también antes de su turno.

Proporcionar desde un JSON privado `API_BASE_URL`, `FIRMA22_PASSWORD`,
`FIRMA22_NOTA`, `FIRMA22_DESTINO`, `FIRMA22_VIA1_ID`, `FIRMA22_VIA2_ID`,
`FIRMA22_AUTOR`, `FIRMA22_VIA1` y `FIRMA22_VIA2`. Las tres cuentas de ensayo deben
compartir esa contraseña de prueba y pertenecer a la misma institución. El
borrador debe asignar a esas dos VÍAS, en el mismo orden, y al destino indicado.
El ensayo modifica esa nota y captura trazos ficticios; requiere Camunda real.

Ejecutar con el driver `test_driver/notas_camunda_driver.dart` y el target
`integration_test/firma_dos_vias_real_test.dart`, usando `--dart-define-from-file`
con el JSON privado. El almacén de sesión del ensayo está separado de la sesión
normal. Al terminar se debe reinstalar el APK normal, sin credenciales de prueba.

[Evidencia aprobada del 22/11](../../docs/entregas/iteracion-06-firma-android.md).

Estas pruebas son optativas: requieren Laravel con PostgreSQL de desarrollo,
Camunda con `web/resources/bpmn/nota-interna.bpmn` desplegado y Android conectado.
No ejecutarlas contra información de producción. Se crean y modifican expedientes.
La suite habitual de `flutter test` no ejecuta estos targets automáticamente.

## Preparación

Crear cuentas **ficticias** de autor, primera VÍA, segunda VÍA, receptor de destino,
CC y funcionario de una tercera unidad. Asignar permisos y unidades usando el
procedimiento normal del proyecto. La cuenta CC debe pertenecer a otra unidad
para comprobar que consultar una copia no habilita recibirla.

Desde los formularios web, emitir dos notas nuevas: una directa y otra con dos
VÍAs en orden. Ambas destinadas a la unidad del receptor y con la cuenta CC.
Guardar sus UUID y CITE. No reutilizar notas ya atendidas para repetir la prueba.

Preparar un JSON **fuera de Git**, con estas claves:

```json
{
  "API_BASE_URL": "http://10.0.2.2:8000",
  "ENSAYO_PASSWORD": "CONTRASENA_LOCAL_DE_CUENTAS_FICTICIAS",
  "ENSAYO_AUTOR": "autor@ensayo.invalid",
  "ENSAYO_VIA1": "via1@ensayo.invalid",
  "ENSAYO_VIA2": "via2@ensayo.invalid",
  "ENSAYO_RECEPTOR": "receptor@ensayo.invalid",
  "ENSAYO_COPIA": "copia@ensayo.invalid",
  "ENSAYO_TERCERO": "tercero@ensayo.invalid",
  "ENSAYO_UNIDAD_TERCERA": 123,
  "ENSAYO_DIRECTO": "UUID_DE_NOTA_DIRECTA",
  "ENSAYO_VIAS": "UUID_DE_NOTA_CON_DOS_VIAS",
  "ENSAYO_CITE_DIRECTO": "CITE_DIRECTO",
  "ENSAYO_CITE_VIAS": "CITE_DOS_VIAS"
}
```

La dirección `10.0.2.2` permite al emulador de Android Studio acceder al servidor
del equipo anfitrión. Para un teléfono, usar una dirección alcanzable desde él.
El archivo contiene credenciales de ensayo: no publicarlo ni incluirlo en capturas.

## Recorrido completo

Desde `movil`, adaptar el dispositivo y la ruta privada:

```powershell
$env:ENSAYO_EVIDENCIA_DIR = 'C:\ruta-local\evidencia-recorrido'
flutter drive -d emulator-5554 --no-pub `
  --driver=test_driver/notas_camunda_driver.dart `
  --target=integration_test/notas_camunda_real_test.dart `
  --dart-define-from-file=C:\ruta-local\ensayo-privado.json
```

El test usa los widgets reales de Android, sesiones y formularios HTTP reales de
la web, API real y Camunda real. No sustituye las respuestas del servidor.
Los formularios HTTP no se presentan como navegación manual por el navegador.
Compara CITE, nota, documento y hoja; comprueba las dos conformidades en orden,
recepción, atención, derivación, respuesta, cierre y copia de consulta.
La cuenta CC pertenece a una unidad sin acceso a la hoja: debe poder seguir
leyendo su nota e historial y ver el aviso de acceso restringido al expediente.
No se amplían permisos del servidor para hacer pasar esa comprobación.

La imagen adjuntada se genera como dato ficticio del ensayo y se descarga tanto
en web como en Android. Esto comprueba adjuntos y visor, **no captura física con
la cámara**. Descargar el QR comprueba su recurso protegido, **no su escaneo**.
Publicar únicamente capturas de una ejecución aprobada y los resultados sin secretos.

La recuperación de intentos tiene regresiones HTTP controladas en
`test/notas_reinicio_test.dart`. El ensayo del 21/11 también interrumpe la entrega
de una respuesta real, verifica el intento en almacenamiento seguro y recrea
la pantalla para conciliar con Laravel/Camunda sin repetir la recepción.

## Targets locales de cierre

- `acceso_recepcion_local_test.dart`: acceso con `ACCESO_EMAIL`, `ACCESO_PASSWORD`
  y `ACCESO_NOTA_ID`. Sólo consulta por defecto. Con `ACCESO_COMPLETAR_NOTA=true`,
  recibe y atiende esa nota ficticia e incluye la interrupción controlada.
  Usa la sesión protegida normal por solicitud del propietario; cierra la sesión
  anterior y deja la nueva guardada para restaurar el APK normal.
- `cierre_iteracion5_local_test.dart`: combina ese acceso con el recorrido completo.
  Requiere ambos grupos de parámetros privados; crea/modifica expedientes.
- `comparacion_institucional_real_test.dart`: con los parámetros `ENSAYO_*`, abre
  la nota cerrada como CC y captura bandeja/detalle, sin modificar el trámite.

El [informe del 21/11](../../docs/evidencia/iteracion-05/cierre-21-11.md) contiene
resultados del teléfono físico y de la comparación con el navegador web real.

## Finalizar

Las pruebas usan una clave separada para su sesión, pero la compilación contiene
las constantes privadas de ensayo. Al acabar, instalar la app normal desde
`lib/main.dart`, sin el JSON de ensayo. Conservar el servidor disponible para la
demostración y no entregar el APK de integración como versión de uso.
