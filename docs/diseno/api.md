# Contrato API de la semana 2

Laravel sirve el prefijo `/api`. JSON UTF-8, `Accept: application/json`. Referencias #4 y #11. Contrato del núcleo revisado con PR #12; adaptación Flutter de Russel aprobada e integrada en PR #14. Esto no cierra el diseño completo de operaciones futuras de #4.

## Acceso

`POST /api/sesiones`: `email`, `password`, `device_name`. Devuelve 200 con `token` y `user` sin hash; errores de credenciales o cuenta/unidad deshabilitada: 422, intentos limitados: 429. Las demás rutas requieren `Authorization: Bearer <token>`. Token válido por ocho horas. `DELETE /api/sesiones/actual` revoca ese token y devuelve 204. La web usa sesión y CSRF, no guarda el token móvil en el navegador.

## Operaciones implementadas

| Método y ruta | Entrada | Resultado |
| --- | --- | --- |
| GET /api/documentos | page opcional | Registros autorizados paginados (`data`, `total`, etc.) |
| POST /api/documentos | Campos abajo y Idempotency-Key | 201 nuevo; 200 reintento reconocido |
| GET /api/documentos/{uuid} | UUID de documento | Objeto con documento, hoja y movimientos |
| GET /api/correspondencia/guia/{guia} | Guía completa | Mismo objeto; 404 con codigo GUIA_NO_ENCONTRADA si no es visible o no existe |
| GET /api/administracion | Administrador | Unidades, catálogos y usuarios |
| POST /api/unidades; PUT /api/unidades/{id} | code, name, enabled | Guarda unidad; administrador |
| POST /api/catalogos; PUT /api/catalogos/{id} | kind, code, name, enabled | kind tipo/prioridad inmutable; administrador |
| POST /api/usuarios; PUT /api/usuarios/{id} | name, email, unit_id, role, enabled, password y password_confirmation | Administrador; contraseña requerida al crear, opcional al actualizar |

Los códigos de catálogos/unidades usan mayúsculas, números, guion y guion bajo. Roles: administrador, recepcion, funcionario. No hay DELETE para catálogos o usuarios: deshabilitar mantiene las referencias. Actualizar un usuario revoca tokens e invalida sus sesiones anteriores mediante auth_version.

Registro: `remitente` (1–150 caracteres), `asunto` (1–500), `fecha` (YYYY-MM-DD), `tipo_id`, `prioridad_id`, `unidad_id`. La cabecera `Idempotency-Key` acepta 16–100 caracteres alfanuméricos, guion o guion bajo; también `request_key` para formularios. Usar UUID nuevo por intención y conservarlo en reintentos. Recepción registra solo en su unidad; administrador en cualquiera habilitada; funcionario no registra.

Respuesta de registro/consulta: `id`, `codigo`, `guia`, `remitente`, `asunto`, `fecha`, `unidad`, `tipo`, `prioridad`, `estado` (`REGISTRADA`), `fechaUltimoMovimiento` (ISO 8601 UTC), `hoja` (`id`, `codigo`, `responsable_id`, `destino_pendiente_id`, `version`) y `movimientos`. Los identificadores y hora inicial los genera el servidor; no se aceptan estado, guía o actor del cliente.

Errores comunes: 401 sin token/sesión; 403 cuenta, unidad o permiso inválido; 404 inexistente o no visible; 409 clave repetida con datos diferentes; 422 validación (`message`, `errors`); 429 límite de acceso; 500 fallo interno. Un fallo transaccional no confirma registros parciales. En producción APP_DEBUG=false.

## Diferencias con el prototipo móvil

La consulta conserva `guia`, `estado` y `fechaUltimoMovimiento` como campos superiores, exige credenciales y el estado es `REGISTRADA`. El cliente Flutter integrado en PR #14 envía token y distingue conflictos de registro de una guía inexistente. El comportamiento anterior de Node se conserva como referencia histórica. Los nuevos documentos no se importan desde el JSON; una importación histórica requeriría decisión y pruebas aparte.

Puerto Laravel local 8000, frente al 3000 del prototipo. Emulador: `http://10.0.2.2:8000`. USB: `adb reverse tcp:8000 tcp:8000`. El móvil debe configurar API_BASE_URL y usar HTTPS fuera del entorno local. El acceso autenticado previsto para la semana 3 se adelantó y quedó integrado mediante #13 / PR #14.

## Opciones de registro para Android

