# T37 · Registro de integración documental

**Responsable de integración:** Mathew (@Xmathewbruk). **Revisión cruzada:** Russel (@RazzellRC).

Mathew comunicó el 27 de noviembre de 2026 que el sistema se desplegó en el servidor y que se realizaron todas las pruebas de T37. La fecha corresponde al reporte. La confirmación es global. Para la revisión se distingue esa declaración de los resultados que cuentan con un archivo o un registro identificable.

## Identificación de la entrega

| Elemento | Registro |
| --- | --- |
| Web/API | [PR #78](https://github.com/elingeyesdev/t4-manejo-correspondencia/pull/78), integrado para #75. |
| Android | [PR #79](https://github.com/elingeyesdev/t4-manejo-correspondencia/pull/79), integrado para #76. |
| Avisos | [PR #80](https://github.com/elingeyesdev/t4-manejo-correspondencia/pull/80), integrado en la línea base. |
| Código de referencia | `189b3f8bd9bd0e67bc480a08b27333f398ff720b`. Falta incorporar el SHA observado en el servidor. |
| Aplicación y dispositivo | El manifiesto Flutter declara `1.0.0+1`. El PR #79 identifica un POCO F3 para la prueba móvil previa. Faltan la identificación del APK instalado y el modelo del teléfono usados en T37. |

## Anexo al plan SQA · Resultados por criterio

La columna de respaldo indica qué parte del resultado puede contrastar el revisor. Los PR citados describen sus propios entornos. El reporte del responsable acredita la ejecución comunicada para el servidor de entrega.

| Prueba | Resultado esperado | Resultado comunicado y respaldo disponible |
| --- | --- | --- |
| Nota directa y nota con VÍA | CITE al emitir, turnos respetados, hoja cerrada e instancia completada en Camunda para ambas notas. | Ejecución reportada. Falta vincular los dos CITE ficticios con sus estados finales en el servidor. |
| Redacción de dos páginas | Encabezado y cuerpo se actualizan; cada hoja conserva membrete, márgenes y pie. | Ejecución reportada. Se adjunta un [borrador ficticio de dos páginas de la revisión web](../evidencia/t37/borrador-dos-paginas.pdf) como referencia de composición. |
| Lectura en cada etapa | Abrir la segunda página antes de actuar conserva el estado; la hoja sigue accesible tras derivación y cierre. | Ejecución reportada. El PR #79 documenta lectura de la segunda página y consulta de la nota cerrada en el teléfono. |
| Firma y sello | Es posible revisar marcas antes de confirmar. Emisión y conformidad requieren firma vigente y actor habilitado. | Ejecución reportada. Los PR #78 y #79 describen las verificaciones de ambos clientes. |
| Recepción inicial | RECIBIDO aparece tras confirmar e identifica unidad, funcionario y hora del acto. | Ejecución reportada. El PR #79 documenta consulta de RECIBIDO; faltan las vistas pareadas de la misma nota de T37. |
| Descarga e impresión | Misma versión, CITE, paginación y constancias en vista, PDF y papel. | Ejecución reportada. El PR #79 registra una descarga de 442007 bytes. Falta adjuntar el cotejo con la impresión de la versión desplegada. |
| Entrada externa con anexo | La unidad de destino recupera el original y el anexo después de confirmar la recepción; el historial conserva la transferencia. | Ejecución reportada. Falta vincular el expediente ficticio y la evidencia de los dos archivos en destino. |
| Acceso directo al PDF | La cuenta ajena al expediente recibe una denegación. | Ejecución reportada. Falta registrar la respuesta observada en el servidor para esa cuenta. |
| Recepción interrumpida | El reintento recupera la acción confirmada; queda una recepción y un sello. | Ejecución reportada. El PR #79 documenta el ajuste de recuperación y las pruebas de regresión; falta vincular el historial del intento de entrega. |
| Cuentas de entrega | Las cuentas individuales autorizadas ingresan en web y Android tras retirar o sustituir las credenciales compartidas. | Ejecución reportada. Falta la constancia del responsable sobre el resultado de la rotación y el acceso por rol. Registrar únicamente los roles y el resultado. |

## Revisión y cierre

Para completar el expediente del [issue #77](https://github.com/elingeyesdev/t4-manejo-correspondencia/issues/77), asociar al reporte la identificación del despliegue y las evidencias de entrega indicadas arriba. El responsable puede consignar incidencias o dejar constancia expresa de que la ejecución concluyó conforme. El cierre del milestone corresponde a la revisión de ese expediente.
