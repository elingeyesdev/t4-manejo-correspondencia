# Revisión del repositorio oficial — 15 de octubre de 2026

Repositorio: https://github.com/elingeyesdev/t4-manejo-correspondencia
Copia local: C:\Users\ElniComp2023\Downloads\t4-manejo-correspondencia

## Estado actualizado tras fetch

La primera inspección encontró el repositorio vacío. Después el compañero publicó develop y feature/7-web-registro-correspondencia. Esta revisión reemplaza el diagnóstico inicial de ausencia total de código.

- develop/origin/develop: 5daeed2, chore: preparar base del proyecto.
- Rama remota web: da9e181, con tres commits de registro, formulario/listado y pruebas/documentación.
- main: no existe como rama remota o local. La predeterminada en GitHub es develop.
- PR #8: registro web, abierto hacia develop, sin merge.
- No hay AGENTS.md en develop ni en los archivos publicados de la rama web.

Se creó develop local directamente desde la referencia origin/develop recién actualizada, sin necesitar pull ni merge. Después se preparó feature/9-movil-consulta-guia desde esa base. La rama temporal no tenía commits propios; todos sus archivos móviles se conservaron y se compararon mediante SHA-256 (33 archivos fuente y configuración).

## Issues y planificación

- #1 a #6: tareas iniciales de análisis, preparación y diseño; #6 sigue siendo mockups móviles, no esta implementación.
- #7: [P04] Implementar registro web de correspondencia entrante, asignado a Xmathewbruk, web, Iteración 02.
- #8 es el PR del compañero, no el issue móvil.
- #9: [P04] Implementar consulta de envío por número de guía. Se creó después de verificar que no había un equivalente. Responsable RazzellRC, label movil, Iteración 02.

Se reutilizó Iteración 02 por corresponder a la entrega P04 ya documentada por el compañero. P04 se usa como referencia de la ficha docente; no se inventaron códigos HU o EDT específicos para la consulta móvil.

Se revisaron los seis milestones existentes y las etiquetas, sin crear duplicados ni modificarlos.

El Project no pudo leerse: la credencial no dispone de read:project. No se creó otro tablero ni se cambió el estado de tarjetas. El Issue #9 sigue abierto y sus criterios están sin marcar.

## API real revisada

La implementación está en la raíz de la rama web (server.js, public/index.html y test/), no en una carpeta web/.

Node.js, puerto 3000, escucha 127.0.0.1. GET y POST /api/correspondencia, almacenamiento JSON en data/correspondencia.json. Campos: id, guia, remitente, destinatario, fecha, asunto, creadoEn.

Faltan consulta por guía, estado actual y fecha del último movimiento. El adaptador móvil mantiene un aviso explícito de servicio pendiente y no simula resultados. No se integra la rama web ni se modifican archivos del compañero para fabricar ese contrato.

Se verificaron POST 201 y GET 200 ejecutando una copia del backend con datos aislados bajo movil/build/revision. Esta prueba verifica registro/listado reales, no una integración móvil de seguimiento todavía inexistente.

## Alcance de los cambios

Solo se incluyen archivos nuevos de movil/: base Flutter Android, aplicación, pruebas y documentación. Los archivos existentes de develop quedan intactos. build/, .dart_tool/, APK, logs, configuración local Android y temporales están excluidos.

El usuario autorizó crear el Issue #9, preparar la rama y commits locales. No autorizó push, creación de PR, merge, release, aprobación ni cierre manual de issues. No se ejecutan esas acciones.

## Verificación final antes de los commits locales

- flutter pub get: correcto.
- flutter analyze: sin observaciones.
- flutter test: 9 pruebas controladas aprobadas.
- flutter build apk --debug: correcto; APK generado.
- API de registro/listado del compañero: POST 201 y GET 200 en almacenamiento aislado; sin estado ni último movimiento en la respuesta.
- Integración móvil de consulta por guía: pendiente del endpoint y contrato necesarios.
- Se revisaron las rutas a incluir: únicamente fuentes, configuración Android, pruebas y documentación de movil/.
- build/, .dart_tool/, APK, local.properties, temporales y datos de prueba quedan fuera de los commits.
- Los archivos base de develop permanecen sin modificaciones.

APK: movil/build/app/outputs/flutter-apk/app-debug.apk (no versionado).