`GET /api/configuracion-registro`, autenticado y con cuenta/unidad habilitadas.
Recepción y administrador reciben `{unidades:[{id,name}],tipos:[{id,name}],prioridades:[{id,name}]}`.
Solo se devuelven opciones habilitadas; recepción ve únicamente su unidad.
Funcionario recibe 403. No concede acceso administrativo a usuarios ni catálogos.
Pruebas: `ConfiguracionMovilTest`. Ampliación al núcleo del PR #12 incluida en la entrega móvil aprobada e integrada mediante PR #14.

## Adjuntos — incremento #18 / T08

Carga, listado y descarga autenticados de adjuntos integrados mediante PR #23; Android y el panel web mediante PR #24. Consultar [contrato de adjuntos y evidencia](adjuntos.md) para rutas, multipart, permisos, respuestas, cifrado y límites. La [recuperación operativa local](recuperacion-adjuntos.md) de PostgreSQL, claves y archivos fue comprobada el 03/11/2026; esta continuación del #18 está pendiente de revisión cruzada. El contrato anterior conserva el alcance del núcleo de semana 2.

## QR de hoja de ruta — #19 / T09

Consulta autorizada por UUID de hoja: `GET /api/hojas/{reference}`. Imagen protegida: `GET /api/hojas/{reference}/qr.svg`. El QR contiene la URL web `/hojas/{reference}` de la instancia; no concede permisos ni confirma recepción. Contrato, origen de dependencias y evidencia en [QR de hoja de ruta](qr-hoja-ruta.md). QR aprobado por RazzellRC e integrado mediante PR #25; su aceptación es independiente del historial #20.

## Historial documental — #20 / T10

`GET /api/documentos/{id}/historial` devuelve documento, hoja, total y movimientos persistidos ordenados por fecha e identificador, con actor y unidades. Exige autenticación y el mismo alcance de acceso del documento. La vista web usa el mismo servicio; consultar no confirma recepción ni modifica el historial. Contrato, límites y evidencia en [Historial documental](historial-documental.md). Implementación local con QR integrado; revisión cruzada del #20 pendiente.

## Atención documental (#31 / T14)

`POST /api/hojas/{uuid}/atenciones` recibe el UUID de la hoja, `version` entera positiva, `observacion` de 1 a 2 000 puntos de código y la cabecera `Idempotency-Key`. El responsable activo puede registrar atención en `RECIBIDA` o `EN_ATENCION`. El detalle ofrece `atender` en `acciones_permitidas` cuando corresponde.

La operación devuelve `201` con `documento_id`, `hoja` en estado `EN_ATENCION` y `movimiento.accion` igual a `ATENCION`. La versión sube una unidad y el historial conserva el autor, la fecha del servidor y la observación en `data[].motivo`. El reintento con el mismo cuerpo y clave devuelve `200` con el resultado anterior. Una corrección usa una clave nueva y la versión vigente. Consultar los códigos de error en el [contrato del recorrido](contrato-recorrido.md#reintentos-conflictos-y-errores).

La foto opcional se envía por la ruta de adjuntos del documento. Si falla la carga, la atención queda guardada y se reintenta solo la foto. El responsable activo puede cargarla con la hoja recibida o en atención. En una hoja cerrada, los archivos existentes siguen disponibles para usuarios autorizados.

## Respuesta y cierre (#32 / T15)

- `POST /api/documentos/{uuid}/respuestas` recibe el UUID del original, `remitente`, `asunto`, `fecha`, `tipo_id`, `prioridad_id` y `version`. El responsable activo obtiene `201` con `respuesta_id`. La hoja conserva su estado y aumenta su versión. La unidad de la respuesta se toma de la hoja.
- `POST /api/hojas/{uuid}/cierre` recibe el UUID de la hoja, `motivo` de 1 a 500 puntos de código y `version`. El responsable activo puede cerrar desde `RECIBIDA` o `EN_ATENCION` sin recepción pendiente. Devuelve `200` con la hoja `CERRADA` y el movimiento `CIERRE`, incluido `movimiento.motivo`. Un segundo cierre autorizado devuelve el resultado original.
- Ambas rutas usan `Idempotency-Key`. Los formularios web usan sesión, CSRF y `request_key`. Sakai exige una confirmación explícita al cerrar.
- El detalle del original incluye `respuestas`. El detalle de cada respuesta incluye `documento_original`. Las dos consultas respetan el acceso al expediente original y comparten la hoja y el historial. El cierre conserva la consulta autorizada y bloquea nuevas operaciones de recorrido.
