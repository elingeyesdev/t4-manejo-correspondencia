# Correspondencia Android — Flutter y Laravel

La aplicación usa el Stack A: Flutter → API Laravel/Sanctum → PostgreSQL.
La web Laravel y Android comparten documentos, autorización y persistencia.
La app no se conecta directamente a PostgreSQL ni al servidor histórico de Node.

## Funcionalidades conectadas

- Inicio de sesión con correo y contraseña institucionales.
- Token protegido con `flutter_secure_storage`, restauración validada en la API,
  expiración, revocación al cerrar y salida ante HTTP 401. La contraseña no se guarda.
- Consulta por guía: guía obligatoria, estado y fecha reales, inexistencia y errores.
- Mi bandeja: documentos autorizados por unidad, paginación, actualización y detalle
  con código, guía, hoja de ruta e historial recibidos del servidor.
- Nueva correspondencia para recepción y administrador: remitente, asunto, fecha,
  tipo, prioridad y unidad. Las opciones se consultan al servidor. La guía y el código
  se muestran únicamente tras su respuesta. El reintento del mismo formulario usa
  la misma clave de idempotencia; no crea otro registro.

Los permisos se verifican en Laravel. Funcionario no dispone de registro.
La sección Gestión documental conserva el diseño de operaciones futuras;
sus pantallas de cámara, QR, recepción, atención y derivación no envían operaciones.
Ver [DISENO_MOVIL.md](DISENO_MOVIL.md).

## Preparar el backend

PHP >=8.4.1 para el composer.lock actual, Composer y PostgreSQL. El manifiesto admite ^8.3, pero varias dependencias fijadas exigen >=8.4.1. Desde la raíz del repositorio:

```powershell
cd web
composer install
Copy-Item .env.example .env
# Configurar DB_HOST, DB_PORT, DB_DATABASE, DB_USERNAME y DB_PASSWORD propios.
php artisan key:generate
php artisan migrate --seed
php artisan correspondencia:administrador
php artisan serve --host=127.0.0.1 --port=8000
```

Copiar `.env.example` solamente cuando todavía no exista `.env`. El comando de
administrador pide nombre, correo y contraseña privada; no hay credenciales públicas.
La base local de esta integración es nueva y separada de los antiguos JSON.
En este equipo, `.local/Crear-Administrador.cmd` y `.local/Iniciar-Backend.cmd`
utilizan PHP portable y el PostgreSQL local preparado. No se versionan esos ajustes.

## Ejecutar Android

Desde `movil/`:

```powershell
flutter pub get
flutter devices
flutter run -d ID_DEL_EMULADOR
```

Predeterminado: `http://10.0.2.2:8000`, que apunta al PC desde Android Emulator.
En teléfono USB:

```powershell
adb reverse tcp:8000 tcp:8000
flutter run -d ID_DEL_TELEFONO --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

En Android Studio, abrir `movil/`, configuración Flutter con `lib/main.dart`.
Para teléfono USB, añadir el mismo `--dart-define` a Additional run args y hacer
`adb reverse`. Cambiar `--dart-define` requiere volver a ejecutar la app.
HTTP local está permitido exclusivamente en debug; un despliegue requiere HTTPS.
El manifiesto desactiva backup para evitar restaurar credenciales sin su clave.

## Contrato consumido

- `POST /api/sesiones`: `{email,password,device_name}` → `{token,user}`.
- `DELETE /api/sesiones/actual`: revoca token, HTTP 204.
- `GET /api/documentos?page=N`: bandeja paginada y autorizada.
- `GET /api/documentos/{uuid}`: detalle autorizado.
- `GET /api/correspondencia/guia/{guia}`: consulta autorizada; 404 con
  `codigo=GUIA_NO_ENCONTRADA` representa inexistencia o falta de acceso.
- `GET /api/configuracion-registro`: tipos, prioridades y unidades habilitados.
  Complementa el PR #12 para recepción y administrador.
- `POST /api/documentos`: `remitente,asunto,fecha,tipo_id,prioridad_id,unidad_id`,
  encabezado `Idempotency-Key`; 201 al crear, 200 al recuperar el mismo intento.
  UUID, `codigo`, `guia`, hoja y movimientos proceden del servidor.

Se manejan 401, 403, 404, 409, 422, 429, errores de servidor, timeout y red.
La sesión está vinculada a la URL del servidor; cambiar de API exige nuevo acceso.

## Verificar

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

`laravel_test.dart` comprueba contrato, sesión, permisos y formulario con respuestas
controladas. `laravel_real_test.dart` levanta PHP/Laravel real, usa PostgreSQL
`correspondencia_test`, crea una cuenta aislada, registra, reintenta, verifica un
solo documento/movimiento/solicitud en BD y consulta las pantallas. Limpia su cuenta
y documentos al finalizar. No ejecutar junto con otras suites que reconstruyan esa BD.
Se activa indicando el ejecutable PHP y la conexión de la base de pruebas:

```powershell
$env:LARAVEL_TEST_PHP = (Get-Command php).Source
# DB_HOST, DB_PORT, DB_USERNAME y DB_PASSWORD deben apuntar al PostgreSQL de pruebas.
# Crear previamente la base correspondencia_test, diferente de la de desarrollo.
flutter test
```

Sin `LARAVEL_TEST_PHP`, esa integración se omite explícitamente. La prueba histórica
`consulta_real_test.dart` usa `../prototipo/node/server.js`, Node disponible en PATH
y un JSON temporal aislado. No acredita la integración Laravel. El formulario
anterior y sus pruebas siguen conservados para trazabilidad; producción utiliza
`RegistroLaravelPage` y `ApiLaravel`, sin `REGISTRO_API_URL`.

APK: `build/app/outputs/flutter-apk/app-debug.apk`, ignorado por Git.
Dependencias, configuración local, credenciales y artefactos generados no se publican.

## Botón Atrás de Android

Desde Consulta, Nueva correspondencia o Mi bandeja vuelve a Inicio y conserva
los campos de la sección. Si el menú está abierto, primero lo cierra.
Desde un detalle regresa a la bandeja. En Gestión documental retrocede por las
pantallas del diseño. Desde Inicio pide confirmación; solo Salir cierra la app,
sin cerrar la sesión. Pruebas de regresión en `test/retroceso_test.dart`.
## Apariencia Sakai

Adaptación móvil de Sakai / PrimeVue con iconos originales PrimeIcons.
Fuente, licencias y alcance: [DISENO_SAKAI.md](DISENO_SAKAI.md).
Comandos usados y estado local: [GUIA_GIT_DISENO.md](GUIA_GIT_DISENO.md).
