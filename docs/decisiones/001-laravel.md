# ADR-001: Laravel para web y API

Decisión: 21/10/2026. Implementación inicial: 23/10/2026. Referencia: #4. Estado: stack confirmado por el usuario; diseño pendiente de revisión cruzada.

## Decisión

El backend definitivo se implementará en Laravel. La aplicación Android existente se conserva en Flutter. PostgreSQL es la base de datos propuesta en la documentación de diseño; validar su configuración en ambos equipos. El servidor Node.js existente es un prototipo de referencia y no cumple el criterio de aceptación del stack.

Base técnica propuesta para la instalación: Laravel 13, PHP 8.3 o superior compatible y Composer 2. Confirmar las versiones disponibles en ambos equipos y conservar composer.lock en Git. Fuente: https://laravel.com/docs/13.x/releases

## Organización

- web/: aplicación Laravel con web y API compartiendo servicios, validaciones y autorización.
- movil/: aplicación Flutter existente.
- docs/: decisiones, contrato API, pruebas y evidencias.

El prototipo se conserva en prototipo/node/ tras verificar Laravel y sus pruebas históricas. No se importaron datos existentes ni se reescribió el historial.

## Reglas que debe cubrir la migración

1. Autenticación web, invalidación de sesión y permisos por rol/unidad en servidor.
2. Administración de unidades, tipos, prioridades y usuarios; deshabilitación sin eliminar referencias históricas.
3. Documento y hoja de ruta separados, con IDs únicos e inmutables.
4. Registro transaccional de documento, hoja y evento inicial REGISTRADA.
5. Clave de idempotencia por actor y operación: un reintento devuelve el mismo resultado; distinta carga con la misma clave produce conflicto.
6. Fechas de eventos generadas por servidor en UTC, presentadas según la zona del usuario.
7. Pruebas contra PostgreSQL para integridad y concurrencia antes de aceptar el registro.

## Coordinación con Android

El cliente actual consulta GET /api/correspondencia/guia/{guia} y espera guia, estado y fechaUltimoMovimiento en un objeto JSON, con fecha que incluya zona horaria. Un 404 con codigo GUIA_NO_ENCONTRADA indica inexistencia; 409 se interpreta como seguimiento ausente.

El diseño documental propone /documentos y /hojas y usa REGISTRADA. No cambiar silenciosamente esos nombres, estados o respuestas: acordar el contrato con Russel, registrar la decisión y adaptar las pruebas. Un conflicto 409 de versión no debe mostrarse como seguimiento ausente. La nueva API protegida requerirá manejar 401/403 y credenciales en Android.

Las pruebas móviles reales actuales arrancan ../server.js. Deben poder comprobar Laravel antes de acreditar compatibilidad. Las pruebas antiguas se conservan como evidencia del prototipo, no como aceptación de la migración.

## Revisión pendiente

Russel revisa contrato y compatibilidad móvil; Mathew atiende observaciones. Esta decisión no cierra #4: faltan el modelo detallado, el contrato completo, mockups y evidencia de revisión. No contiene aprobación del compañero ni validación del docente.
