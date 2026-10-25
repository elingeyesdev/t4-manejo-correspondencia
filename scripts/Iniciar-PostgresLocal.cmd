@echo off
set "DEV_ROOT=%~dp0..\.."
set "PG_CTL=%DEV_ROOT%\.tools\postgresql16\bin\pg_ctl.exe"
set "PG_DATA=%DEV_ROOT%\.services\correspondencia-pg16"
if not exist "%PG_CTL%" (
  echo Instale PostgreSQL y configure web/.env siguiendo README.
  exit /b 1
)
"%PG_CTL%" -D "%PG_DATA%" status
if errorlevel 1 "%PG_CTL%" -D "%PG_DATA%" -l "%PG_DATA%\server.log" start -w
