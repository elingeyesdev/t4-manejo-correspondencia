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
| Consultar bandeja | `GET /api/notas-internas` | `bandeja`, `page` y `per_page`. |
| Consultar detalle | `GET /api/notas-internas/{id}` | La API verifica los permisos y devuelve el detalle actualizado. |

Después de la primera recepción, usar las rutas de hoja y las operaciones de historial, adjuntos y respuesta del #29, conforme a sus contratos. En el detalle devolver id, cite, asunto, estado, version, fecha_ultimo_movimiento, unidad_actual, destino_pendiente cuando aplique, hoja_id y acciones_permitidas. La visibilidad depende del actor autenticado. No enviar identificadores de Camunda al cliente.

Camunda determina la siguiente tarea del proceso. Laravel valida la identidad y el permiso, conserva las constancias y presenta el estado confirmado. Un reintento con la misma clave y los mismos datos recupera el resultado. Datos distintos con la misma clave o una versión desactualizada devuelven 409. Ante una respuesta perdida, conservar la clave y evitar presentar éxito hasta confirmar el resultado. El #43 debe comprobar la reconciliación contra el motor real.

### Bandejas Android · propuesta para revisión

`GET /api/notas-internas?bandeja=por_recibir&page=1&per_page=15` usa el usuario autenticado. Laravel filtra por sus permisos. La página empieza en 1, el tamaño admite de 1 a 50 y toma 15 por defecto. Ordenar por último movimiento descendente y por ID como desempate. Parámetros inválidos devuelven `422`.

| Bandeja | Registros |
|---|---|
| `por_revisar` | Notas pendientes para la VÍA activa del usuario. |
| `por_recibir` | Primera recepción o recepción de una derivación pendiente para la unidad de destino, según permisos. |
| `por_atender` | Notas recibidas o en atención asignadas al responsable que puede actuar. |
| `copias` | Notas visibles como copia según la regla de CC. El momento exacto de visibilidad queda pendiente. |

Ejemplo de respuesta `200` con datos ficticios. Si la bandeja está vacía, se devuelve `data: []` con la misma estructura de paginación.

```json
{
  "data": [
    {
      "id": "30000000-0000-4000-8000-000000000001",
      "cite": "DEMO-ALFA-001",
      "asunto": "Solicitud ficticia de inventario",
      "unidad_origen": {"id": 1, "nombre": "Unidad Alfa"},
      "unidad_actual": {"id": 1, "nombre": "Unidad Alfa"},
      "destino_pendiente": {"id": 2, "nombre": "Unidad Beta"},
      "estado": "pendiente_recepcion",
      "version": 3,
      "fecha_ultimo_movimiento": "2026-11-18T16:00:00Z",
      "documento_id": null,
      "hoja_id": null,
      "acciones_permitidas": ["confirmar_primera_recepcion"]
    }
  ],
  "meta": {"current_page": 1, "per_page": 15, "total": 1, "last_page": 1}
}
```

Estados propuestos: `borrador`, `pendiente_revision`, `pendiente_recepcion`, `recibida`, `en_atencion` y `cerrada`. La lista de acciones puede incluir `dar_conformidad`, `confirmar_primera_recepcion`, `confirmar_recepcion_derivacion` o `registrar_atencion`. Puede estar vacía, por ejemplo en Copias. Android refresca bandeja y detalle al confirmar una acción. Laravel vuelve a comprobar el permiso al ejecutarla.

### Relación con fotos, historial y hoja de ruta

El `id` identifica la nota. La primera recepción devuelve `200` con el detalle actualizado, `documento_id` y `hoja_id`. Un reintento con la misma clave devuelve los mismos identificadores. Antes de la vinculación ambos son `null`. El detalle incluye los eventos previos autorizados en `movimientos_nota` con `id`, `accion`, `actor`, `fecha` y `estado_resultante`. La carga de fotos antes de la primera recepción queda pendiente de definición.

- Con `documento_id`, reutilizar `GET /api/documentos/{documento_id}/adjuntos` y `GET /api/documentos/{documento_id}/historial`. La carga usa `POST /api/documentos/{documento_id}/adjuntos` con el campo multipart `archivo` y los permisos existentes.
- Con `hoja_id`, consultar `GET /api/hojas/{hoja_id}` y usar la versión de la hoja en sus acciones. La primera recepción aparece una sola vez, como inicio de la hoja. El historial previo de la nota permanece disponible para quienes tengan permiso.
- Laravel comprueba el acceso a cada recurso por separado. El vínculo con la nota no concede permiso para ver, cargar ni descargar adjuntos.

### Firma, sello y notificaciones · propuesta para la demo

- **Firma en pantalla.** Mostrar la acción y la versión del documento antes de firmar. Permitir borrar y volver a dibujar el trazo antes de confirmar. Laravel registra el usuario autenticado, el cargo o unidad, la acción, la versión y la hora del servidor. El trazo queda protegido y asociado a esa constancia. Una versión posterior requiere su propia constancia si la acción tiene firma habilitada.
- **Sello de recepción.** Generar una constancia visual al confirmar la recepción, con CITE, unidad receptora, fecha y hora del servidor e identificador de constancia. Mostrar **RECIBIDO · DEMOSTRACIÓN** en el detalle o PDF de prueba. La marca se genera con datos del registro confirmado y es de solo lectura. Mostrarla una sola vez si se repite la operación con la misma clave. La demo usa identidad y marca ficticias.
- **Notificaciones.** Proponer un aviso dentro de la app cuando se habilite una tarea de revisión, recepción o atención. El aviso abre el detalle con verificación de permisos y se registra una vez por transición y destinatario. El canal push y los eventos y destinatarios definitivos, incluido CC, quedan pendientes.
- **Validación institucional.** Confirmar qué acciones exigen firma, quién puede firmar o sellar, la plantilla aprobada y si el Concejo requiere firma digital certificada u otro mecanismo oficial. En el prototipo, el trazo y el sello visual se presentan como evidencia del flujo. Ver [Ley N.º 164, art. 78](https://plantilla-gob-bo.aads.upat.agetic.gob.bo/wp-content/uploads/2024/04/ley-n-164-comprimido.pdf).

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

4. **Firma, sello y aviso.** Confirmar una acción ficticia con firma habilitada y verificar actor y versión. Confirmar recepción, consultar su sello y repetir la acción con la misma clave. Debe conservarse una sola constancia y un solo aviso por destinatario. Probar que un usuario sin permiso no puede abrir el detalle desde el aviso.

## Decisiones pendientes

- **Con el docente o el Concejo:** serie y momento del CITE, reglas de conformidad o devolución por VÍA, facultad de recepción por unidad, alcance y momento de CC, responsable del cierre, acciones que requieren firma, responsables y formato del sello, mecanismo aceptado para las constancias oficiales y reglas definitivas de notificación. La auditoría del prototipo registra actor, versión y hora del servidor. La aceptación institucional de ese mecanismo queda pendiente.
- **Con Russel:** confirmar endpoints y nombres, matriz de acciones por canal, modelo de errores y casos de prueba. Registrar la revisión cruzada antes de dar por acordado el contrato.
