# Diseño Android para revisión

Entrega de diseño de la actividad C del PDF; referencia: Issue #6 del repositorio
oficial. Flutter contiene el recorrido visual; no se acredita la implementación
del backend, autenticación ni operaciones documentales de futuras iteraciones.

## Recorrido y evidencia

Abrir la app en Android. Inicio contiene **Consultar envío**, **Nueva
correspondencia** y **Gestión documental**. La consulta usa el servicio real.
El registro usa ahora Laravel desde Nueva correspondencia. Acceso, Mi bandeja y detalle también tienen implementación real separada del diseño.
Gestión documental contiene los diseños del recorrido institucional, con una
indicación compacta de conexión pendiente. Sus datos son referencias de diseño.

Acceso → Abrir bandeja → Ver documento → Confirmar recepción → Revisar recepción
→ Continuar recorrido → Detalle. Desde el detalle recibido se puede revisar
captura, atención o derivación. El aviso de cada confirmación aclara que no se
envían cambios al servidor. No se generan recibos ni correlativos de guardado.

El menú **Secciones** permite recorrer todas las pantallas. El botón de ajustes
**Revisar pantallas** agrupa los estados de error, navegación de revisión y el
requisito asociado a la pantalla. No forma parte de los formularios de trabajo.

## Pantallas y criterios representados

- Acceso: HU-02 / CU-01. Usuario y contraseña, acceso pendiente de conexión y
  sesión vencida. No verifica identidad ni crea o conserva una sesión.
- Bandeja y detalle: HU-12 / CU-08. Documento y hoja con códigos separados,
  responsable activo, destino pendiente, estado e historial cronológico.
- Adjuntos y captura: HU-07 / CU-04. Vista del archivo, encuadre,
  previsualización, repetir y confirmar. No utiliza cámara ni sube archivos.
- QR y recepción: HU-10 / CU-06. Localizar no confirma recepción. Una acción
  explícita separada representa el cambio de responsable. No valida permisos
  reales, no lee QR y no crea movimientos en el servidor.
- Atención: HU-11 / CU-07. Observación obligatoria; el recorrido solo la permite
  después de recibir y cuando no existe otra recepción pendiente.
- Derivación: HU-09 / CU-05. Destino y motivo, revisión antes de continuar,
  responsable anterior conservado hasta la recepción del destino. No se envía.

## Estados para revisar

En **Revisar pantallas** seleccionar sesión vencida, falta de conexión,
cámara sin permiso, bandeja vacía, falta de autorización o documento actualizado.
Los textos de observación y motivo se conservan al cambiar de estado. Para
mostrar cámara sin permiso, abrir Capturar documento o Localizar por QR.
Para el conflicto, seleccionar Documento actualizado y revisar una recepción u
operación permitida. No se registra el cambio en ese caso.

## Estilo y límites

Verde institucional, fondo neutro, superficies blancas, bordes suaves, tipografía
jerarquizada y Material Icons. La guía real no se rellena ni se sugiere con un
código ficticio. No hay métricas, usuarios autenticados o resultados de búsqueda
inventados en Inicio. El contenido está pensado para desplazamiento vertical y
controles accesibles en pantalla pequeña.

## Revisión pendiente

- Mathew debe recorrer las pantallas y registrar observaciones y correcciones.
- Ambos deben revisar la adaptación Laravel y el endpoint local de opciones de registro.
- La entrega se publica para revisión por PR; falta la aprobación de Mathew.
- No se marca el Issue #6 como terminado ni se simula una aprobación.

Pruebas de interfaz verifican navegación, validaciones, recepción separada del
QR, previsualización antes de confirmar, errores y ausencia de solicitudes desde
el recorrido visual. Esto no sustituye pruebas de integración futuras con la API.
