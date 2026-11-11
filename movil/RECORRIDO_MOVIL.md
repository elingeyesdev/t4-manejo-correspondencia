# Recorrido de correspondencia en Android — Issue #33

La bandeja permite abrir documentos autorizados y localizar una hoja con **Escanear QR de hoja de ruta**. También se puede pegar el enlace del QR. La lectura abre el expediente y conserva su estado.

En el detalle, Laravel indica qué acciones permite a la cuenta:

- **Derivar hoja**. Elegir una unidad de destino habilitada y escribir un motivo de 1 a 500 puntos de código Unicode.
- **Confirmar recepción**. Confirmar el aviso para asumir la responsabilidad de una hoja pendiente para la unidad.
- **Registrar atención**. Escribir una observación de 1 a 2 000 puntos de código. Cada registro se conserva en el historial.

El detalle actualiza estado, unidad vigente, responsable e historial. El responsable recibido puede adjuntar una foto con la captura y vista previa existentes. Guardar la atención y subir la foto son operaciones separadas. Si falla el archivo, se recupera solo la foto.

Si se pierde una respuesta, **Reintentar confirmación** conserva el cuerpo y la clave de la operación. Los datos permanecen bloqueados mientras se desconoce el resultado. Un conflicto confirmado recarga el detalle para revisar la versión actual. Para un archivo de resultado incierto, **Comprobar subida** consulta y compara el contenido antes de darlo por guardado.

## Comprobación en teléfono

1. Configurar cuentas de recepción en la unidad A, funcionario en B y funcionario en C.
2. Registrar una correspondencia en A.
3. Desde Android, derivar a B con motivo. Comprobar en web que sigue siendo responsable A y está pendiente.
4. Entrar como funcionario de B y localizar por bandeja o escanear el QR de la web. Leer el QR debe conservar estado y movimientos.
5. Confirmar recepción y comprobar responsable B, estado RECIBIDA y un único evento.
6. Registrar atención, adjuntar una foto y abrir el mismo archivo desde web.
7. Comprobar el rechazo de C, sesión vencida, permiso de cámara denegado y pérdida de conexión.
8. Revisar el historial después de reintentar y verificar que no se repitió el movimiento.

La lectura óptica y los permisos nativos requieren comprobación en el teléfono. El análisis, pruebas y compilación se registran según sus resultados reales. La evidencia del recorrido completo y los diagramas corresponden al #34.

## Código

- lib/funciones/recorrido/ contiene operaciones y formularios.
- lib/funciones/qr/ contiene cámara QR y consulta de hoja.
- lib/funciones/mi_bandeja/ contiene bandeja, detalle y navegación.
- test/recorrido_test.dart verifica claves, respuestas, validación, confirmación y conflictos.
- test/recorrido_real_test.dart verifica HTTP con Laravel y PostgreSQL local aislado, incluida una recepción cuya respuesta se pierde después de guardarse.

Las pruebas reales requieren LARAVEL_TEST_PHP y LARAVEL_ADJUNTOS_BACKEND. Solo usan la base correspondencia_test en PostgreSQL local. Sus cuentas, unidades, documento y almacenamiento son temporales.

## Verificación ejecutada — 11/11/2026

- Flutter analyze finalizó sin observaciones.
- Flutter test aprobó las 108 pruebas con las integraciones reales activadas y ejecución secuencial.
- La prueba del recorrido utilizó Flutter, HTTP, Laravel y PostgreSQL local en correspondencia_test. Verificó derivación, consulta QR sin recepción, una respuesta perdida después de recibir, recuperación de esa misma solicitud, atención, foto y rechazo de una tercera unidad.
- La comprobación de permiso QR denegado se ejecutó como prueba de widgets con permiso simulado. La lectura óptica y los permisos del dispositivo físico siguen pendientes.
- Flutter build apk --debug compiló correctamente. El APK generado está en build/app/outputs/flutter-apk/app-debug.apk y permanece ignorado por Git.
- El usuario confirmó la recepción en su teléfono y posteriormente informó haber realizado las pruebas del teléfono. Esta confirmación no equivale a una observación independiente de cada escenario; no se adjuntaron capturas de esa sesión.
- La suite de 108 pruebas volvió a pasar contra el backend integrado del PR #39 (feb6011), junto con flutter analyze sin observaciones.
- Rama feature/33-recorrido-android. Mathew debe revisar los criterios y registrar su aprobación antes de integrar y cerrar el issue.
