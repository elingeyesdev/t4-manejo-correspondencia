# Android · Estado de #63, #64 y #65

23/11/2026.

- **#64:** terminado e integrado por Mathew mediante el PR #71. Las dos
  observaciones de revisión están corregidas en `27f30e4`.
- **#58:** revisado y fusionado mediante #72 (`a165362`). Pasaron 110 pruebas de
  aplicación y dos de concurrencia PostgreSQL; Pint y CI correctos. La inspección
  del visor PDF de escritorio no pudo repetirse por un fallo de la herramienta.
- **#63:** integración del sello real, firmas y QR terminada localmente, pruebas
  focalizadas aprobadas y APK compilado. Laravel/Camunda reales completaron el
  recorrido y devolvieron el mismo sello al reintentar. Falta instalar esta
  versión y medir las tres actualizaciones automáticas en el teléfono.
- **#65:** manual preparado en la rama local `codex/65-entrega-android`. Falta
  conocer la dirección del servidor Ubuntu de Mathew y ejecutar allí el recorrido
  final con teléfono físico sin USB. La dirección Wi-Fi local no sustituye esa
  comprobación.

[Evidencia de integración de #63](../evidencia/iteracion-06/seguimiento-sello-23-11/README.md).
[Contrato y campos reales](../diseno/contrato-android-seguimiento-avisos.md).
[Evidencia física previa del seguimiento](../evidencia/iteracion-06/seguimiento-manual-22-11/README.md).
[Evidencia de notificaciones](../evidencia/iteracion-06/notificaciones-android-22-11/README.md).

El APK está preparado para la API local Wi-Fi. No se publicó un PR parcial de #63
ni se cerraron #63/#65 sin sus comprobaciones pendientes.