# Sistema de correspondencia institucional

Aplicación web y API en **Laravel 13 / PHP**, con PostgreSQL y cliente Android en Flutter. Proyecto académico del equipo Mathew Bruckner Becerra (Xmathewbruk, web/API) y Russel (RazzellRC, Android), con revisión cruzada.

## Estado de la entrega

- Núcleo Laravel/PostgreSQL: PR #12 revisado e integrado en develop; Issue #11 cerrado.
- Consulta móvil P04: PR #10 integrado; Issue #9 cerrado.
- Adaptación móvil a Laravel #13: aprobada por Xmathewbruk e integrada mediante PR #14 el 26/10/2026.
- Diseño móvil #6: incluido en PR #14; queda pendiente registrar el recorrido humano completo del diseño.
- Semana 2: incremento técnico integrado; ver [acta de cierre](docs/entregas/cierre-semana-02.md). La aceptación docente del software sigue pendiente.
- Cámara, QR, adjuntos, recepción, atención y derivación siguen pendientes de implementación.

La app usa sesiones protegidas, consulta, bandeja, detalle y registro reales de Laravel.
Node se conserva en `prototipo/node/` como antecedente; no es el backend de la app.

## Estructura

| Carpeta | Contenido |
| --- | --- |
| `web/` | Laravel: interfaz Blade, API, dominio, migraciones y pruebas |
| `movil/` | Flutter: acceso, consulta, bandeja, registro y diseños móviles |
| `docs/` | Diseño, contrato, planificación y evidencias |
| `prototipo/node/` | Prototipo previo de referencia |
| `scripts/` | Auxiliares de desarrollo y pruebas |

## Requisitos

- PHP >=8.4.1 para el composer.lock actual; probado con 8.4.27 y 8.5.
- Composer 2; extensiones PHP PDO, pdo_pgsql, mbstring, xml, curl, fileinfo y openssl.
- PostgreSQL 16 y dos bases separadas: `correspondencia` y `correspondencia_test`.
- Git. Herd puede proporcionar PHP y Composer; no es una dependencia del código.

Las vistas Blade usan estilos locales y no requieren compilar JavaScript para este corte.

## Instalación en otro equipo

```powershell
git clone https://github.com/elingeyesdev/t4-manejo-correspondencia.git
cd t4-manejo-correspondencia
git switch develop
cd web
composer install
Copy-Item .env.example .env
php artisan key:generate
```

En PostgreSQL cree un usuario de desarrollo con contraseña privada y las bases `correspondencia` y `correspondencia_test` de su propiedad. Configure `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME` y `DB_PASSWORD` en `web/.env`. Para una instalación nueva:

```powershell
php artisan migrate --seed
php artisan correspondencia:administrador
php artisan serve --host=127.0.0.1 --port=8000
```

Abra http://127.0.0.1:8000. El comando de administrador solicita la contraseña de forma oculta; no hay contraseñas predeterminadas ni cuentas compartidas versionadas. Los catálogos iniciales son datos de demostración, no una validación institucional.

En el equipo donde se preparó esta rama, PostgreSQL portátil escucha únicamente en `127.0.0.1:55432`; sus binarios y datos están fuera del repositorio. `scripts/Iniciar-PostgresLocal.cmd` permite reiniciarlo. La contraseña local está solamente en `.env`, ignorado por Git.

## Verificación

```powershell
cd web
composer validate --strict
php artisan test
vendor/bin/pint --test
composer audit
```

La ejecución ordinaria usa SQLite en memoria para pruebas rápidas. Desde la raíz, ejecutar `php scripts/test-postgres.php` prueba el mismo núcleo contra **correspondencia_test**, que se vacía durante las pruebas. Nunca apuntar las pruebas a datos reales. La CI usa PostgreSQL 16.

## Seguridad y límites

Sesión web con CSRF, límite de intentos de acceso, contraseñas con hash y tokens API revocables de ocho horas. Cada operación exige cuenta/unidad habilitadas y autorización en servidor. Un usuario de recepción registra en su unidad; el administrador puede registrar en cualquier unidad habilitada. La asignación inicial y esta política deben revisarse con el compañero y docente.

El registro reconoce `Idempotency-Key` y guarda documento, hoja, primer movimiento, auditoría y solicitud en una transacción. No hay edición ni borrado ordinarios de IDs o movimientos.

Adjuntos, cifrado de archivos, QR, derivaciones, recepción, atención, respuestas y cierre no forman parte de este incremento. El esquema incluye el vínculo futuro de respuesta; no presenta esas funciones como implementadas. Un despliegue público requiere configuración operativa y HTTPS; el servidor de desarrollo escucha solo localmente.

## Documentación y revisión

- [Alcance y plan de semana 2](docs/entregas/semana-02.md)
- [Decisión técnica](docs/decisiones/001-laravel.md)
- [Modelo de datos](docs/diseno/modelo.md)
- [Contrato API](docs/diseno/api.md)
- [Guía de revisión cruzada](docs/revision-semana-02.md)
- [Convenciones de colaboración](CONTRIBUTING.md)
