# Firma en Android · tareas #61 y #62

Avance local del 22 de noviembre de 2026. Base: PR #67 de Mathew,
commit `e7141794c84c03da788489489b606c2d03fa7437`.

## Implementado

- Bandeja **Por firmar**: consulta los borradores autorizados al servidor.
- **Firmar borrador**: muestra asunto, origen, destino, referencia, contenido y
  versión antes de capturar el trazo.
- **Firmar y dar conformidad**: reutiliza la misma pantalla para la VÍA activa.
- Captura normalizada al formato del contrato, con limpieza y rechazo de firmas
  vacías. Cancelar no envía nada. Confirmar dos veces no abre dos operaciones.
- El trazo, la versión y la clave del intento se guardan en almacenamiento seguro
  antes del POST, separados por servidor, cuenta, nota y acción.
- Reintentos por resultado pendiente, desconexión, 503 y 429 conservan los datos.
  Un borrador editado exige revisar y firmar su nueva versión.
- Una firma de remitente confirmada no necesita aumentar la versión de la nota.
  La emisión sigue realizándose desde web; Android no la ejecuta automáticamente.

## Revisión y comprobaciones

- PR #67: comprobaciones de Laravel en GitHub en verde al revisar.
- `InternalNoteFlowTest`: 6 pruebas, 194 aserciones, con motor simulado.
- Suite completa de Flutter: 172 pruebas aprobadas y una captura visual opcional
  omitida por no proporcionarse su referencia. Incluye pruebas existentes con
  Laravel y PostgreSQL aislado; no acredita el flujo firmado con Camunda real.
- Subconjunto de notas y firmas: 58 pruebas aprobadas, con bandejas, captura,
  permisos, versión, reintentos y recuperación.
- Analizador de Dart sobre `lib`, `test` e `integration_test`: sin observaciones.
- El ensayo existente `notas_camunda_real_test.dart` se adaptó para dibujar y
  confirmar la firma de cada VÍA. Requiere notas ficticias emitidas con la firma
  de remitente vigente; aún no se ejecutó este ensayo adaptado en el piloto.

## Prueba manual pendiente en el piloto

1. En web, crear un borrador con destino y dos autoridades VÍA. Pulsar **Enviar a firma**.
2. En Android, entrar como remitente: **Notas internas → Por firmar → abrir nota →
   Firmar borrador**. Revisar el contenido, dibujar y confirmar.
3. En web, comprobar que **Emitir** se habilite. Editar el contenido: debe exigir
   enviar a firma y firmar nuevamente desde Android antes de emitir.
4. Emitir la versión firmada. Con la cuenta de la segunda VÍA, comprobar que aún
   no se pueda aprobar. Con la primera: **Por revisar → abrir nota → Firmar y dar
   conformidad**. Luego repetir con la segunda VÍA.
5. Comprobar en web la misma nota y CITE, las conformidades en orden y el paso a
   recepción. Contrastar el avance con Camunda real.

Esta preparación no cierra los issues ni acredita despliegue, firma digital
certificada, notificaciones push, sello o seguimiento en vivo. Falta la prueba
con Android físico y la dirección accesible del servidor de Mathew, sin USB.
