# Recuperación operativa de adjuntos — #18 / T08

## Objetivo y estado

Completar el criterio pendiente del #18: procedimiento documentado y probado para recuperar PostgreSQL, archivos cifrados y sus claves originales.

Prueba local ejecutada por Mathew el 03/11/2026, con scripts preparados por Codex. Se respaldaron y restauraron 19 tablas y 2 adjuntos; la descarga HTTP desde la copia recuperada pasó con autenticación y contenido idéntico. La revisión cruzada de esta continuación sigue pendiente antes de cerrar el issue.

La carga/cifrado/descarga original se integró mediante PR #23, aprobado por RazzellRC; Android y el panel web mediante PR #24. Este trabajo completa la restauración operativa; no cambia las rutas ni permisos del producto.

## Entorno y alcance

- Windows/PowerShell, PHP 8.5.12, Laravel y dependencias existentes del repositorio.
- PostgreSQL 16.15; herramientas pg_dump y pg_restore. Por defecto los scripts buscan la instalación del proyecto en `../.tools/postgresql16/bin`. Puede definirse PG_BIN con otra carpeta que contenga esos ejecutables.
- Base habitual `correspondencia`, conexión local por .env sin DB_URL alternativa. La cuenta PostgreSQL necesita lectura del origen y permiso para crear la base aislada.
- Los archivos de respaldo y recuperación se conservan bajo `.local/recuperacion-18/<GUID>`, fuera de Git, con permisos de usuario actual y SYSTEM.
- Detener todos los servidores web y procesos que escriban durante la captura. El script comprueba 127.0.0.1:8000; el operador debe detener también servidores en otra dirección o puerto y cualquier escritor CLI.
- Puerto 127.0.0.1:8001 libre para verificar la recuperación. Se requiere una cuenta administradora operativa en los datos restaurados; no se modifica su contraseña.
- Este es un ensayo operativo local. Una copia en el mismo equipo no cubre pérdida del disco/equipo ni acredita una estrategia externa, retención automática o restauración en otro sistema operativo.

## Preparación de un lote nuevo

Ejecutar desde la raíz del repositorio, con PostgreSQL iniciado:

```powershell
.\scripts\Iniciar-PostgresLocal.cmd

$restauracion18 = Join-Path (Get-Location) (
    '.local\recuperacion-18\' + [guid]::NewGuid().ToString('N')
)
New-Item -ItemType Directory -Path $restauracion18 -ErrorAction Stop | Out-Null
$restauracionUsuario = [Security.Principal.WindowsIdentity]::GetCurrent().Name

icacls $restauracion18 /inheritance:r /grant:r "${restauracionUsuario}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F'
if ($LASTEXITCODE -ne 0) { throw 'No se pudieron limitar los permisos.' }
icacls $restauracion18 /remove:g '*S-1-5-32-544'
if ($LASTEXITCODE -ne 0) { throw 'No se pudo retirar el permiso adicional.' }

foreach ($carpeta in @('datos', 'adjuntos', 'claves')) {
    New-Item -ItemType Directory -Path (Join-Path $restauracion18 $carpeta) -ErrorAction Stop | Out-Null
}

$acl = Get-Acl -LiteralPath $restauracion18
$usuarioSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
if (-not $acl.AreAccessRulesProtected -or @($acl.Access).Count -ne 2) {
    throw 'Los permisos no coinciden con el directorio privado esperado.'
}
foreach ($regla in $acl.Access) {
    if ($regla.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -notin @($usuarioSid, 'S-1-5-18')) {
        throw 'Existe un permiso adicional.'
    }
}
git check-ignore -- $restauracion18
if ($LASTEXITCODE -ne 0) { throw 'El lote no esta excluido de Git.' }

$referencia = [ordered]@{
    directorio = $restauracion18
    carpetas = @('datos', 'adjuntos', 'claves')
    permisos_verificados = $true
    excluido_de_git = $true
    respaldo_creado = $false
}
$puntero = Join-Path (Split-Path $restauracion18) 'lote-actual.json'
[IO.File]::WriteAllText(
    $puntero,
    ($referencia | ConvertTo-Json -Depth 3),
    [Text.UTF8Encoding]::new($false)
)
```

La referencia contiene rutas y estados, no secretos. Un nuevo GUID preserva los lotes anteriores. Los scripts rechazan repetir respaldo/restauración sobre un lote o destino ya usado; ante un intento incompleto, conservar sus registros y preparar otro lote tras revisar la causa.

## 1. Captura coherente del respaldo

```powershell
php -d memory_limit=256M .\scripts\respaldar-adjuntos-local.php --comprobar
php -d memory_limit=256M .\scripts\respaldar-adjuntos-local.php --crear
```

El script valida el origen local y las rutas, abre una transacción de solo lectura con snapshot exportado y pasa ese snapshot a pg_dump, de modo que el archivo de base y los conteos/metadatos correspondan al mismo punto de lectura. No crea ni altera registros del origen.

Estructura del lote:

| Archivo/carpeta | Contenido |
| --- | --- |
| datos/base.dump | Respaldo PostgreSQL en formato custom |
| datos/pg_dump.log | Registro privado de la herramienta |
| adjuntos/ | Copia de los archivos cifrados, conservando rutas relativas |
| claves/cifrado.json | APP_KEY, claves previas y anillo/versiones de claves de adjuntos |
| manifiesto.json | Hash del dump, hashes de archivos cifrados, referencias y SHA-256/tamaño originales |

