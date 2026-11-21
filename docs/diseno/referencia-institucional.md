# Referencia institucional compartida — #46 y #48

La propuesta del 18/11 se actualiza localmente el 21/11/2026 con la referencia
del PR #54, integrado en `develop` como `4da6559`. La implementación Flutter
se desarrolla en `codex/46-cierre-institucional`. El 21/11 se extendió el tema
a toda la aplicación y se completó la comparación de bandeja y detalle del mismo
CITE en web y teléfono. El [informe final](../evidencia/iteracion-05/cierre-21-11.md)
incluye las cuatro capturas de la aplicación en ejecución.

## Procedencia

Los bocetos iniciales usaron Tiendanube como inspiración. La referencia vigente
es [la plantilla web de Mathew](interfaz-web-nota-interna.md), basada en Bootstrap
5.3.8 Navbar Static. Flutter reproduce su lenguaje visual con componentes
nativos; no utiliza Bootstrap. La identidad sigue siendo la del prototipo
académico, sin atribuir aprobación institucional al Concejo.

## Paleta y componentes

- Cabecera blanca, bandera verde/blanco/verde **#006B2E**, proporción 22:15,
  filete **#20B72C**, texto e iconos **#171A18**.
- Acciones y CITE: **#12682A**. El botón principal lleva letras blancas.
- Fondo: **#FFFFFF**. Texto principal: **#171A18**; secundario: **#555B57**.
- Separadores: **#D4D8D5**, de 1 px. Estados neutros: fondo **#F0F2F0**.
- Error: **#941E15**, acompañado de un mensaje. El color no reemplaza la etiqueta.
- Pendientes: fondo **#FBF5E4**, borde **#E4D3A4**, texto **#654A13**.
- Recibida/en atención: fondo **#EAF4ED**, borde **#C4DCCC**, texto **#174E2B**.
- Tipografía: Roboto en Android; tipografía de sistema en web. Título de pantalla
  20–21 px, título de fila 17 px, cuerpo 15 px y metadatos 12 px.
- Separaciones base: 4, 8, 12, 16 y 20 px. Bordes de controles de 4 px.
- Acciones táctiles de al menos 48 px, foco visible y texto ampliable.

## Bandeja y detalle

La bandeja usa filas, separadas por líneas finas: CITE, asunto, unidad de origen,
unidad destinataria, fecha, estado y acción. La API añade `unidad_destinataria`
sin alterar los campos anteriores; el detalle añade `autor` para mostrar DE.
La búsqueda indica que filtra sólo las notas ya cargadas.
Conserva las cuatro bandejas y la paginación. El detalle destaca asunto, CITE y
estado; separa datos, contenido e historial. La conformidad o primera recepción
queda al pie para mantener la acción visible sin ocultar el contenido al ampliar
el texto. Copias conserva sólo consulta.

No se añaden datos de VÍA, CC ni adjuntos inexistentes para reproducir un boceto:
se muestran únicamente los datos y permisos que devuelve la API. Las fotos se
consultan en el expediente una vez disponible la vinculación correspondiente.

## Evidencia

Las capturas finales en `docs/evidencia/iteracion-05/cierre-21-11/` proceden de
la aplicación en el teléfono físico y de la web en un navegador de pruebas.
Comparten el CITE terminado en 000029, cuenta CC y estado Cerrada. El render
optativo de widgets sigue disponible como apoyo de desarrollo mediante:

`flutter test test/notas_institucional_test.dart --dart-define=CAPTURAR_INSTITUCIONAL=true`

Los borradores de `.local/pendiente-visual-46/` fueron sustituidos por las
capturas reales de cierre. El 21/11, por pedido de Russel, la identidad se aplica también
al acceso, inicio, navegación y cuenta, registro, documentos, consulta, cámara,
QR y adjuntos. Todas las rutas utilizan la misma cabecera y el tema raíz; los
componentes heredados reciben la paleta institucional mediante un adaptador.
Se conservan las licencias de los iconos y recursos de terceros.
