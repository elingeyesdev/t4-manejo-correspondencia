# #64 · Avisos en Android

[Evidencia física y resultados de aceptación](../evidencia/iteracion-06/notificaciones-android-22-11/README.md).

## Configuración

Registrar en el mismo proyecto Firebase que utiliza Laravel la aplicación Android
`dev.elingeyes.correspondencia.t4_movil`. Descargar `google-services.json` y
colocarlo en `movil/android/app/`; el archivo está excluido de Git. Recompilar e
instalar la app. La credencial de envío del servidor no se incluye en Android.

Laravel utiliza `FCM_PROJECT_ID`, la credencial de envío mediante
`GOOGLE_APPLICATION_CREDENTIALS` y el canal `correspondencia`. Ejecutar su tarea
programada de envío según el contrato de Nota Interna. La API debe ser accesible
desde el teléfono y ambos dispositivos necesitan conexión a Internet para FCM.

## Comportamiento

- Solicita permiso de notificaciones y registra la instalación y el token bajo
  la sesión vigente. Actualiza el registro cuando cambia el token.
- El aviso del sistema muestra texto genérico. El push solo contiene el ID del
  aviso; Laravel resuelve la nota con los permisos de la cuenta autenticada.
- Tocar un aviso carga la nota autorizada antes de marcarlo leído. Si requiere
  acceso, espera el inicio de sesión. Cambiar de cuenta descarta la apertura
  pendiente de la cuenta anterior. Un segundo aviso puede abrir su nota aunque
  el primer detalle siga abierto o su confirmación de lectura esté pendiente.
- El centro de avisos funciona también con el permiso denegado o sin Firebase.
- Al salir invalida los registros pendientes de la cuenta. Si ya se envió un
  registro a Laravel, espera su resultado antes de dar de baja la instalación;
  cada petición HTTP conserva su límite de 20 segundos. No espera la cola de
  permisos o de obtención del token de Firebase. El borrado del token y la
  cancelación de avisos se intentan en paralelo, con un límite de espera de dos
  segundos, antes de intentar la revocación y borrar la sesión local.
- Las respuestas tardías de permisos y tokens no registran una cuenta anterior.
  Si el borrado de Firebase termina después de otro ingreso, se vuelve a
  registrar el token de la cuenta vigente.
- La prueba de app cerrada se refiere a cierre normal o proceso terminado, no
  a «Forzar detención» en Ajustes, que requiere volver a abrir la app.

## Prueba de aceptación

Con datos ficticios y un teléfono físico, comprobar revisión VÍA, recepción
inicial y recepción por derivación. Para cada caso: cerrar la app normalmente,
confirmar el movimiento en el servidor, recibir el aviso y tocarlo para abrir la
nota correcta. Verificar también el rechazo de una cuenta ajena.

Registrar esta evidencia por separado de la actualización del seguimiento. El
sello de #58 y la barra de #63 no forman parte de este cambio. La validación en el
servidor final desplegado y el manual de entrega corresponden además a #65.
