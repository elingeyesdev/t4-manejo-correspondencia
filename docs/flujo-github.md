# Flujo de colaboración en GitHub

Esta guía aplica los acuerdos de [CONTRIBUTING.md](../CONTRIBUTING.md). No sustituye los criterios del docente ni acredita aceptación del software. Actualización documental: 03/11/2026, preparada por Codex por encargo de Mathew; requiere revisión cruzada antes de integrarse.

## Del issue a la integración

1. El issue identifica responsable, historia o tarea, criterios verificables y corte aprobado. Los pendientes se mantienen visibles.
2. Crear la rama `feature/<issue>-<descripcion>`, `fix/...` o `docs/...` desde `develop` actualizado, con el árbol de trabajo limpio. Cada commit explica su propósito y referencia el issue.
3. Abrir el PR contra `develop`, asignar al autor y solicitar revisión al otro integrante. Mathew revisa el móvil de Russel; Russel revisa la web/API de Mathew. Registrar ejecutores reales y asistencia utilizada.
4. Adjuntar pasos reproducibles y resultados realmente ejecutados: entorno, comandos, alcance, omisiones y evidencia. Un check Laravel aprobado no acredita Flutter ni una prueba física de cámara.
5. El revisor comprueba el diff y los criterios; registra observaciones o aprobación en GitHub. Corregir los hallazgos y repetir las comprobaciones afectadas. Cambios posteriores a la revisión deben quedar revisados.
6. Integrar únicamente con aprobación del otro integrante, comprobaciones requeridas satisfactorias y observaciones bloqueantes resueltas. El autor no se aprueba a sí mismo. Una revisión posterior al merge se registra como tal.
7. Cerrar el issue cuando todos sus criterios estén acreditados; enlazar el PR y la evidencia. La integración de una parte no cierra un criterio operativo todavía pendiente.

No versionar `.env`, claves, tokens, bases, respaldos, datos reales, dependencias ni compilados. Conservar `composer.lock`. No reescribir el historial compartido.

## Tablero y milestones

| Situación comprobada | Estado de trabajo |
| --- | --- |
| Trabajo identificado y todavía no iniciado | Backlog |
| Implementación en curso | En progreso |
| PR preparado y revisión del compañero pendiente | En revisión |
| Criterios acreditados, aprobación registrada e integración realizada | Hecho |

Usar la opción equivalente que tenga configurada el tablero. El issue y su PR deben reflejar la misma situación. La tarea #4 se conserva en Backlog conforme a la indicación de Mathew.

En Iteración 03 cada entregable cuenta mediante su issue; los PR son evidencia y no se agregan al mismo milestone para evitar duplicar esa entrega. Los milestones históricos conservan su trazabilidad; sus cierres pueden incluir trabajo sustituido y pares issue/PR. No interpretar su porcentaje como esfuerzo, cobertura ni aceptación docente.

Estado comprobado el 03/11/2026: Iteración 03 contiene seis issues, cinco cerrados y #18 abierto (83,3 % por conteo). PR #27 tiene checks aprobados y revisión solicitada a RazzellRC; falta su aprobación e integración. La fecha 05/11/2026 permanece sin cambios. El milestone no se cierra por una prueba local satisfactoria.

## Protección de develop: propuesta para el propietario

La lectura del 03/11/2026 devuelve `protected: false`. La cuenta Xmathewbruk tiene permiso de escritura, pero no de administración. Por tanto, estas reglas están propuestas y **no activadas**.

El propietario puede configurar una protección de `develop` que exija:

- PR y al menos una aprobación del otro integrante antes del merge.
- Nueva revisión cuando cambie el contenido aprobado.
- Check `laravel` satisfactorio, emitido por GitHub Actions, y rama actualizada antes de integrar.
- Resolución de conversaciones bloqueantes.
- Prohibición de force push y borrado de `develop`; sin excepción ordinaria para saltarse la revisión.

No exigir historial lineal sin acordar antes un cambio: el repositorio conserva commits de merge revisados. Tampoco crear `main` ni modificar el cronograma como parte de esta configuración.

El propietario debe comprobar la configuración con un PR de prueba antes de darla por vigente. Referencia: [protección de ramas en GitHub](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches).

## Cierre de una iteración

Revisar la lista real de entregables, los criterios, las aprobaciones y la evidencia. Mantener el corte aprobado y documentar cualquier continuación. No cerrar/reabrir issues para aparentar avance ni atribuir al compañero pruebas o revisiones que no registró. El cierre administrativo del milestone y la aceptación docente son hechos distintos.
