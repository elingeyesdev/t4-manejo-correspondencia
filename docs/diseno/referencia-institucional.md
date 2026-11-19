# Referencia institucional compartida — #46 y #48

Propuesta elegida por Russel el 18/11/2026 para la nota interna. Implementada
localmente en Flutter; la equivalencia con la web requiere la revisión cruzada
del #48. No implica que ese issue ya esté implementado o cerrado.

## Procedencia

La página https://www.tiendanube.com/blog/diseno-de-paginas-web/ se utilizó como
inspiración para una cabecera sencilla, texto legible y fondo blanco. No se
descargó una plantilla de esa página. Los bocetos se prepararon con asistencia
de IA y la interfaz Android se implementó con componentes nativos de Flutter.
La paleta verde fue elegida por Russel. No se presenta como identidad oficial
aprobada por el Concejo Municipal.

## Paleta y componentes

- Cabecera: **#20B72C**, con texto e iconos **#171A18**. No usar letras blancas
  sobre ese verde claro.
- Acciones y CITE: **#12682A**. El botón principal lleva letras blancas.
- Fondo: **#FFFFFF**. Texto principal: **#171A18**; secundario: **#555B57**.
- Separadores: **#D4D8D5**, de 1 px. Estados neutros: fondo **#F0F2F0**.
- Error: **#B42318**, acompañado de un mensaje. El color no reemplaza la etiqueta.
- Tipografía: Roboto en Android; tipografía de sistema en web. Título de pantalla
  20–23 px, título de fila 17 px, cuerpo 14–16 px y metadatos 12 px.
- Separaciones base: 4, 8, 12, 16 y 20 px. Bordes de controles de 4 px.
- Acciones táctiles de al menos 48 px, foco visible y texto ampliable.

## Bandeja y detalle

La bandeja usa filas, separadas por líneas finas: CITE, asunto, unidad de origen,
fecha, estado y acción. La búsqueda indica que filtra sólo las notas ya cargadas.
Conserva las cuatro bandejas y la paginación. El detalle destaca CITE, asunto y
estado; separa datos, contenido e historial. La conformidad o primera recepción
queda al pie para mantener la acción visible sin ocultar el contenido al ampliar
el texto. Copias conserva sólo consulta.

No se añaden datos de VÍA, CC ni adjuntos inexistentes para reproducir un boceto:
se muestran únicamente los datos y permisos que devuelve la API. Las fotos se
consultan en el expediente una vez disponible la vinculación correspondiente.

## Evidencia local

Las imágenes en `docs/evidencia/iteracion-05/` se renderizan desde las pantallas
Flutter y contienen exclusivamente datos ficticios de pruebas. No son capturas
de un teléfono ni acreditan la conexión a Laravel/Camunda. Se generaron con:

`flutter test test/notas_institucional_test.dart --dart-define=CAPTURAR_INSTITUCIONAL=true`

El #47 deberá comparar estas pantallas con la web del #48 durante el recorrido
real. Las pantallas históricas de correspondencia conservan su estilo previo;
esta sustitución se aplica a Notas Internas, conforme al alcance del #48.
