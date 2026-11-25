# Prueba final con Mathew

Validación del 24 de noviembre de 2026. El ingreso HTTPS al servidor se comprobó en el teléfono físico. El usuario confirmó el uso sin USB y posteriormente informó que el recorrido final con Mathew funcionó correctamente.

La evidencia distingue las comprobaciones observadas directamente de la confirmación manual del usuario. El [resultado del piloto](../evidencia/iteracion-06/piloto-https-24-11/resultado.json) identifica la APK, el certificado, el entorno y el alcance de cada resultado. La [constancia de entrega](../evidencia/iteracion-06/piloto-https-24-11/README.md) reúne el cierre comunicado por el usuario.

## Llevar

- Teléfono cargado y APK candidata guardada también fuera del teléfono.
- Computadora de Mathew con Ubuntu Server, Nginx, web, base de datos, Camunda y envío de avisos funcionando.
- Cuentas ficticias en ese servidor: remitente, dos autoridades VÍA diferentes, recepción inicial y recepción de una segunda unidad.
- Dos notas nuevas de prueba. No reutilizar una nota ya cerrada.

## Antes del encuentro

La dirección del piloto del 24 de noviembre es `https://172.20.10.3:18443`, en el punto de acceso de Mathew. La APK `Correspondencia-Piloto-HTTPS-24.apk` utiliza la autoridad pública que entregó Mathew, limitada a ese origen. La huella y la compilación se describen en [HTTPS del piloto en Android](../operacion/piloto-https-android.md). Si cambia la dirección, hay que preparar otra compilación y comprobar su certificado.

La configuración Android y el servidor deben usar el mismo proyecto Firebase: `correspondencia-univalle`. Mathew configura sus credenciales privadas en el servidor; no se incluyen en la APK ni en este documento.

## Al llegar

1. Conectar teléfono y servidor a una red que permita que se comuniquen. El Wi-Fi de invitados de la universidad puede impedir el acceso entre dispositivos.
2. Abrir la APK preparada para ese servidor e iniciar sesión con una cuenta del piloto. Confirmar que llega a Inicio antes de comenzar el recorrido. La autoridad del piloto está configurada dentro de Correspondencia y el navegador tiene su propia configuración de confianza.
3. Confirmar que el servidor tiene la versión final de develop, incluido el PR73.
4. Instalar la APK candidata como actualización, sin desinstalar la app actual.
5. Desconectar el cable USB y mantenerlo desconectado durante la prueba.
6. Cerrar la sesión anterior e iniciar sesión con una cuenta existente en el servidor de Mathew. Las cuentas creadas solo en la laptop de Russel no estarán disponibles automáticamente en ese servidor.
7. Permitir notificaciones y comprobar que se puede abrir la misma nota en web y teléfono. El teléfono necesita Internet para recibir los avisos de Firebase.

## Recorrido A: firma y cambio del borrador

1. Crear una nota directa en web y enviarla a firma.
2. Abrir Por firmar en Android y firmar como remitente.
3. Editar el contenido en web. Comprobar que no permite emitir con la firma vieja.
4. Firmar la nueva versión en Android y emitir desde web.
5. Como destinatario, recibir el aviso, abrir la nota y confirmar la recepción.
6. Comprobar el sello con persona, oficina y fecha. Compararlo con web.

## Recorrido B: dos revisores y cierre

1. Crear otra nota con dos autoridades VÍA diferentes, firmarla y emitirla.
2. Dejar la app fuera de pantalla y bloquear el teléfono. Comprobar el aviso de la primera autoridad y que abre la nota correcta al tocarlo.
3. Firmar y dar conformidad con la primera autoridad. Comprobar que solo después puede hacerlo la segunda con su propia cuenta.
4. Confirmar la recepción con la cuenta de destino y comprobar el sello.
5. Derivar a una segunda oficina. Comprobar su aviso y confirmar allí la recepción.
6. Registrar atención y cerrar desde web con el responsable correspondiente.
7. En cada cambio, mantener abierto el detalle en el otro dispositivo. Comprobar que etapa y oficina cambian sin actualizar ni reabrir, en hasta cinco segundos con conexión estable.
8. Comprobar Trámite finalizado y Volver al inicio en Android.
9. Abrir la nota por su referencia o QR y comprobar documento, firmas, sello, historial y archivos disponibles. Comprobar que una cuenta sin permiso no puede abrirla, aunque tenga el QR o toque el aviso.

## Guardar el resultado

- Fecha, versión del servidor, nombre y huella SHA-256 de la APK instalada.
- Referencias de las notas ficticias usadas y resultado de cada recorrido.
- Capturas del seguimiento en ambos dispositivos, sello, vista previa y cierre.
- Resultado de avisos con pantalla bloqueada y de apertura por QR.
- Confirmación de ambos de que se hizo sin USB contra el servidor desplegado.

Este procedimiento queda como referencia para repetir la validación si cambia la versión instalada, el servidor o su dirección. La entrega incluye el manual de uso y la evidencia para la revisión cruzada de #65.
