# Iteración 05 — Android y recorrido compartido

## Resultado del 21/11/2026

Los criterios de #46/#47 se verificaron en un teléfono Android físico conectado
a Laravel, PostgreSQL y Camunda reales. El [informe final con capturas y
resultados](../evidencia/iteracion-05/cierre-21-11.md) consolida la validación.

- Android usa el diseño institucional en acceso, inicio, navegación, cuenta,
  registro, documentos, consulta, cámara, QR, adjuntos y notas internas.
- Notas internas tiene entrada directa en Inicio, menú y Bandeja, con Por
  revisar, Por recibir, Por atender y Copias. La bandeja de documentos se
  actualiza al volver a su sección.
- Se verificaron emisión web, revisión en orden, recepción y atención Android,
  derivación a otra unidad, respuesta y cierre web, y consulta final en Android.
- Una respuesta interrumpida conservó el intento en almacenamiento seguro y se
  concilió al recrear la pantalla sin repetir la recepción.
- Se compararon capturas reales de bandeja y detalle del mismo CITE, cuenta CC
  y estado Cerrada, con paleta y campos coherentes en web y móvil.
- Se comprobaron permisos, rechazo a otra institución, adjuntos y QR protegido.

Validación: **157 pruebas Flutter**, **104 pruebas Laravel y 852 aserciones**,
análisis Dart, formato y Pint aprobados. El recorrido real y las capturas se
verificaron por separado de las suites habituales. El informe distingue la
interrupción controlada del transporte de un reinicio del sistema operativo.

Todos los expedientes e imágenes del ensayo son ficticios. Los parámetros con
contraseñas y los APK de integración quedan fuera de Git. Al finalizar se
restauró la aplicación normal en el teléfono.

## Reproducción

La [guía manual](prueba-manual-telefono-web.md) explica dónde tocar y qué debe
ocurrir. Los [targets de integración](../../movil/integration_test/README.md)
permiten repetir el ensayo con cuentas y notas ficticias nuevas.

La nueva línea de tiempo y los cambios posteriores solicitados por Yasmani se
tramitan como trabajo posterior a esta iteración; no se atribuyen a #46/#47.