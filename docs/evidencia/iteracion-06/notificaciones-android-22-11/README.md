# #64 · Notificaciones reales en Android

Prueba del 22/11/2026, hora de Bolivia, con datos ficticios, un POCO F3 físico
(Android 13), Laravel/PostgreSQL y Camunda 8.9.28 locales y Firebase Cloud
Messaging real. El servidor y el teléfono se comunicaron por Wi-Fi sin
redirección de la API mediante adb.

Se emitieron tres notas mediante el formulario web con sesión y CSRF. Las
acciones preparatorias utilizaron cuentas y trazos ficticios mediante las rutas
de la aplicación. Las transiciones consultadas existen en Camunda real.

- **Revisión VÍA:** Firebase aceptó el envío; Android mostró el aviso y el usuario
  confirmó que tocarlo abrió «Prueba aviso de revision VIA».
- **Recepción inicial:** se comprobó ausencia del proceso de la app antes del
  envío. El aviso abrió «Prueba aviso de recepcion», según confirmó el usuario.
- **Recepción por derivación:** se comprobó ausencia del proceso y pantalla en
  estado `Dozing` antes del envío. El usuario confirmó el sonido con pantalla
  apagada y la apertura de «Prueba aviso de derivacion» al tocar el aviso.

En los tres casos hubo una entrega aceptada, con un intento, y Laravel registró
la lectura tras abrir la nota. Una cuenta ajena fue rechazada al consultar cada
aviso. Las notificaciones mostraron el texto genérico «Correspondencia · Tienes
una nueva tarea» y utilizaron el canal `correspondencia`.

[Resultados estructurados](resultado.json).

La apertura y el sonido se acreditan mediante confirmación expresa del usuario;
la presencia del aviso y los registros de envío y lectura se comprobaron por
separado. No se adjunta una captura Android de esta ejecución.

La rama que contiene solo #64 pasó 29 pruebas, una integración adicional contra
Laravel/PostgreSQL reales y el analizador. La compilación
local que combina #63/#64 pasó 47 pruebas y el analizador, se compiló e instaló
conservando datos. Los módulos de notificaciones son los mismos en ambas ramas.

El USB se utilizó para instalación y diagnóstico. Esta ejecución no acredita el
sello de #58, la latencia del seguimiento de #63 ni la validación del servidor
Ubuntu final sin USB de #65.

## Regresiones de la revisión de Mathew · 23/11/2026

Se reprodujeron ambos hallazgos sobre el código de `6e35943`: el cierre no
revocaba la sesión mientras Firebase dejaba pendiente el permiso, la obtención
del token o su borrado; el segundo aviso seguía mostrando la primera nota.

Después de la corrección pasan 45 pruebas de avisos, sesión, navegación y
pantallas principales. Incluyen:

- Firebase sin responder en permiso, token, borrado y cancelación de avisos:
  se intenta revocar la sesión en Laravel y se elimina la credencial local.
- Un registro de dispositivo ya enviado: su resultado precede a la baja del
  dispositivo y esta precede a la revocación de la sesión.
- Permiso, token y borrado tardíos tras otro ingreso: no se da de baja la cuenta
  nueva; si termina un borrado tardío, se recupera su registro de notificaciones.
- Dos avisos consecutivos: la segunda nota se abre con el primer detalle todavía
  en la pila y la primera confirmación de lectura sin responder.

Estos casos se verifican mediante pruebas automatizadas con respuestas y
Firebase controlados. La evidencia física anterior corresponde a la compilación
del 22/11; no acredita una repetición de estos casos nuevos en el teléfono.

La compilación local combinada con #63 pasó además 29 pruebas de avisos,
seguimiento y navegación, y el analizador sin incidencias. El APK corregido
compiló y se instaló en el POCO F3 mediante actualización, conservando los datos
y la firma de instalación (`versionCode` 2001). SHA-256 del APK:
`42b4673bb6667ed4eafbc8fbebb5326b6026d8a36ad4278cde28d7eb737a1ae5`.
