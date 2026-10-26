# Contrato API de la semana 2

Laravel sirve el prefijo `/api`. JSON UTF-8, `Accept: application/json`. Referencias #4 y #11. Este contrato requiere revisión de Russel antes de adaptar el móvil.

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

La consulta conserva `guia`, `estado` y `fechaUltimoMovimiento` como campos superiores, pero ahora exige credenciales y el estado es `REGISTRADA`. El móvil actual no envía token y traduce cualquier 409 como seguimiento ausente: debe actualizar su manejo. No reutilizar ese significado para conflictos de registro. Los nuevos documentos no se importan desde el JSON; una importación histórica requeriría decisión y pruebas aparte.

Puerto Laravel local 8000, frente al 3000 del prototipo. Emulador: `http://10.0.2.2:8000`. USB: `adb reverse tcp:8000 tcp:8000`. El móvil debe configurar API_BASE_URL y usar HTTPS fuera del entorno local. El acceso autenticado de la semana 3 está implementado para revisión en #13.

## Opciones de registro para Android

`GET /api/configuracion-registro`, autenticado y con cuenta/unidad habilitadas.
Recepción y administrador reciben `{unidades:[{id,name}],tipos:[{id,name}],prioridades:[{id,name}]}`.
Solo se devuelven opciones habilitadas; recepción ve únicamente su unidad.
Funcionario recibe 403. No concede acceso administrativo a usuarios ni catálogos.
Pruebas: `ConfiguracionMovilTest`. Ampliación al núcleo del PR #12 incluida en la entrega móvil para revisión.