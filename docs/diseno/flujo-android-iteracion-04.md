# Tarea 9 — Flujo Android actualizado, Iteración 04

Actor: recepción para registrar/derivar y funcionario de la unidad de destino para recibir/atender. Flutter presenta formularios, permisos y cámara; HTTP transporta solicitudes con token a Laravel; Laravel valida autorización y confirma datos de PostgreSQL. Android no accede directamente a la base. Se mantiene el estilo Sakai.

Este diagrama editable separa el flujo móvil del flujo web de la Tarea 9. Código de referencia: rama `feature/33-recorrido-android`, implementación móvil `2f9f6bf`, versión de entrega `eb3532153640973bfe787a32ab534602e6649c5b`, PR #40.

```mermaid
flowchart TD
  A([Abrir Android]) --> B[Acceso: correo y contraseña / Iniciar sesión]
  B --> C{Sesión aceptada por Laravel?}
  C -- No --> D[Mostrar error de acceso o conexión / volver a intentar]
  D --> B
  C -- Sí --> E[Mi bandeja: documentos autorizados]
  E --> F{Localizar documento}
  F -- Bandeja --> G[Abrir documento]
  F -- QR --> H[Escanear QR de hoja de ruta / Abrir cámara para escanear]
  H --> I{Permiso de cámara?}
  I -- No --> J[Mostrar explicación, ajustes si bloqueo permanente o pegar enlace]
  J --> K[Enlace o identificador de la hoja / Abrir hoja]
  I -- Sí --> K2[Leer QR con la cámara]
  K2 --> L{Referencia QR válida?}
  K --> L
  L -- No --> M[Mostrar QR inválido / volver a localizar]
  M --> E
  L -- Sí --> G
  G --> N{API autoriza consultar documento?}
  N -- No --> O[No disponible o sin sesión / regresar a bandeja o Acceso]
  O --> E
  N -- Sí --> P[Detalle: estado, responsable, unidad, historial y fotos]
  P --> Q{Acciones que indica Laravel}
  Q -- Derivar --> R[Derivar hoja: elegir unidad, escribir motivo / Derivar]
  Q -- Recibir --> S[Confirmar recepción / confirmar el aviso explícito]
  Q -- Atender --> T[Registrar atención: observación / Guardar atención]
  R --> U[Enviar versión y clave de la solicitud]
  S --> U
  T --> U
  U --> V{Respuesta confirmada?}
  V -- Éxito --> W[Refrescar estado, responsable e historial desde Laravel]
  W --> W2[Confirmación visible; Realizar otra acción si hay continuación permitida]
  W2 --> P
  V -- Conflicto --> X[Recargar situación; conservar texto y revisar antes de nueva intención]
  X --> P
  V -- Sesión vencida --> B
  V -- Permiso denegado --> Y[Mostrar rechazo y refrescar el documento]
  Y --> P
  V -- Sin respuesta o error incierto --> Z[Conservar cuerpo y clave / Reintentar confirmación]
  Z --> U
  Q -- Solo consulta o CERRADA --> AA[Ver datos, historial y archivos; sin botones de escritura]
  P --> AB{Adjuntar foto con autorización?}
  AB -- Sí --> AC[Tomar foto: solicitar permiso, consejos, vista previa y usar o repetir]
  AC --> AD{Foto aceptada?}
  AD -- No --> P
  AD -- Sí --> AE[Subir foto al documento existente]
  AE --> AF{Resultado?}
  AF -- Guardada --> P
  AF -- Rechazo confirmado --> AG[Conservar foto y corregir; reintentar solo archivo]
  AG --> AE
  AF -- Incierto --> AH[Comprobar subida: consultar y comparar nombre, MIME, tamaño y bytes]
  AH -- Encontrada --> P
  AH -- No confirmado --> AH
```

- Abrir por QR no envía recepción ni otro movimiento.
- Derivar mantiene la responsabilidad de origen hasta la recepción. Recibir asigna responsable y unidad; atender agrega una observación con hora del servidor.
- La atención y la foto son operaciones separadas. Una foto fallida no vuelve a guardar atención. Mientras una foto es incierta, se comprueba su existencia sin reenviarla.
- Atrás bloquea la salida durante una operación y pide confirmación si hay foto o solicitud pendiente. Una pérdida de conexión no se presenta como éxito.
- Responder y cerrar se hacen desde web; Android actualiza el mismo expediente y muestra CERRADA en consulta. No se implementan esos formularios en Android en el #33.

Implementación: `movil/lib/funciones/mi_bandeja/`, `movil/lib/funciones/qr/`, `movil/lib/funciones/recorrido/`, `movil/lib/funciones/camara/`, `movil/lib/funciones/adjuntos/` y `movil/lib/compartido/api/laravel_api.dart`.

Tras una atención, la continuación se presenta como Agregar otra atención para distinguir una nueva observación de un reintento. Los bocetos se retiraron del menú operativo.
