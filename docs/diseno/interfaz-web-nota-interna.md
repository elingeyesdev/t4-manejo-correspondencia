# Interfaz institucional web de Correspondencia

Issue #48 · Iteración 05

## Plantilla y alcance

Las pantallas de acceso, Documentos, Nota Interna, Administración y errores usan el ejemplo oficial [Navbar Static de Bootstrap 5.3.8](https://getbootstrap.com/docs/5.3/examples/navbar-static/). La plantilla conserva su estructura de navegación superior, marca, enlaces y contenedor principal. Usa los componentes de Bootstrap para tablas, pestañas, formularios, avisos y botones. Las hojas de estilo se sirven desde el propio repositorio, con la [licencia MIT](../../web/public/vendor/bootstrap-5.3.8/LICENSE). Laravel renderiza las tablas y los formularios desde Blade. Los controles nativos funcionan sin JavaScript. El script local añade validaciones de archivo y evita dobles envíos.

La cabecera compartida usa la bandera departamental verde, blanco y verde, con proporción de 22:15 y franjas iguales, según los artículos 9 y 10 de la [Ley Departamental 109](https://gacetaoficial.santacruz.gob.bo/verpdf/ley-departamental-109). El verde digital de la bandera es una aproximación visual a Pantone 356 C. El detalle de documentos mantiene los enlaces al QR, el historial, los adjuntos y las acciones autorizadas de la hoja de ruta. Administración conserva los formularios de unidades, catálogos y usuarios.

## Referencia para Android

| Elemento | Criterio web |
| --- | --- |
| Color y jerarquía | Fondo blanco, texto `#171A18`, verde `#12682A` para el CITE y la acción primaria, líneas `#D4D8D5`. La cabecera web usa el verde `#20B72C` en un filete y lleva la bandera junto al nombre. |
| Tipografía y medidas | Tipografía de sistema, cuerpo de 15 px, títulos de sección de 17 px, espaciado regular y bordes de 1 px. |
| Bandeja | CITE, asunto, origen, destino, fecha y estado. El asunto abre el detalle. En pantallas estrechas la tabla tiene desplazamiento propio. |
| Formulario | DE, A, asunto, referencia y cuerpo. VÍA mantiene el orden de los revisores y CC permite selección múltiple. |
| Detalle | El asunto, el CITE y el estado encabezan la nota. Se muestran la unidad actual, la siguiente acción autorizada y el historial. |
| Accesibilidad | Foco visible, campo asociado a su etiqueta y errores vinculados al control cuando corresponda. El estado se identifica por texto. |

Web y Android comparten colores de acción, bordes finos y nombres de estados. Android adapta la bandeja a filas compactas. La revisión cruzada de ambos canales con el mismo expediente corresponde al #47.

## Evidencias con datos ficticios

- [Acceso](../evidencia/iteracion-05/web-acceso.png)
- [Correspondencia registrada](../evidencia/iteracion-05/web-documentos.png)
- [Registro documental](../evidencia/iteracion-05/web-documento-registro.png)
- [Detalle documental, hoja de ruta y adjuntos](../evidencia/iteracion-05/web-documento-detalle.png)
- [Administración](../evidencia/iteracion-05/web-administracion.png)
- [Bandeja de Nota Interna](../evidencia/iteracion-05/web-nota-bandeja.png)
- [Formulario de Nota Interna](../evidencia/iteracion-05/web-nota-formulario.png)
- [Detalle de Nota Interna](../evidencia/iteracion-05/web-nota-detalle.png)
- [Página de error](../evidencia/iteracion-05/web-respuesta-error.png)

Las capturas muestran vistas Blade renderizadas por Laravel sobre una base SQLite de pruebas. La revisión cruzada y el recorrido conjunto con Android y Camunda se registran en GitHub cuando se realicen.

Se verificaron las nueve vistas en Chromium a 1366 y 390 px. En ambos anchos aparece la cabecera institucional y las tablas anchas se desplazan dentro de su propio contenedor. La suite de Laravel cubre el acceso, los permisos por rol, el registro, los movimientos, las respuestas y los adjuntos. Para repetirla, ejecuta `php artisan test` desde `web/` con la configuración de pruebas.
