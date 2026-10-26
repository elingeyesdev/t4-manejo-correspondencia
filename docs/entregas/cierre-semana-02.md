# Cierre técnico de semana 2 — 26/10/2026

Equipo: Mathew Bruckner Becerra (Xmathewbruk, web/API) y Russel (RazzellRC, Flutter).
Corte planificado: 29/10/2026. Registro del incremento técnico integrado anticipadamente; no equivale a aceptación docente, entrega de todas las semanas ni despliegue en producción.

## Alcance integrado y trazabilidad

| Trabajo | Evidencia | Estado |
| --- | --- | --- |
| Núcleo D, EDT 3.1, #11: acceso, roles, catálogos, usuarios y registro transaccional | [PR #12](https://github.com/elingeyesdev/t4-manejo-correspondencia/pull/12), merge cc1861acd5ea891fd67160498afe67d5db1ceabf | Aprobado por RazzellRC el 25/10 e integrado |
| Consulta por guía, #9 | PR #10 como antecedente; versión autenticada actual en PR #14 | Integrada; no se inventa aprobación retrospectiva de #10 |
| Adaptación Flutter a Laravel, #13: sesión protegida, consulta, bandeja, detalle y registro | [PR #14](https://github.com/elingeyesdev/t4-manejo-correspondencia/pull/14), head revisado 532bd1a, merge 923f8871b425ab87b66dc323c8a4185cae5ca500 | Aprobado por Xmathewbruk e integrado el 26/10 |
| Prototipo Node #7 / PR #8 | Antecedente conservado en prototipo/node; sustituido por #11 / PR #12 | Retirado sin fusionar ni acreditar cumplimiento del stack definitivo |
| Diseños Android #6 | movil/DISENO_MOVIL.md, código de diseño y pruebas de PR #14 | Incluidos; falta registro del recorrido humano completo del diseño |

Se mantiene el milestone de #13 en Iteración 03 como planificación original; su implementación fue adelantada. No se alteran por este cierre fechas, EDT, dependencias, ruta crítica ni línea base de ProjectLibre.

## Revisión cruzada y corrección

- Núcleo: [aprobación de RazzellRC](https://github.com/elingeyesdev/t4-manejo-correspondencia/pull/12#pullrequestreview-5645807603).
- Móvil: [solicitud de cambios](https://github.com/elingeyesdev/t4-manejo-correspondencia/pull/14#pullrequestreview-5646460221) por reintento incorrecto de actualización de bandeja.
- Corrección definitiva 532bd1a: conserva el modo de la operación fallida; Actualizar repite página 1 y reemplaza la lista; Cargar más repite la página pendiente conservando las anteriores. Cuatro regresiones nuevas y prueba independiente del revisor aprobadas. La reversión intermedia no es el estado final integrado.
- [Aprobación final de Xmathewbruk](https://github.com/elingeyesdev/t4-manejo-correspondencia/pull/14#pullrequestreview-5653626692) y observación resuelta antes del merge manual de Mathew.

La revisión móvil fue asistida con Codex. No se registra sesión de programación en pareja conductor/copiloto porque no hay evidencia de una sesión real.

## Validación y procedencia

| Fuente | Resultado y límite |
| --- | --- |
| CI del núcleo inicial | [Ejecución 40036634850](https://github.com/elingeyesdev/t4-manejo-correspondencia/actions/runs/40036634850), código ef10e4f; evidencia histórica de semana-02.md |
| CI del último head móvil | [Ejecución 40337217203](https://github.com/elingeyesdev/t4-manejo-correspondencia/actions/runs/40337217203), Núcleo Laravel aprobado; este workflow valida backend, no Flutter |
| CI de revisión móvil inicial | [Ejecución 40250246863](https://github.com/elingeyesdev/t4-manejo-correspondencia/actions/runs/40250246863): 24 pruebas/108 aserciones PostgreSQL, concurrencia 1/13; Pint y Composer aprobados |
| Revisor móvil, segunda revisión | Análisis sin observaciones; 66 aprobadas = 65 del proyecto + 1 regresión independiente; integración Laravel omitida por falta de LARAVEL_TEST_PHP |
| Entorno del revisor | Dart 3.13.4 frente a requisito ^3.13.5. Comprobación exploratoria reduciendo temporalmente el requisito en copia aislada; manifiestos y lock restaurados. No equivale a ejecución con SDK requerido |
| Autor móvil | Declara 66 pruebas completas, integración Laravel/PostgreSQL y APK debug compilado; ver registro de entrega móvil y PR #14 |
| Confirmación del equipo | El 26/10 Mathew transmitió la confirmación del compañero de que funciona y guarda en BD; se documenta como evidencia aportada, no como ejecución independiente de cada caso en Android |

No se publican credenciales, bases de datos ni datos institucionales reales.

## Cierre y pendientes separados

El núcleo de semana 2 y el incremento móvil adelantado están aprobados e integrados en develop. La Iteración 02 puede cerrarse administrativamente tras retirar el antecedente Node, sin ocultar que #7 no se acepta como implementación definitiva y sin fusionar PR #8.

Permanecen abiertos los criterios de #1–#6 que no cuentan con validación específica; en particular, #6 requiere el registro del recorrido humano completo del diseño. La aprobación técnica del PR no reemplaza ese registro. No se declara aceptación docente del software: solo las fechas fueron confirmadas previamente por el usuario.

Adjuntos y cifrado de archivos, cámara real, QR, derivación, recepción, atención, respuesta y cierre documental pertenecen a incrementos posteriores. El diseño y los campos preparados no acreditan su implementación. El inicio del siguiente incremento está planificado en docs/diseno/incremento-03.md.

Mejoras de proceso: incorporar Flutter e integración Laravel a CI; aplicar feature/<issue>-<descripcion> en nuevas funcionalidades. La rama histórica codex/movil-laravel fue una excepción y se conserva sin reescribir el historial. Las diapositivas originales del docente no estuvieron disponibles en esta revisión; el flujo contrastado es CONTRIBUTING.md y la plantilla versionada.
