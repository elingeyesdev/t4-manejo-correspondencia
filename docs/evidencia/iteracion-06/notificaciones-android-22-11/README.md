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
