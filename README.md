# Sistema de correspondencia institucional

Aplicación web y API en **Laravel 13 / PHP**, con PostgreSQL y cliente Android en Flutter. Proyecto académico del equipo Mathew Bruckner Becerra (Xmathewbruk, web/API) y Russel (RazzellRC, Android), con revisión cruzada.

## Estado de la entrega — 03/11/2026

- Núcleo Laravel/PostgreSQL #11: PR #12 revisado e integrado en `develop`.
- Consulta móvil #9: PR #10 es el antecedente histórico; la versión vigente usa Laravel y fue revisada e integrada mediante PR #14, junto con acceso, bandeja, detalle y registro #13.
- Interfaces Sakai: adaptación móvil PR #16 y web #17 / PR #22 aprobadas e integradas.
- Adjuntos cifrados y descarga autorizada #18: backend PR #23 aprobado e integrado. El cliente Android y el panel web de adjuntos #21 se integraron mediante PR #24. La revisión formal de Mathew fue posterior al merge y quedó como `COMMENTED`; se conserva esa cronología en [#21](https://github.com/elingeyesdev/t4-manejo-correspondencia/issues/21#issuecomment-6583168840).
- Recuperación operativa de #18: ensayo local realizado; [PR #27](https://github.com/elingeyesdev/t4-manejo-correspondencia/pull/27) abierto hacia `develop`, con checks aprobados y revisión de RazzellRC solicitada. #18 permanece abierto hasta la aprobación y la integración de esta continuación. El ensayo local no acredita respaldo externo ante pérdida del equipo.
- QR #19 y consulta del historial #20: PR #25 y PR #26 aprobados por RazzellRC e integrados en `develop`; ambos issues cerrados. La revisión de #20 registró que su recorrido visual automático no pudo completarse.
- Iteración 03: cinco de seis entregables cerrados; queda #18. El contador del milestone coincide con la lista: cinco cerrados y uno abierto. El conteo no mide esfuerzo ni aceptación docente.
- Diseño web #5 y móvil #6: cerrados. Mathew confirmó el 03/11/2026 la revisión cruzada: RazzellRC revisó web y Mathew revisó móvil. La fecha efectiva de esas revisiones no consta; las fechas del documento son de planificación (diseño 20–21/10 y corte 22/10), no fechas de ejecución. Se conserva la confirmación atribuida al usuario y los pendientes de evidencia por criterio.
- Semana 2: incremento técnico integrado; ver [acta de cierre](docs/entregas/cierre-semana-02.md). La aceptación docente del software sigue pendiente.
- Derivación, recepción, atención, respuesta y cierre documental corresponden a incrementos posteriores. La consulta del QR o del historial no ejecuta esas operaciones.

La app usa sesiones protegidas, consulta, bandeja, detalle y registro reales de Laravel.
Node se conserva en `prototipo/node/` como antecedente; no es el backend de la app.

## Estructura

| Carpeta | Contenido |
| --- | --- |
| `web/` | Laravel: interfaz Sakai Vue/PrimeVue sobre páginas Blade, API, dominio, migraciones y pruebas |
| `movil/` | Flutter: acceso, consulta, bandeja, registro, cámara y gestión de adjuntos |
| `docs/` | Diseño, contrato, planificación y evidencias |
| `prototipo/node/` | Prototipo previo de referencia |
| `scripts/` | Auxiliares de desarrollo y pruebas |

## Requisitos

- PHP >=8.4.1 para el composer.lock actual; probado con 8.4.27 y 8.5.
- Composer 2; extensiones PHP PDO, pdo_pgsql, mbstring, xml, curl, fileinfo y openssl.
- PostgreSQL 16 y dos bases separadas: `correspondencia` y `correspondencia_test`.
- Node.js y npm para compilar los recursos Sakai/Vue con Vite; la CI utiliza Node.js 22.
- Git. Herd puede proporcionar PHP y Composer; no es una dependencia del código.

La interfaz actual necesita los recursos compilados de Vite.

## Instalación en otro equipo

```powershell
git clone https://github.com/elingeyesdev/t4-manejo-correspondencia.git
cd t4-manejo-correspondencia
git switch develop
cd web
composer install
npm.cmd ci
npm.cmd run build
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
npm.cmd run build
php artisan test
vendor/bin/pint --test
composer audit
```

La ejecución ordinaria usa SQLite en memoria para pruebas rápidas. Desde la raíz, ejecutar `php scripts/test-postgres.php` prueba el mismo núcleo contra **correspondencia_test**, que se vacía durante las pruebas. Nunca apuntar las pruebas a datos reales. La CI usa PostgreSQL 16 y comprueba el backend y la compilación web; no ejecuta Flutter. Registrar por separado las pruebas móviles y sus omisiones.

## Seguridad y límites

Sesión web con CSRF, límite de intentos de acceso, contraseñas con hash y tokens API revocables de ocho horas. Cada operación exige cuenta/unidad habilitadas y autorización en servidor. Un usuario de recepción registra en su unidad; el administrador puede registrar en cualquier unidad habilitada. La asignación inicial y esta política deben revisarse con el compañero y docente.

El registro reconoce `Idempotency-Key` y guarda documento, hoja, primer movimiento, auditoría y solicitud en una transacción. No hay edición ni borrado ordinarios de IDs o movimientos.

Los adjuntos cifrados, su descarga autorizada, el QR y la consulta del historial están integrados. La consulta muestra los movimientos persistidos disponibles; actualmente el núcleo genera REGISTRO. Derivaciones, recepción, atención, respuestas y cierre documental siguen fuera del alcance implementado. El esquema incluye el vínculo futuro de respuesta; ese campo no acredita la operación de respuesta. Un despliegue público requiere configuración operativa y HTTPS; el servidor de desarrollo escucha solo localmente.

## Documentación y revisión

El flujo acordado es issue y criterios → rama desde `develop` actualizado → PR hacia `develop` → pruebas reales → revisión del otro integrante → correcciones → aprobación registrada por el revisor → merge. Mathew revisa el móvil de Russel; Russel revisa la web/API de Mathew. Registrar ejecutores reales y sesiones de pareja solo cuando hayan ocurrido. `.env`, claves, tokens y datos reales quedan fuera de Git.

- [Alcance y plan de semana 2](docs/entregas/semana-02.md)
- [Decisión técnica](docs/decisiones/001-laravel.md)
- [Modelo de datos](docs/diseno/modelo.md)
- [Contrato API](docs/diseno/api.md)
- [QR de hoja de ruta](docs/diseno/qr-hoja-ruta.md)
- [Historial documental](docs/diseno/historial-documental.md)
- [Adjuntos web y Android](docs/diseno/adjuntos-web-movil.md)
- [Guía de revisión cruzada de semana 2](docs/revision-semana-02.md)
- [Convenciones de colaboración](CONTRIBUTING.md)
- [Flujo de GitHub y propuesta de protección de develop](docs/flujo-github.md)

