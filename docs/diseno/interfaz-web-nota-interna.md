# Interfaz institucional web de Nota Interna

Issue #48 · Iteración 05

## Plantilla y alcance

Las vistas de bandeja, borrador y detalle usan el ejemplo oficial [Navbar Static de Bootstrap 5.3.8](https://getbootstrap.com/docs/5.3/examples/navbar-static/). La plantilla conserva su estructura de navegación superior, marca, enlaces y contenedor principal. Usa los componentes de Bootstrap para tablas, pestañas, formularios, avisos y botones. Las hojas de estilo se sirven desde el propio repositorio, con la [licencia MIT](../../web/public/vendor/bootstrap-5.3.8/LICENSE). El módulo funciona sin JavaScript para la navegación y los formularios.

La cabecera de Nota Interna usa la bandera departamental verde, blanco y verde, con proporción de 22:15 y franjas iguales, según los artículos 9 y 10 de la [Ley Departamental 109](https://gacetaoficial.santacruz.gob.bo/verpdf/ley-departamental-109). El verde digital de la bandera es una aproximación visual a Pantone 356 C. Documentos y las demás pantallas históricas conservan su plantilla Sakai.

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

- [Bandeja](../evidencia/iteracion-05/web-nota-bandeja.png)
- [Formulario](../evidencia/iteracion-05/web-nota-formulario.png)
- [Detalle](../evidencia/iteracion-05/web-nota-detalle.png)

Las capturas muestran vistas Blade renderizadas por Laravel sobre una base SQLite de pruebas. La revisión cruzada y el recorrido conjunto con Android y Camunda se registran en GitHub cuando se realicen.

Se verificaron las tres vistas en Chromium a 1366 y 390 px. En ambos anchos cargan las dos hojas de estilo locales, se puede iniciar la navegación por teclado desde el enlace de salto y el formulario permite desplegar y ocultar revisores adicionales. Para repetir la validación funcional, ejecuta `php artisan test` desde `web/` con la configuración de pruebas.
