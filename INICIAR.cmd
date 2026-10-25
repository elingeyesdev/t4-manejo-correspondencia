@echo off
cd /d "%~dp0web"
php artisan serve --host=127.0.0.1 --port=8000
pause
