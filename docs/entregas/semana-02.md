# Entrega acumulada hasta la semana 2 — #11

Preparación: 23/10/2026. Corte planificado: 29/10/2026, fecha aprobada por el docente según confirmación del usuario el 23/10/2026. Paquete D, EDT 3.1. Núcleo aprobado por RazzellRC e integrado en PR #12 el 25/10/2026; adaptación móvil aprobada por Xmathewbruk e integrada en PR #14 el 26/10/2026. Cierre técnico y evidencia en [acta de cierre](cierre-semana-02.md). La aceptación docente del software sigue pendiente.

## Trazabilidad

| Requisito | Implementación/evidencia |
| --- | --- |
| Base A/B/T/C | Referencia documental conservada en docs/referencia; modelo, contrato, convenciones y plantilla de PR; validaciones humanas previas aún pendientes |
| HU-01 / CU-01 | SessionController, sesiones web con CSRF, cierre, expiración configurada, pruebas de acceso y revocación |
| HU-03 / CU-02 | Unidades, tipos y prioridades; validación de unicidad y habilitación; vistas y API restringidas |
| HU-04 / CU-02 | Usuarios, roles/unidades, hash, deshabilitación, versión de autorización y revocación de tokens |
| HU-05 / CU-03 | StoreDocumentRequest y RegisterDocument: documento, hoja, movimiento, solicitud y auditoría transaccionales |
| Reintentos/concurrencia | Clave por actor/operación, huella de campos y bloqueo de fila; prueba de dos procesos sobre PostgreSQL |
| Revisión cruzada | PR #12 aprobado por RazzellRC; PR #14 aprobado por Xmathewbruk; enlaces y límites en el acta de cierre |

## Organización del repositorio

Web/API definitivas en web/, Flutter en movil/, referencias y diseño en docs/. Node quedó en prototipo/node/ con historial conservado. Se ajustó solamente la ruta del servidor histórico en una prueba móvil y su guía; no se reescribió la aplicación Android.

El prototipo del PR #8 queda sustituido por el núcleo Laravel aprobado en PR #12, sin fusionar el backend Node ni simular aprobación retrospectiva. #10 se conserva como antecedente de la consulta móvil; la revisión actual del cliente Laravel está registrada en PR #14.

## Verificación local realizada

- PHP 8.5.12, Composer 2.10.3, Laravel 13.38.0 y PostgreSQL 16.15.
- Migraciones y seed inicial ejecutados en la base nueva de desarrollo.
- Suite núcleo: 21 pruebas aprobadas, 97 aserciones, tanto en SQLite de pruebas como en PostgreSQL.
- Concurrencia PostgreSQL: 1 prueba aprobada, 13 aserciones, dos procesos con la misma clave; un documento y un movimiento.
- Pruebas históricas Node después de ordenar carpetas: 15 aprobadas.
- Composer valida el manifiesto y no informa avisos de vulnerabilidad en las dependencias instaladas.
- Revisión en navegador: acceso con cuenta ficticia local, formulario, registro real en PostgreSQL, IDs/códigos distintos, detalle, estado y administración.

La evidencia se encuentra en docs/evidencia/semana-02/. Las pruebas Flutter no se ejecutaron en esta sesión (SDK no disponible en PATH); tampoco se acredita integración autenticada con Laravel. La CI se configura para PostgreSQL; ejecución remota aprobada en Linux/PostgreSQL: https://github.com/elingeyesdev/t4-manejo-correspondencia/actions/runs/40036634850 (código ef10e4f).

## Datos locales y ejecución

La cuenta ficticia de revisión y un documento de demostración están solamente en la base local; no se publican credenciales. El archivo .local/acceso-revision.json, ignorado por Git, permite consultar el acceso temporal en este equipo. Para cuentas propias usar php artisan correspondencia:administrador. Las bases de desarrollo y pruebas son distintas; no hay importación silenciosa de datos JSON.

## Cronograma y pendientes

La ruta crítica del documento es A-B-C-D-E-F-G-H-Z; D no tiene holgura. La implementación y pruebas no sustituyen revisión ni aprobación de A/B/C. Reestimar con el tiempo real disponible y revisar dependencias antes de declarar el corte cumplido. Los archivos de ProjectLibre se conservan como referencia sin inventar porcentajes ejecutados ni establecer una línea base aprobada.

El corte pide también el inicio del siguiente incremento: docs/diseno/incremento-03.md identifica dependencias y criterios; es planificación inicial, no código de adjuntos o QR.

Actualización del 26/10/2026: las revisiones del núcleo y del cliente Laravel ya están aprobadas e integradas. Permanecen la aceptación docente del software, los criterios no acreditados de diseño/planificación #1–#6 y las funciones de iteraciones posteriores. La evidencia local anterior se conserva como registro histórico; las comprobaciones más recientes y sus límites están en el acta de cierre. No se modificaron fechas, duraciones ni dependencias del cronograma.
