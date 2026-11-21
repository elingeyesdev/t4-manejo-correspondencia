# Prueba manual — teléfono y web

Preparada el 21/11/2026 para la rama local `codex/46-cierre-institucional`.
No se publica ni cierra #46/#47 sólo por tener esta guía.

## Antes de comenzar

- Mantener el teléfono conectado por USB a esta computadora y la app instalada
  en esta sesión. Está configurada para acceder al servidor por el cable.
  Desconectar el cable interrumpe esta conexión; el modo Wi-Fi requiere otra
  configuración y no está comprobado por este ensayo.
- Abrir en la computadora <http://127.0.0.1:8000/acceso>.
- Usar el correo completo y la contraseña de cada cuenta. No cambiar claves ni
  compartirlas para hacer la prueba. Cada cambio de actor requiere cerrar sesión
  y entrar con la cuenta correspondiente; una sola cuenta no representa todos
  los funcionarios.
- Elegir cuentas habilitadas que se puedan usar: emisor, revisor VÍA, funcionario
  de la unidad destinataria y persona con CC. Para dos VÍAs hacen falta dos
  revisores distintos. Usar una nota de prueba y contenido ficticio.

## 1. Acceso y diseño general

En el teléfono, iniciar sesión. Debe abrir Inicio. En la web, entrar con la misma
cuenta. Ambos deben identificar al mismo usuario. Un mensaje de contraseña o
cuenta inválida significa que no se inició sesión; no continuar como si hubiera
entrado. Revisar el correo completo y la cuenta habilitada sin revelar la clave.

Recorrer Inicio, Bandeja, Consulta, Cuenta y, con una cuenta autorizada, Nueva
correspondencia. Abrir un detalle, QR, cámara y un adjunto cuando correspondan.
La cabecera debe ser blanca con bandera verde/blanco/verde de Santa Cruz y
filete verde. Botones, campos, textos y bordes deben conservar el mismo estilo;
no debe volver el diseño anterior al cambiar de pantalla. Los permisos de la
cámara y el visor externo de PDF son pantallas del sistema operativo.

## 2. Emitir una nota desde web

Importante: **Registrar → Tipo: Nota Interna** crea correspondencia en Documentos;
no emite una nota con CITE para las bandejas de revisión. Ese documento se
consulta en **Bandeja**, usando Actualizar si se creó mientras estaba abierta.
Para ensayar este flujo, entrar específicamente en **Nota Interna → Nueva nota**.

Entrar como emisor. Ir a **Nota Interna → Nueva nota**. Completar **A · Unidad
destinataria**, asunto y cuerpo. En **VÍA · Orden de revisión**, seleccionar el
revisor cuya cuenta se utilizará en el teléfono. Agregar una persona en **CC**.
Guardar borrador, revisar el contenido y pulsar **Emitir**.

Debe generarse un CITE y quedar pendiente de revisión. Anotar el CITE completo:
identificará este mismo caso durante todo el recorrido. Guardar un borrador por
sí solo no envía la nota a las bandejas de los demás.

## 3. Dar conformidad desde Android

Cerrar sesión y entrar en el teléfono como la persona elegida en VÍA. Ir a
**Inicio → Notas internas → Por revisar**. Buscar el CITE, abrirlo y pulsar
**Dar conformidad**; confirmar una sola vez y esperar el resultado.

Al actualizar la web, esa revisión debe figurar en el historial. Con dos VÍAs,
el segundo revisor sólo puede actuar después del primero; hasta entonces no
debe poder adelantarse. Tras la última conformidad, debe aparecer
**Pendiente de recepción**. Conformidad no equivale a recepción.

## 4. Recibir en la unidad destinataria

Entrar en Android con un funcionario de la unidad elegida en A. Abrir
**Inicio → Notas internas → Por recibir**, seleccionar el mismo CITE, pulsar
**Confirmar recepción** y aceptar la confirmación.

Debe aparecer **Recibida**, el movimiento y la hoja vinculada. Actualizar la
misma nota en web: debe mostrar el mismo CITE, estado y registro de recepción.
La nota sale de Por recibir; consultar Por atender. Recibir de nuevo no debe
crear otra hoja ni otro CITE.

## 5. Registrar atención

En el teléfono, abrir la nota desde **Por atender**. Usar la acción disponible
de atención; si aparece **Ver expediente y adjuntos**, abre el documento y allí
pulsa **Registrar atención**. Completar la observación y guardar.

Debe confirmarse el resultado y quedar **En atención** en el móvil y, al
actualizar, en la web. El historial debe conservar lo anterior y agregar la
atención. Registrar atención no cierra el trámite.

## 6. Derivación, fotografía, respuesta y cierre

En la hoja web, derivar el expediente a otra unidad habilitada. Con una cuenta
de esa unidad en Android, recibir y registrar atención. Debe conservar el mismo
CITE y la misma hoja, con los nuevos movimientos y el responsable correspondiente.

Con una cuenta que pueda adjuntar, abrir el expediente en Android, tomar una
foto ficticia, revisarla y confirmar su uso/subida. Debe poder abrirse la misma
foto desde móvil y web. Cancelar una foto no debe adjuntarla. Probar también
el QR de la hoja con una cuenta autorizada: debe abrir esa misma hoja y no
confirmar una recepción automáticamente.

Desde web, registrar/vincular una respuesta según las acciones de la hoja y
realizar el cierre con una cuenta autorizada. Actualizar Android: debe aparecer
**Cerrada**, con la respuesta, adjuntos autorizados e historial conservados.

## 7. Copias y restricciones

Entrar como la persona seleccionada en CC y abrir **Copias**. Debe ver la misma
nota, sin poder dar conformidad, recibir ni atender por tener únicamente copia.
Una cuenta ajena al recorrido y sin CC no debe poder consultar/actuar sobre esa
nota. La ausencia de permiso sobre el expediente vinculado no debe borrar una
nota que sí está autorizada como copia.

Repetir con otra nota sin VÍAs: al emitir desde web debe pasar directamente a
**Por recibir** para la unidad destinataria, sin exigir conformidades.

## 8. Corte de conexión y reintento

Usar otro caso de prueba. Cortar el USB antes de confirmar una acción: no debe
anunciar éxito. Reconectar, reactivar la conexión USB y actualizar/reintentar.
Comprobar en web que existe un solo resultado y que no se duplica la recepción.

Un corte antes del envío no demuestra el caso en que el servidor recibió la
acción y se perdió la respuesta. Ese segundo escenario necesita registrarse
por separado: misma cuenta, misma nota y misma acción al reabrir; conservar el
intento pendiente, consultar su estado y evitar una segunda ejecución.

## Comparación visual y registro del resultado

Abrir la bandeja y el detalle del **mismo CITE** en ambos clientes, con la misma
cuenta y después de actualizar. Comparar asunto, origen, destino, fecha, estado,
historial y acciones según los permisos. La web usa tabla y el teléfono filas:
los datos deben coincidir aunque se acomoden distinto.

Guardar cuatro capturas ficticias: bandeja web, bandeja móvil, detalle web y
detalle móvil. Anotar fecha, teléfono, versión local, CITE y resultado de cada
paso. Marcar como pendiente lo que no se haya realizado; no sustituir una prueba
fallida por capturas de otra nota o de un boceto.

Estado inicial de esta sesión: instalación correcta, proceso Android iniciado,
conexión USB configurada y accesos móvil y web confirmados por Russel. El resto se
completa con los resultados observados durante este ensayo.
