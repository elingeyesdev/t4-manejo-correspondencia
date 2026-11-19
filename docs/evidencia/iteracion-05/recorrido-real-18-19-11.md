# Nota interna: comprobación web, Android y Camunda

## Resultado y entorno

El recorrido completo **aprobó el 19/11/2026** en el emulador Android Studio
Medium_Phone, API 36, conectado a Laravel, PostgreSQL y Camunda **reales**.
Ejecutor: Codex en el equipo de Russel. Código funcional comprobado: `32b897e`,
sobre la rama del PR #52, que ya incorpora los PR #51 y #53.
Todos los usuarios, instituciones, notas e imágenes del ensayo son ficticios.

El servidor y el motor se ejecutaron localmente en Windows. Camunda 8.9.28 usó
el BPMN `nota_interna` del repositorio. Flutter requiere Dart 3.13.5 como mínimo.
El anfitrión usa hora de Bolivia y el emulador de estas capturas usa UTC.
La conexión PostgreSQL de Laravel usa UTC; Android convierte los instantes a la
zona horaria de su dispositivo.

**Recuperación tras reiniciar el proceso real: no acreditada en este corte;
se conservan las regresiones HTTP controladas. El ensayo adicional se detuvo
para priorizar el recorrido y la demostración manual. Comparación visual #48:
pendiente, separada del recorrido funcional aprobado.**

## Qué se probó entre web y Android

Las notas se crearon y emitieron mediante los formularios HTTP reales de la web,
con sesión y CSRF. El test posterior usa los widgets reales de Android y vuelve
a consultar formularios web durante el recorrido. Esto no se presenta como una
prueba manual completa del navegador. No se simularon las respuestas de Laravel
ni de Camunda en este recorrido.

1. **Envío directo:** emisión web, aparición en Por recibir, confirmación de
   recepción y atención desde Android, cierre web y consulta Cerrada en Android.
2. **Dos VÍAs:** el segundo revisor y el destinatario no pueden adelantarse.
   Primera y segunda conformidad desde Android, en orden. Después, recepción y
   atención en destino desde Android, reflejadas en la web.
3. **Derivación:** se envía a una tercera unidad desde la web. El responsable
   anterior se conserva hasta la recepción. El tercer funcionario recibe y
   atiende desde Android, y la web muestra el cambio de responsable.
4. **Adjuntos y respuesta:** una imagen ficticia se carga al mismo documento;
   web y Android descargan exactamente sus bytes y Android abre el visor. Se
   vincula una respuesta desde el formulario web y se comprueba su existencia.
5. **Cierre y Copias:** cierre web, estado Cerrada en Android, mismos IDs de
   nota, documento y hoja. La cuenta CC consulta su nota e historial sin botones
   de conformidad, recepción o atención. Cuando no tiene permiso sobre la hoja,
   el expediente queda deshabilitado con un aviso y la copia sigue visible.

Casos finales aprobados, registrados en [android-real-19-11.json](android-real-19-11.json):

- Directo: `01a1f40c-a814-70c9-b205-0fd2a876b27e`, CITE terminado en `000022`.
- Dos VÍAs: `01a1f40c-b338-71d8-a5a7-5f33d6c89218`, CITE terminado en `000023`.

La búsqueda REST del motor devolvió **una única instancia COMPLETED por nota**:
`2251799813690277` y `2251799813690287`, respectivamente. Véase
[camunda-android-real-19-11.json](camunda-android-real-19-11.json).
El cierre del motor se consultó directamente; no se dedujo sólo del mensaje móvil.

La comprobación cruzada final de
[comparacion-web-android-19-11.json](comparacion-web-android-19-11.json) aprobó
CITE, documento, hoja, estado y los **siete movimientos del historial** idénticos
entre los datos consultados en Android y el detalle HTML de la web: recepción,
atención, derivación, segunda recepción, segunda atención, respuesta y cierre.

Capturas del recorrido aprobado:

- [Mismo CITE cerrado en Android](dos_vias_cerrada_android.png).
- [Copia de consulta con expediente restringido](copia_solo_lectura_android.png).

