# Historial documental — #20 / T10

## Alcance y estado

Iteración 03, corte aprobado: 05/11/2026. Responsable web/API: Xmathewbruk; revisión cruzada prevista: RazzellRC.

Implementación local en `feature/20-historial-documental`: consulta de movimientos persistidos, sin crear ni modificar operaciones de negocio. Commit funcional `a64ac63`; incorporación del QR ya aprobado desde develop mediante `dd3fec0`. Implementación y verificación local acreditadas según la evidencia inferior. El #20 permanece pendiente de publicación y revisión cruzada; esta documentación no acredita aprobación.

## Consulta y autorización

- API: `GET /api/documentos/{id}/historial`, donde `id` es el UUID del documento.
- Enviar `Accept: application/json` y `Authorization: Bearer <token>`. Rutas protegidas con Sanctum y cuenta/unidad operativas.
- Administrador: alcance global del documento; recepción y funcionario: documentos de su unidad, según `Document::visibleTo`.
- Web: el detalle `GET /documentos/{id}` usa sesión y el mismo servicio `DocumentHistory`. Mantiene el panel de adjuntos y la tarjeta QR.
- Desde una hoja: la consulta QR existente `GET /api/hojas/{reference}` devuelve el documento y su `id`; ese identificador se usa para consultar el historial. En web, `/hojas/{reference}` redirige al detalle. El UUID de la hoja y el del documento son distintos; no intercambiarlos.
- La respuesta del nuevo endpoint incluye `Cache-Control: private, no-store`. No se exponen correos, contraseñas ni tokens en sus actores.
- Consultar no confirma recepción, no cambia estado/responsable/versión y no inserta movimientos, auditorías ni solicitudes de registro.

## Respuesta 200

El objeto contiene `documento_id`, `hoja` con `id`, `codigo` y `estado`, `total` y `data`. Cada elemento de `data` contiene:

| Campo | Significado |
| --- | --- |
| id | UUID del movimiento persistido |
| accion | Acción guardada en el movimiento |
| actor | Objeto con id del usuario ejecutor y nombre disponible |
| unidad_origen | Objeto con id y nombre, o null si no se registró |
| unidad_destino | Objeto con id y nombre, o null si no se registró |
| fecha | occurred_at en ISO 8601 UTC, terminado en Z |
| estado_resultante | Estado guardado para ese movimiento |
| motivo | Motivo persistido, o null |

Los nombres corresponden a los usuarios/unidades relacionados en el momento de consultar; no se reconstruyen nombres históricos anteriores a una edición. Las fechas, acciones, referencias y estados resultantes proceden del movimiento almacenado.

Se devuelve la lista completa disponible, sin paginación en este incremento. Orden ascendente por `occurred_at` y, en empate, por `id`; el UUID da estabilidad, no acredita una secuencia causal adicional entre eventos simultáneos.

Documento accesible con hoja y sin movimientos: 200, `total: 0`, `data: []`. Documento/hoja inexistentes o documento fuera del alcance: 404. UUID mal formado: 404 por restricción de ruta. Sin autenticación API: 401; cuenta o unidad deshabilitada: 403. La web sin sesión redirige al acceso.

El contrato previo de `GET /api/documentos/{id}`, incluido su campo `movimientos`, se conserva para los clientes existentes. El endpoint específico de historial añade una representación explícita con nombres y unidades.

## Pantalla y límites funcionales

Se adapta la tabla existente de Sakai Vue/PrimeVue en `DocumentDetail.vue`, con acción, ejecutor, unidades, fecha en America/La_Paz, estado resultante y motivo. No se incorpora un diseño independiente. Origen y licencia MIT del template conservados en [ORIGEN.MD](../../web/resources/js/sakai/ORIGEN.MD).

La tabla muestra un mensaje cuando no hay movimientos y aclara que el registro inicial no acredita derivaciones, recepciones ni cierre. Actualmente el núcleo crea la acción REGISTRO. Las operaciones futuras de derivación, recepción y cierre no se implementan mediante este issue ni se generan eventos ficticios para aparentar un recorrido completo. Cuando existan movimientos persistidos adicionales, el servicio puede listarlos; ello no acredita que sus operaciones de escritura estén implementadas.

## Verificación y ejecutores — 02/11/2026

| Comprobación | Resultado acreditado | Ejecutor |
| --- | --- | --- |
| Suite específica de historial | 12 pruebas, 53 aserciones | Mathew, salida compartida |
| Suite completa antes de incorporar QR | 65 pruebas, 356 aserciones | Mathew |
| Suite completa con QR e historial combinados | 76 pruebas, 401 aserciones, SQLite en memoria | Codex |
| Pint y compilación Vite tras resolver conflictos | Aprobados | Codex |
| PostgreSQL aislado y concurrencia tras la combinación | 76 pruebas, 401 aserciones; concurrencia: 1 prueba, 13 aserciones | Mathew, salida compartida |
| Revisión visual del historial combinado | Capturas con QR, tabla de historial, REGISTRO, ejecutor, unidades, fecha/hora Bolivia, estado y motivo disponibles | Mathew, capturas inspeccionadas por Codex |
| Revisión cruzada del #20 | Pendiente, mediante PR hacia develop | RazzellRC |

Las pruebas cubren autenticación, acceso propio/ajeno, evento real de registro, ausencia de mutaciones, coherencia web/API, historial vacío, UUID inexistente/mal formado, cuenta/unidad deshabilitadas, orden por fecha/UUID y unidades enviadas al componente. Los movimientos adicionales para probar orden son datos sintéticos solo de la base aislada, sin atribuirles una operación de negocio ejecutada.

Mathew ejecutó el desarrollo manual guiado y los commits. Codex corrigió declaraciones duplicadas en pruebas, resolvió los tres conflictos al incorporar el QR y preparó esta documentación. No se acredita sesión de programación en pareja ni revisión del compañero para #20.

## Comandos de verificación

Desde la raíz del repositorio:

```powershell
Push-Location .\web
php vendor/bin/pint --test
npm.cmd run build
php artisan test
Pop-Location
php .\scripts\test-postgres.php
git diff --check
```

El script PostgreSQL usa la base separada `correspondencia_test` y toma la conexión local sin imprimir las credenciales. No versionar .env, claves, bases, archivos subidos, dependencias ni compilados.

Siguientes pasos: commit de documentación, publicación de la rama, PR hacia develop y revisión de RazzellRC antes de integrar y cerrar #20. No contar el PR como otro entregable en el mismo milestone.