Se valida el contenido descifrado antes de registrar su hash original. No se guardan copias en claro de los adjuntos en el respaldo.

El archivo de claves contiene secretos en texto claro protegido por ACL: no es un archivo de claves cifrado. Es imprescindible conservar su acceso restringido y mantenerlo fuera del repositorio y de destinos públicos. Los volcados también contienen datos y hashes de autenticación y permanecen privados. Las claves no se imprimen ni se envían como argumentos de herramientas. No regenerar ATTACHMENTS_KEY_V1 para recuperar archivos antiguos: se requieren sus claves originales.

## 2. Restauración en un destino nuevo

```powershell
php -d memory_limit=256M .\scripts\restaurar-adjuntos-local.php --comprobar
php -d memory_limit=256M .\scripts\restaurar-adjuntos-local.php --restaurar
```

El nombre del destino se deriva del lote y solo admite el prefijo `correspondencia_recuperacion18_`. Rechaza bases o directorios existentes y no contiene operaciones DROP DATABASE ni --clean.

Crea una base vacía y usa pg_restore con --single-transaction, --exit-on-error, --no-owner y --no-acl. Verifica las tablas y sus conteos, los metadatos de adjuntos, los archivos restaurados y el descifrado con claves recuperadas, comparando tamaño y SHA-256 con el original.

El destino de archivos es `<lote>/restaurado/storage/app/private/attachments`; las claves recuperadas se copian a `<lote>/restaurado/claves`. La configuración fuente .env no se reemplaza. La evidencia queda en `restaurado/restauracion.json`.

## 3. Descarga autenticada desde la aplicación recuperada

```powershell
php -d memory_limit=256M .\scripts\verificar-restauracion-local.php --comprobar
php -d memory_limit=256M .\scripts\verificar-restauracion-local.php --descargar
```

La aplicación usa la base restaurada, claves de su copia recuperada, almacenamiento/logs/cachés separados y el backend original. El script levanta temporalmente un servidor HTTP en 127.0.0.1:8001 y comprueba su identidad y base antes de enviar un token. No redirige peticiones a otra instancia.

Comprueba HTTP 401 sin autenticación. Crea mediante CLI un token temporal en la base restaurada para un administrador operativo, descarga cada adjunto por la ruta real protegida y exige HTTP 200, MIME, tamaño, no-store, nosniff y SHA-256 coincidentes.

Revoca únicamente el token creado y detiene el servidor temporal al terminar, también en la salida por fallo. No se prueba aquí el inicio de sesión con contraseña ni la interfaz móvil. Los binarios descargados en claro y su resultado quedan en una carpeta privada `restaurado/verificacion-<id>`; no se publican. La evidencia se guarda en resultado.json y actualiza restauracion.json. Si falla la revocación se informa como fallo de verificación.

## Evidencia observada — 03/11/2026

| Comprobación | Resultado | Ejecutor |
| --- | --- | --- |
| Lote privado y exclusión de Git | Usuario/SYSTEM; .env y .local excluidos | Codex |
| Respaldo real | 19 tablas, 2 archivos cifrados y 2 adjuntos | Mathew |
| Restauración PostgreSQL | 19 tablas con conteos y metadatos coincidentes | Mathew |
| Claves y contenido recuperados | Claves originales; tamaño y SHA-256 coincidentes | Mathew |
| HTTP sin autenticación | 401 | Mathew |
| HTTP autenticado, JPEG pequeño | 200; 669 bytes; MIME y SHA-256 coincidentes | Mathew |
| HTTP autenticado, archivo de límite | 200; 10 485 760 bytes; MIME y SHA-256 coincidentes | Mathew |
| Finalización | Token temporal revocado y servidor detenido | Mathew; confirmado por Codex |
| Conservación de datos | Conteos de las 19 tablas del origen y destino iguales al respaldo; cero tokens de verificación | Codex |
| Prevención de sobrescritura | Respaldo usado y destino existente rechazados; dump y claves intactos | Codex |
| Regresión SQLite y PostgreSQL | 76 pruebas, 401 aserciones en cada entorno | Mathew |
| Concurrencia PostgreSQL | 1 prueba, 13 aserciones | Mathew |
| Formato y diff | Pint aprobado: 3 scripts y 64 archivos web; git diff --check sin errores | Mathew |
| Revisión de esta continuación | Pendiente en PR hacia develop | RazzellRC |

El archivo de 10 MiB procede de la prueba previa de límite y contiene relleno; no se presenta como una fotografía natural de ese tamaño. Las solicitudes HTTP atravesaron las rutas/middleware reales de Laravel, sin mocks.

Los scripts y la documentación fueron preparados por Codex. Mathew ejecutó las tres operaciones reales y compartió sus salidas. No se acredita sesión de programación en pareja ni aprobación de recuperación por el compañero todavía.

## Cierre y mantenimiento

Publicar solo scripts/documentación, solicitar revisión cruzada y cerrar #18 tras la aprobación e integración de esta continuación. Los respaldos, manifiestos privados, claves, descargas y registros permanecen en .local. El procedimiento conserva los destinos para revisión y no automatiza su borrado.

Conservar todas las versiones de clave necesarias junto con sus correspondencias key_version. Este ensayo no rota claves ni migra datos de producción. La continuación no altera el alcance ni la fecha aprobada de Iteración 03 (05/11/2026).
