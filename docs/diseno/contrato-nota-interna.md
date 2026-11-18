# Nota interna · Contrato funcional y de API

**Issue:** #42 · **Responsable:** Xmathewbruk · **Revisión técnica:** RazzellRC

**Estado:** borrador para validación. Los nombres de operaciones y las decisiones marcadas como propuestas requieren revisión antes de fijar el contrato.

## Objetivo y alcance

La nota nace en la unidad emisora. Puede pasar por una secuencia de VÍA antes de entregarse a A. CC recibe una copia informativa. Una vez recibida, la hoja de ruta documenta las derivaciones, la atención y el cierre del expediente. El Desafío UNIVALLE (págs. 1–5 y 9) describe estas relaciones. El contrato de la iteración 4 (#29) se reutiliza para las operaciones de hoja, el historial y los errores compatibles.

Las pruebas usan personas, unidades, textos, adjuntos y CITE ficticios. Los documentos de referencia reservados y sus datos quedan fuera del repositorio, de Camunda y de las evidencias.

## Actores y permisos propuestos

| Actor | Cuándo interviene | Acción y efecto |
|---|---|---|
| DE · emisor autenticado | Borrador y emisión | Redacta y emite desde su unidad. Consulta el progreso. Laravel obtiene el actor y la unidad de la sesión. |
| VÍA 1…n · autoridad identificada | Antes de entregar a A | Revisa en el orden indicado. Solo la VÍA activa puede dar conformidad. Registrar quién actuó sobre qué versión y cuándo. La devolución con motivo queda pendiente de validación. |
| A · destinatario | Tras la emisión directa o la última VÍA | Tiene la recepción pendiente. Un funcionario autorizado de destino confirma explícitamente. Abrir, escanear un QR o descargar un archivo no registra recepción. |
| CC · destinatario informativo | Al entregar la nota a A, como propuesta inicial | Consulta la nota y los adjuntos autorizados. Su lectura no habilita acciones sobre la hoja ni condiciona la entrega. La constancia de lectura queda por confirmar. |
| Responsable activo de la hoja | Desde la recepción | Registra atención, deriva según permisos y deja instrucciones. Puede vincular una respuesta o cerrar si tiene la facultad correspondiente. |
| Unidad de destino posterior | Mientras su recepción esté pendiente | Confirma la recepción para asumir la responsabilidad. El responsable anterior conserva la custodia hasta entonces, conforme al #29. |
| Unidad ajena | Siempre | El expediente no aparece en sus vistas. Una consulta directa devuelve 404. Aplicar lo mismo a historial, archivos y QR. |

**Propuesta para revisión:** asignar un CITE correlativo por unidad emisora y gestión al emitir. Confirmar la serie institucional, el formato y el tratamiento de anulaciones. Un reintento de emisión recupera el mismo CITE y proceso, sin generar un duplicado.

## Flujo y contrato entre aplicaciones

| Tramo | Estado visible | Acciones principales |
|---|---|---|
| Redacción | Borrador | Guardar / Emitir |
| Una o más VÍA | Pendiente de revisión | Dar conformidad. El destinatario no tiene recepción pendiente todavía. |
| Entrega directa o última conformidad | Pendiente de recepción | Confirmar recepción |
| Primera recepción | Recibida | Consultar hoja de ruta, derivar o atender según facultad |
| Derivación posterior | Pendiente de recepción | Confirmar en la nueva unidad. Mostrar por separado unidad vigente y destino pendiente. |
| Atención | En atención | Registrar atención, derivar, vincular respuesta o cerrar según facultad |
| Cierre | Cerrada | Consultar el expediente y su historial autorizado |

**Nuevas operaciones propuestas para acordar con Russel**

| Operación | Ruta propuesta | Entrada |
|---|---|---|
| Crear borrador | POST /api/notas-internas | asunto, cuerpo, destinatario_unidad_id, vias_usuario_ids en orden y cc_usuario_ids |
| Editar borrador | PATCH /api/notas-internas/{id} | Campos editables y version |
| Emitir | POST /api/notas-internas/{id}/emision | version, Idempotency-Key |
| Dar conformidad VÍA | POST /api/notas-internas/{id}/conformidades | version, Idempotency-Key |
| Confirmar primera recepción | POST /api/notas-internas/{id}/recepciones | version, Idempotency-Key. Devuelve la referencia de la hoja al confirmar. |
| Consultar bandeja y detalle | GET /api/notas-internas y GET /api/notas-internas/{id} | Filtros y paginación para bandeja. La API comprueba el acceso al detalle. |

Después de la primera recepción, usar las rutas de hoja y las operaciones de historial, adjuntos y respuesta del #29, conforme a sus contratos. En el detalle devolver id, cite, asunto, estado, version, fecha_ultimo_movimiento, unidad_actual, destino_pendiente cuando aplique, hoja_id y acciones_permitidas. La visibilidad depende del actor autenticado. No enviar identificadores de Camunda al cliente.

Camunda determina la siguiente tarea del proceso. Laravel valida la identidad y el permiso, conserva las constancias y presenta el estado confirmado. Un reintento con la misma clave y los mismos datos recupera el resultado. Datos distintos con la misma clave o una versión desactualizada devuelven 409. Ante una respuesta perdida, conservar la clave y evitar presentar éxito hasta confirmar el resultado. El #43 debe comprobar la reconciliación contra el motor real.

## Interfaz institucional

Usar el template institucional compartido definido en #48. Las pantallas web de #44 y #45 y las pantallas Android de #46 usan la misma paleta, tipografía, espaciado, bordes, estados y nombres de acciones. Flutter adapta la disposición para pantallas pequeñas. El #47 compara ambos canales con el mismo expediente ficticio. La observación del ingeniero afecta la presentación de Sakai y las pantallas que verá el funcionario. Evaluar el resultado con una vista de bandeja y otra de detalle antes de extenderlo al resto.

- **Web:** cabecera discreta, navegación institucional sencilla y bandeja tabular. Usar columnas CITE, asunto, remitente o unidad de origen, fecha y estado. Mostrar la acción del rol en el detalle.
- **Android:** listas compactas para Por revisar, Por recibir, Por atender y Copias. Mostrar asunto, origen, fecha y estado, con un botón de acción cuando corresponda.
- **Estilo:** fondo blanco o gris claro, bordes finos, tipografía de sistema, una sola tonalidad sobria para acciones y color funcional para alertas. Usar títulos, tablas y formularios convencionales. Retirar degradados, tarjetas decorativas, iconos de adorno, indicadores de portada y animaciones que no ayuden a trabajar.
- Mantener contraste, etiquetas explícitas, foco visible y mensajes de error legibles. El aspecto administrativo puede ser austero y seguir siendo cómodo para consultar expedientes todo el día.

## Pruebas con datos ficticios

1. **Directa.** Unidad Alfa emite «Solicitud de inventario de prueba» a Unidad Beta sin VÍA. Beta confirma en Android. Web muestra el mismo estado y una única hoja. Repetir emisión y recepción con las claves originales. Verificar un CITE y un movimiento por acción.
2. **Con VÍA y CC.** Unidad Alfa emite «Solicitud de revisión de formulario» con dos autoridades ficticias en secuencia, A en Unidad Beta y CC en Unidad Gamma. La segunda VÍA no actúa antes de la primera. A recibe solo tras la segunda conformidad. CC consulta sin alterar el flujo. Beta deriva a Unidad Delta, que recibe, atiende y registra respuesta cuando corresponda. La autorización de cierre se comprueba según la regla acordada.
3. **Controles comunes.** Un usuario de Unidad Épsilon queda fuera del expediente y sus adjuntos. Web y Android muestran el mismo estado confirmado. Una pérdida de respuesta no produce una segunda constancia. Cada evidencia indica ejecutor, versión y resultado.

## Decisiones pendientes

- **Con el docente o el Concejo:** serie y momento del CITE, reglas de conformidad o devolución por VÍA, facultad de recepción por unidad, alcance y momento de CC, responsable del cierre y mecanismo aceptado para las constancias oficiales. La auditoría del prototipo registra actor, versión y hora del servidor. La aceptación institucional de ese mecanismo queda pendiente.
- **Con Russel:** confirmar endpoints y nombres, matriz de acciones por canal, modelo de errores y casos de prueba. Registrar la revisión cruzada antes de dar por acordado el contrato.
