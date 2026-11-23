# Cierre web y actualización automática Android

Prueba manual del 22/11/2026 con la nota ficticia **ererer**, número terminado en
**000002**, y la cuenta ficticia **Recepción Prueba**.

El usuario registró atención desde el teléfono y cerró la nota desde la web con
la cuenta responsable. La captura aportada muestra el cierre en el historial a
las 19:04:08 de Bolivia. El usuario confirmó expresamente que, con esa misma nota
abierta en el teléfono, la barra pasó sola a **Cierre**, sin tocar Actualizar ni
volver a abrir el detalle.

Una consulta autenticada independiente a la API por Wi-Fi devolvió `cerrada` y
la etapa `cierre`. Camunda devolvió `COMPLETED` para la instancia correspondiente.
No se modificó el cierre mediante scripts: lo realizó el usuario en la web.

[Resultado estructurado](resultado.json).

Este ensayo acredita la actualización automática del cierre. La latencia no fue
cronometrada. Faltan la derivación, las constancias de #58, el push real y la
validación final contra el servidor Ubuntu desplegado. El USB se utilizó para
instalar; no se acredita aquí la prueba sin USB de #65.
