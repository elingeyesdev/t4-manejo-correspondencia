# Entrega Android y validación del piloto

24 de noviembre de 2026, hora de Bolivia. Tarea #65.

## Entrega

- APK: `Correspondencia-Piloto-HTTPS-24.apk`.
- [Descargar la APK del piloto](https://github.com/elingeyesdev/t4-manejo-correspondencia/releases/download/piloto-android-2026-11-24/Correspondencia-Piloto-HTTPS-24.apk).
- [Archivos de la entrega](https://github.com/elingeyesdev/t4-manejo-correspondencia/releases/tag/piloto-android-2026-11-24).
- Aplicación: `dev.elingeyes.correspondencia.t4_movil`, versión 1.0.0 y versionCode 2001, arm64.
- SHA-256 de la APK: `7365ae083a868f3f734ffc57c11591fcb235fabb971b5c26820e330f62db0ca1`.
- Servidor del piloto: `https://172.20.10.3:18443`, en el punto de acceso de Mathew.
- Dispositivo: POCO F3 con Android 13.
- [Manual de uso](../../../entregas/manual-android-iteracion-06.md).
- [Manual en PDF](../../../entregas/manual-android-iteracion-06.pdf).
- [Configuración HTTPS](../../../operacion/piloto-https-android.md).

La APK conserva la firma de la instalación anterior. Se instaló como
actualización y se conservó la información de la aplicación. No contiene
contraseñas del piloto ni claves privadas de Firebase o del servidor.

## Comprobaciones directas

La huella del certificado público recibido coincidió con la que entregó Mathew.
La autoridad se usa en un contexto TLS limitado al origen del piloto. Se
mantienen la validación del nombre y de la vigencia del certificado.

Después de resolver el acceso al puerto 18443, una comprobación HTTPS desde el
teléfono devolvió 200 en `/up` y `/acceso`, y 401 al consultar la API sin sesión.
El ingreso posterior en la aplicación real mostró Inicio con `Hola, Recepcion`.
El usuario completó la confirmación del formulario.

La comunicación con el servidor fue por Wi-Fi, sin `adb reverse`. El USB se
utilizó para instalar y observar. El usuario después confirmó que lo desconectó
y que la aplicación abrió con la cuenta del piloto.

En la aplicación se observó la nota ficticia `Prueba manual #44`, CITE
`NI/DEMO/RECEPCION/2026/000002`, referencia `DEMO-45`. La vista previa mostró la
firma del remitente y el sello de recepción. El detalle ofrecía agregar otra
atención y consultar el expediente. El cierre se realiza en la web con la cuenta
responsable y esa diferencia está explicada en el manual.

## Confirmación del recorrido final

El usuario comunicó que la web abrió desde el teléfono de Mathew y después
confirmó que la prueba final funcionó correctamente en su servidor. Solicitó
registrar la tarea como realizada y publicar el PR final de #65.

El resultado del recorrido final se registra como confirmación manual del
usuario. No se atribuye a esta comprobación una lectura independiente del estado
final de Camunda ni una captura del cierre que no se obtuvo.

## Pruebas de código

- Suite Flutter completa: 233 aprobadas y cuatro optativas omitidas.
- Configuración y TLS: 14 casos aprobados, incluidos en la suite completa.
- Analizador Dart: sin incidencias.
- APK compilada, firma verificada e instalada en el teléfono.

[Resumen de ejecución conservado](pruebas.txt).

Las pruebas TLS aceptan la autoridad válida y rechazan otra autoridad, un nombre
distinto y solicitudes a otros orígenes. La configuración del piloto no cambia
el contexto global ni sigue redirecciones.

[Resultados estructurados](resultado.json).
