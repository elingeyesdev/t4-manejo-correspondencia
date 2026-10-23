# Colaboración del equipo

Laravel es obligatorio para la web/API. El cliente móvil vigente es Flutter. El stack no debe sustituirse por conveniencia del entorno.

`develop` integra incrementos revisados; `main` se reserva para versiones aceptadas cuando exista y se acuerde su creación. No crear una rama principal con contenido no aprobado. Trabajar en ramas `feature/<issue>-<descripcion>`, `fix/...` o `docs/...` desde `develop` actualizado.

Commits con propósito concreto: `feat`, `fix`, `test`, `docs` o `chore`, alcance y referencia al issue. No reescribir el historial compartido ni fusionar trabajo sin la revisión acordada. Las decisiones del material docente prevalecen; una convención aquí propuesta no equivale a aprobación del docente.

Para cada incremento: issue y criterios → rama → commits → PR hacia develop → pruebas → revisión del otro integrante → correcciones → aprobación → integración. El autor no aprueba su propio PR. No simular sesiones de pareja, revisiones ni resultados.

Mathew revisa el trabajo móvil de Russel; Russel revisa el trabajo web/API de Mathew. Registrar conductor y copiloto cuando haya una sesión real de programación en pareja. La revisión de PR complementa esa práctica.

No versionar `.env`, tokens, contraseñas, dependencias, bases, logs ni datos reales. Versionar `composer.lock`. Mantener casos de prueba con datos aislados y documentación consistente con lo ejecutado.

La línea base de ProjectLibre solo se aprueba tras validación docente. Actualizar avance a partir de evidencia. Al cambiar duración, disponibilidad o dependencias, recalcular ruta crítica y carga de recursos. Los milestones de GitHub deben reflejar el corte acordado y diferenciar propuesta de aprobación.
