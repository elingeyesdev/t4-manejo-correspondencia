# Tarea 9 — Flujo web actualizado, Iteración 04

Actor: recepción o responsable activo; administración prepara unidades y cuentas. La web usa Sakai/Vue para presentar controles y Laravel para sesión, permisos, validación y transacciones. PostgreSQL conserva documento, hoja y movimientos. La foto se guarda cifrada en almacenamiento privado; PostgreSQL guarda su referencia. Respuesta y cierre se operan desde web.

Este diagrama editable actualiza el recorrido previsto del documento de Tarea 9 del 04/11/2026. No modifica ni sustituye silenciosamente ese PDF. Código web de referencia: PR #39, `feb6011`, más las confirmaciones del PR #40, `eb35321`.

```mermaid
flowchart TD
  A([Usuario abre la web]) --> B[Acceso: correo y contraseña / Ingresar]
  B --> C{Laravel acepta sesión y cuenta habilitada?}
  C -- No --> D[Mostrar error y volver a Acceso]
  D --> B
  C -- Sí --> E[Documentos: seleccionar Ver detalle]
  E --> F{Documento autorizado?}
  F -- No --> G[Recurso no disponible / volver a Documentos]
  G --> E
  F -- Sí --> H[Detalle: datos, hoja, QR, historial y adjuntos]
  H --> I{Acción permitida y estado vigente?}
  I -- Solo consulta o CERRADA --> J[Consultar expediente y descargar adjuntos autorizados]
  I -- Derivar --> K[Derivar hoja: unidad habilitada y motivo / Derivar]
  K --> W{Laravel valida versión y permiso}
  W -- Sí --> L[Transacción: PENDIENTE_RECEPCION, conservar responsable de origen]
  L --> H
  I -- Recibir --> M[Funcionario de destino / Confirmar recepción]
  M --> W2{Destino y versión vigentes?}
  W2 -- Sí --> N[RECIBIDA: asignar responsable y unidad de destino]
  N --> H
  I -- Atender --> O[Registrar atención: observación / Guardar atención]
  O --> W3{Observación de 1 a 2000 puntos y versión válidas?}
  W3 -- Sí --> P[EN_ATENCION: guardar autor, hora y observación]
  P --> H
  I -- Responder --> Q[Vincular respuesta: remitente, asunto, fecha, tipo y prioridad]
  Q --> R[Guardar respuesta: ID propio y vínculo al original, conservar estado]
  R --> H
  I -- Cerrar --> S[Cerrar expediente: motivo y marcar Confirmo el cierre]
  S --> T{Confirmación, versión y estado válidos, sin recepción pendiente?}
  T -- Sí --> U[CERRADA: guardar un único cierre y conservar consulta e historial]
  U --> H
  W -- No --> V[Mostrar error, conservar borrador y refrescar situación]
  W2 -- No --> V
  W3 -- No --> V
  T -- No --> V
  R -. Error confirmado .-> V
  V --> H
  H --> X{Agregar archivo opcional?}
  X -- Sí --> Y[Selecciona un archivo / Subir archivo: PDF, JPG o PNG hasta 10 MiB]
  Y --> Z{Permiso, estado y archivo válidos?}
  Z -- Sí --> AA[Cifrar y guardar; presentar Ver y Descargar]
  AA --> H
  Z -- No --> V
  H --> AB[Consultar hoja de ruta o escanear QR desde Android]
  AB --> H
```

- El QR es una lectura: no recibe ni modifica el expediente.
- Cada escritura de recorrido envía versión y clave de solicitud; un reintento conserva la misma intención y recupera su resultado. Un conflicto exige refrescar antes de una nueva intención.
- Si se pierde una respuesta, no se asume éxito: consultar el detalle y recuperar el resultado de la misma solicitud. No generar otro registro por una respuesta incierta.
- El alta inicial está en Nueva correspondencia: datos obligatorios, validación Laravel y guardado atómico de documento y hoja. Los errores retornan al formulario; un reintento del mismo alta usa su misma clave.
- No se ofrecen destinos si no hay otra unidad habilitada. El detalle solo presenta acciones autorizadas; el servidor vuelve a validarlas.

Implementación: `web/resources/views/documents/show.blade.php`, `web/resources/js/sakai/DocumentDetail.vue`, `web/resources/js/sakai/SakaiForm.vue`, `web/app/Services/RouteSheetWorkflow.php` y `web/routes/web.php`.

Las confirmaciones del servidor aparecen como aviso visible de éxito. Al consultar una hoja CERRADA se conserva además el mensaje Expediente cerrado, incluso después de volver a abrirla. Vincular una respuesta conserva el estado de la hoja; cerrar es una acción explícita diferente.
