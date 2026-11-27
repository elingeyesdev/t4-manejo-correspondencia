param(
    [ValidateRange(1024, 65535)]
    [int] $Port = 8176,
    [string] $ChromiumBinary,
    [switch] $PrepareOnly
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$web = Join-Path $workspace 'web'
$runDir = Join-Path $workspace ('.local/nota-interna/' + [guid]::NewGuid().ToString('N'))
if (!(Test-Path (Join-Path $web 'vendor/autoload.php'))) {
    throw 'Primero instala las dependencias con composer install dentro de web.'
}
New-Item -ItemType Directory -Force -Path $runDir,(Join-Path $web 'bootstrap/cache'),(Join-Path $web 'storage/framework/sessions'),(Join-Path $web 'storage/framework/views') | Out-Null
$db = Join-Path $runDir 'prueba.sqlite'
New-Item -ItemType File -Path $db | Out-Null
$php = Join-Path $env:USERPROFILE '.config/herd/bin/php85/php.exe'
if (!(Test-Path $php)) { $php = (Get-Command php -ErrorAction Stop).Source }
$url = "http://127.0.0.1:$port"
$env:APP_ENV = 'local'
$env:APP_DEBUG = 'false'
$env:APP_URL = $url
$keyBytes = New-Object byte[] 32
$keyGenerator = [Security.Cryptography.RandomNumberGenerator]::Create()
try { $keyGenerator.GetBytes($keyBytes) } finally { $keyGenerator.Dispose() }
$env:APP_KEY = 'base64:' + [Convert]::ToBase64String($keyBytes)
$env:DB_CONNECTION = 'sqlite'
$env:DB_DATABASE = $db
$env:DB_URL = ''
$env:SESSION_DRIVER = 'file'
$env:SESSION_COOKIE = 'correspondencia_issue75'
$env:SESSION_SECURE_COOKIE = 'false'
$env:CACHE_STORE = 'array'
$env:QUEUE_CONNECTION = 'sync'
$env:CAMUNDA_URL = 'http://camunda.local.test/v2'
$env:FCM_PROJECT_ID = ''
if (!$ChromiumBinary) {
    $ChromiumBinary = @(
        'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
        'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
        'C:/Program Files/Google/Chrome/Application/chrome.exe'
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (!$ChromiumBinary -or !(Test-Path -LiteralPath $ChromiumBinary -PathType Leaf)) {
    throw 'Indica un ejecutable de Edge o Chrome con -ChromiumBinary para probar el PDF.'
}
$env:DOCUMENT_CHROMIUM_BINARY = (Resolve-Path -LiteralPath $ChromiumBinary).Path
Set-Location -LiteralPath $web
& $php artisan migrate --seed --force
if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear la base de prueba.' }
$notes = & $php (Join-Path $PSScriptRoot 'issue75-local-seed.php')
if ($LASTEXITCODE -ne 0) { throw "No se pudieron preparar las notas: $notes" }
$router = Join-Path $PSScriptRoot 'issue75-local-router.php'
$demo = $notes | ConvertFrom-Json
Write-Host ''
Write-Host "Ingreso: $url/acceso"
Write-Host 'Modo local Windows: Camunda simulado, base SQLite nueva.'
foreach ($account in $demo.cuentas.PSObject.Properties) {
    $values = $account.Value
    Write-Host "$($values[1]): $($values[0]) / $($values[3])"
}
Write-Host "Borrador: $url/notas-internas/$($demo.draft)/editar"
Write-Host "Nota recibida: $url/notas-internas/$($demo.received)"
Write-Host "Nota para revisar como Direccion: $url/notas-internas/$($demo.review)"
Write-Host 'Conserva esta ventana abierta mientras usas la demo. Ctrl+C detiene el servidor.'
if ($PrepareOnly) { return }
Set-Location -LiteralPath (Join-Path $web 'public')
& $php -S "127.0.0.1:$port" $router
