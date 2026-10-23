# Inicio del siguiente incremento — E y M

El corte de semana 2 contempla iniciar el siguiente incremento. Este documento inicia su análisis, sin afirmar implementación.

## E: adjuntos protegidos y QR

Depende del registro y autorización de D. Añadir entidad Archivo: documento_id, nombre original, MIME verificado, tamaño, ubicación privada y versión de clave. Aceptar PDF, JPEG y PNG reales de 1 byte a 10 MB; almacenar cifrado y descargar solo mediante autorización. El QR contiene referencia opaca y localiza una hoja; no concede acceso ni confirma recepción. Probar formato/tamaño, fallo de escritura, permiso y recuperación de claves/archivos.

## M: acceso Android y consulta

Depende de D. Russel revisa contrato de sesiones/token, URL del emulador, 401/403, expiración, cierre y estado REGISTRADA. Implementar credencial local protegida y bandeja autorizada. Las pruebas reales deben consultar Laravel y comprobar los mismos datos de PostgreSQL; la prueba histórica de Node se conserva diferenciada.

## Planificación

E pertenece a la ruta crítica; M tiene holgura prevista de 2 días. E/M alimentan N y sus holguras no se suman como reservas independientes. Confirmar disponibilidad y reestimar tras la revisión de D. Corte de semana 3: 05/11/2026. El usuario confirmó el 23/10/2026 la aprobación docente de las fechas; la aceptación funcional sigue requiriendo pruebas y revisión.