La imagen es un dato generado para el ensayo: se comparó su descarga byte a byte
en ambos clientes y se abrió la pantalla del visor. Su captura fue prematura,
antes de la decodificación, y no se publica como prueba de imagen visible.
Esto **no acredita una captura física con la cámara**. La consulta del recurso SVG protegido
del QR comprueba su descarga, **no un escaneo físico**. No atribuir a esta
ejecución pruebas de hardware que no realizó.

## Fallos encontrados y corregidos

- **Atención con red demorada:** al cambiar los mensajes de carga se destruía
  el estado del formulario y el detalle podía quedar bloqueado después de guardar.
  Se conserva su identidad con una clave estable. La regresión reproduce una
  respuesta demorada y verifica el estado actualizado y un único POST.
- **CC con nota autorizada y hoja restringida:** un 403/404 de la hoja borraba
  también la nota que el servidor sí permitía consultar. Ahora se distinguen los
  permisos de ambos recursos, se conserva la copia y se deshabilita su expediente.
  Un 401 de sesión caducada sigue limpiando el detalle. Las regresiones 403/404
  fallaron antes de la corrección y aprobaron después; el caso real también pasó.
- **Horas PostgreSQL:** una sesión de base de datos en hora local reinterpretaba
  timestamps UTC sin offset y desplazaba el instante cuatro horas. Se fija la
  sesión PostgreSQL en UTC y se prueba la conservación del instante. No se
  modificaron retrospectivamente los registros de ensayo antiguos.
- **Cambio de cuenta web:** se incorporaron usuario, unidad y Cerrar sesión al
  encabezado de Nota Interna. Se reconstruyeron los recursos web que estaban viejos.

## Comprobaciones complementarias

El 18/11 se ejecutaron **14 comprobaciones API reales** de creación, emisión,
recepción repetida con la misma clave, rechazo de otra clave, una única recepción,
atención, derivación, cambio de responsable, respuesta y cierre. También se
rechazó un destino de otra institución. Resultado:
[recorrido-api-real-18-11.json](recorrido-api-real-18-11.json).
Su instancia real finalizada consta en [camunda-real-18-11.json](camunda-real-18-11.json).

Las **cuatro comprobaciones negativas reales** aprobaron: sin sesión 401;
segunda VÍA adelantada 404; CC intentando recibir en otra unidad 403; destino
de otra institución 422. Véase [permisos-api-real-18-11.json](permisos-api-real-18-11.json).
No se deshabilitaron autenticación, permisos ni límites de acceso.

Validación del código:

- Flutter: **151 pruebas aprobadas**, incluidas las integraciones anteriores
  con Laravel/PostgreSQL reales en la base aislada `correspondencia_test`.
- Regresiones focalizadas de notas y reintentos: **41 aprobadas**.
- Laravel: **102 pruebas, 811 aserciones aprobadas**; CI de GitHub aprobado
  para `32b897e`. Formato PHP, análisis Flutter y compilación web aprobados.
- Las regresiones `202 → 429 → reinicio → misma clave`, pérdida de respuesta y
  pérdida de permisos usan HTTP controlado en las pruebas unitarias. Distinguirlas
  del recorrido con motor real descrito arriba.
- Se adaptó el verificador de estado web para leer `data-state` del template
  institucional y conservar compatibilidad con el `<dd>` anterior. Sus cuatro
  casos aprobaron, incluido el rechazo de un estado incorrecto aunque otro texto
  de la página diga Cerrada. El recorrido integral publicado se ejecutó sobre
  el template anterior; la comprobación conjunta con #48 sigue pendiente.

## Reproducción y alcance pendiente

Los targets, requisitos y comandos están en
[movil/integration_test/README.md](../../../movil/integration_test/README.md).
Las credenciales de ensayo se proporcionan mediante un JSON local excluido de Git.
Las pruebas usan una clave separada para su sesión. Al finalizar se instala la
app normal sin las constantes privadas del ensayo.

La comparación visual #48 sigue pendiente: web y Android todavía no usan el mismo
template. Por prioridad acordada, esa comparación se completa con el PR de Mathew;
no se presenta aquí como aprobada ni se marcan todos los criterios de #46/#47
como cumplidos. Firma, sello y notificaciones Firebase no se implementan ni se
acreditan con este ensayo.
