# Evidencia de integración de Camunda para Nota Interna

Issue #43. Pruebas realizadas el 18 de noviembre de 2026 con el motor local Camunda 8.9.28. Se usaron notas ficticias.

## Ejecución del BPMN

Laravel inició instancias del proceso `nota_interna` desplegado con clave `2251799813685351`. El BPMN está versionado en `web/resources/bpmn/nota-interna.bpmn`.

| Recorrido | Instancia | Tareas verificadas | Resultado |
| --- | --- | --- | --- |
| Envío directo | `2251799813685353` | Primera recepción, atención, recepción de derivación y cierre | `COMPLETED` |
| Dos revisores VÍA | `2251799813685386` | VÍA 1, VÍA 2, primera recepción, atención, recepción de derivación y cierre | `COMPLETED` |

Las solicitudes de completar tarea devolvieron HTTP 204. Por ejemplo, la primera recepción del recorrido directo fue la tarea `2251799813685361`. CC se mantiene fuera de las tareas bloqueantes del BPMN.

## Persistencia y recuperación

Con la migración aplicada en SQLite en memoria, Laravel guardó la instancia `2251799813685453` y devolvió esa misma clave al repetir la emisión. Se simuló una respuesta de creación perdida con una instancia real ya creada y Laravel recuperó la clave `2251799813685462` por el UUID de la nota. También se probó una búsqueda sin resultados: la emisión siguió pendiente y el reintento no volvió a solicitar la creación.

## Validación pendiente

Queda pendiente conectar el servicio a la emisión de Nota Interna del #44 y validar los permisos con usuarios del sistema. La recepción y el recorrido documentado en la hoja de ruta se completan en el #45.
