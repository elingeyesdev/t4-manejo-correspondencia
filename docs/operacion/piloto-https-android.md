# HTTPS del piloto en Android

Configuración del 24 de noviembre de 2026 para la tarea #65.

## Certificado y destino

La APK del piloto utiliza una autoridad privada mediante un contexto TLS propio.
Se conserva la validación del nombre y de la vigencia del certificado. El cliente
no sigue redirecciones y rechaza solicitudes a otro esquema, servidor o puerto.
Esta configuración no modifica las autoridades del sistema ni de otros clientes.

Destino del piloto recibido de Mathew: `https://172.20.10.3:18443`.

La huella SHA-256 del certificado público entregado por Mathew es:

```text
CD:B7:89:0A:50:28:F1:E9:D8:32:65:28:8F:01:C7:F1:AC:CF:9F:E2:A1:3E:03:AD:99:19:B6:F4:02:57:7C:AF
```

Corresponde a `Caddy Local Authority - 2026 ECC Root`. Se verificó mediante
`openssl x509 -sha256 -fingerprint`. La huella representa el certificado DER,
no el archivo PEM completo. No se necesita la clave privada de la autoridad.

## Preparar la compilación

Crear fuera del repositorio un JSON con estos valores:

- `API_BASE_URL`: dirección HTTPS del servidor, sin `/up` ni `/acceso`.
- `API_CA_ORIGIN`: el mismo esquema, servidor y puerto, sin rutas adicionales.
- `API_CA_CERT_BASE64`: archivo público de la autoridad codificado en Base64.

La configuración del piloto debe corresponder a la CA y al destino acordados.
Sin esos valores se utiliza el transporte habitual de la aplicación. La
configuración privada de Firebase del servidor no forma parte de este archivo.

Compilar desde `movil` conservando la firma de instalación del teléfono:

```text
flutter build apk --debug --no-pub --target-platform android-arm64 --split-per-abi --build-number=1 --dart-define-from-file=RUTA_AL_JSON
```

La APK arm64 mantiene `versionCode` 2001. Antes de instalarla se verificó su firma
contra la APK anterior. Los certificados y la clave de `test/fixtures/tls_piloto`
son identidades ficticias de loopback para pruebas. No se incluyen en la APK.

## Verificación

- Catorce casos de configuración, límite de origen y TLS real aprobados.
- Suite Flutter completa con 233 casos aprobados y cuatro optativos omitidos.
- Analizador sin incidencias.
- APK compilada e instalada como actualización en el POCO F3.

Las pruebas TLS comprueban aceptación de la CA válida, rechazo de otra CA,
validación del nombre del servidor y separación del contexto global.

Referencias de la implementación:

- [HttpClient de Dart](https://api.dart.dev/dart-io/HttpClient-class.html)
- [Autoridades de confianza en SecurityContext](https://api.dart.dev/dart-io/SecurityContext/setTrustedCertificatesBytes.html)

## Alcance de la comprobación en el servidor

El primer ingreso agotó el tiempo de espera. Una comprobación independiente
desde el teléfono también agotó la conexión TCP hacia `172.20.10.3:18443`, antes
de iniciar TLS. No se sustituyó ese fallo por un resultado aprobado.

Después de revisar el acceso con Mathew, la nueva comprobación devolvió 200 en
`/up` y `/acceso`, y 401 en la API todavía sin autenticar. Se utilizó la autoridad
comprobada y se conservó la validación del certificado y del nombre del servidor.

El segundo ingreso con la cuenta ficticia del piloto llegó a Inicio y mostró
`Hola, Recepcion` en la aplicación real. El teléfono mantuvo `172.20.10.2` en el
punto de acceso de Mathew. El usuario completó la confirmación del formulario.

La comunicación de la API fue por Wi-Fi, sin `adb reverse`. El USB se utilizó
para instalar la actualización y observar la pantalla. Esta comprobación
acredita el ingreso al servidor, no el recorrido completo de cierre de #65.
