@echo off
setlocal
set "WEB_ROOT=%~dp0..\web"
set "UPLOAD_TEMP=%~dp0..\.local\uploads-temp"

if not exist "%UPLOAD_TEMP%" mkdir "%UPLOAD_TEMP%"
if not exist "%UPLOAD_TEMP%" exit /b 1

pushd "%WEB_ROOT%\public" || exit /b 1
echo Servidor local: http://127.0.0.1:8000
echo Subidas hasta 10 MiB; carpeta temporal privada del proyecto.
php -d "upload_tmp_dir=%UPLOAD_TEMP%" -d "sys_temp_dir=%UPLOAD_TEMP%" -d upload_max_filesize=10M -d post_max_size=12M -d memory_limit=256M -S 127.0.0.1:8000 -t . "..\vendor\laravel\framework\src\Illuminate\Foundation\resources\server.php"
set "WEB_EXIT=%ERRORLEVEL%"
popd
exit /b %WEB_EXIT%
