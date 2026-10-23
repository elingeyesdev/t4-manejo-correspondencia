# Entrega acumulada hasta la semana 2 — #11

Preparación: 23/10/2026. Corte propuesto del documento: 29/10/2026. Paquete D, EDT 3.1. Estado: implementado para revisión; pendiente de aprobación del compañero y validación docente. La entrega no se declara aceptada por este informe.

## Trazabilidad

| Requisito | Implementación/evidencia |
| --- | --- |
| Base A/B/T/C | Referencia documental conservada en docs/referencia; modelo, contrato, convenciones y plantilla de PR; validaciones humanas previas aún pendientes |
| HU-01 / CU-01 | SessionController, sesiones web con CSRF, cierre, expiración configurada, pruebas de acceso y revocación |
| HU-03 / CU-02 | Unidades, tipos y prioridades; validación de unicidad y habilitación; vistas y API restringidas |
| HU-04 / CU-02 | Usuarios, roles/unidades, hash, deshabilitación, versión de autorización y revocación de tokens |
| HU-05 / CU-03 | StoreDocumentRequest y RegisterDocument: documento, hoja, movimiento, solicitud y auditoría transaccionales |
| Reintentos/concurrencia | Clave por actor/operación, huella de campos y bloqueo de fila; prueba de dos procesos sobre PostgreSQL |
| Revisión cruzada | docs/revision-semana-02.md; pendiente de ejecución y aprobación por Russel |

## Organización del repositorio

Web/API definitivas en web/, Flutter en movil/, referencias y diseño en docs/. Node quedó en prototipo/node/ con historial conservado. Se ajustó solamente la ruta del servidor histórico en una prueba móvil y su guía; no se reescribió la aplicación Android.

El PR #8 permanece abierto y su base web ya estaba reutilizada en #10. No se fusionan ni cierran automáticamente. #10 figura integrado, pero no tenía revisión formal en la consulta realizada: debe revisarse honestamente sin inventar aprobación retrospectiva.

## Verificación local realizada

- PHP 8.5.12, Composer 2.10.3, Laravel 13.38.0 y PostgreSQL 16.15.
- Migraciones y seed inicial ejecutados en la base nueva de desarrollo.
- Suite núcleo: 21 pruebas aprobadas, 97 aserciones, tanto en SQLite de pruebas como en PostgreSQL.
- Concurrencia PostgreSQL: 1 prueba aprobada, 13 aserciones, dos procesos con la misma clave; un documento y un movimiento.
- Pruebas históricas Node después de ordenar carpetas: 15 aprobadas.
- Composer valida el manifiesto y no informa avisos de vulnerabilidad en las dependencias instaladas.
- Revisión en navegador: acceso con cuenta ficticia local, formulario, registro real en PostgreSQL, IDs/códigos distintos, detalle, estado y administración.

La evidencia se encuentra en docs/evidencia/semana-02/. Las pruebas Flutter no se ejecutaron en esta sesión (SDK no disponible en PATH); tampoco se acredita integración autenticada con Laravel. La CI se configura para PostgreSQL; su ejecución remota debe verificarse en el PR.

## Datos locales y ejecución

La cuenta ficticia de revisión y un documento de demostración están solamente en la base local; no se publican credenciales. El archivo .local/acceso-revision.json, ignorado por Git, permite consultar el acceso temporal en este equipo. Para cuentas propias usar php artisan correspondencia:administrador. Las bases de desarrollo y pruebas son distintas; no hay importación silenciosa de datos JSON.

## Cronograma y pendientes

La ruta crítica del documento es A-B-C-D-E-F-G-H-Z; D no tiene holgura. La implementación y pruebas no sustituyen revisión ni aprobación de A/B/C. Reestimar con el tiempo real disponible y revisar dependencias antes de declarar el corte cumplido. Los archivos de ProjectLibre se conservan como referencia sin inventar porcentajes ejecutados ni establecer una línea base aprobada.

El corte pide también el inicio del siguiente incremento: docs/diseno/incremento-03.md identifica dependencias y criterios; es planificación inicial, no código de adjuntos o QR.

Pendientes: revisión de Russel, revisión de Mathew del móvil, validación docente, conciliación de issues previos y aceptación del contrato móvil. Ninguno se marca terminado sin evidencia.
