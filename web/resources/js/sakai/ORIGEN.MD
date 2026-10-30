# Procedencia del template

- Template: Sakai Vue.
- Autor/proveedor: PrimeTek / PrimeFaces.
- Repositorio: https://github.com/primefaces/sakai-vue
- Versión declarada: 5.0.0.
- Commit de origen: ec6b6ef53ad4fa7f2861277f50f2d9e236c40372.
- Licencia: MIT, conservada en LICENSE.md.
- Tarea del proyecto: #17 / T07.
- Responsable web: Xmathewbruk.

## Archivos incorporados

Las carpetas layout/ y assets/ se copiaron del repositorio original.
Las adaptaciones posteriores se identificarán mediante los cambios de Git.

## Integración

Laravel conserva el backend y la API.
Las dependencias y la configuración se adaptan al Vite 7 del proyecto.

## Estado

Base original conectada con acceso, bandeja, registro, detalle y administración. Verificación local realizada el 29/10/2026. La aprobación del compañero y la integración mediante pull request siguen pendientes.
## Recursos del submódulo

- Repositorio: https://github.com/primefaces/sakai-assets
- Commit: eaa70ece4cfa9aeb8f60b36dce5a422b6bae8003.
- Descargado mediante el submódulo vinculado al template original.
- Se conserva el contenido de assets, excluyendo su archivo interno .git.

## Adaptaciones de la interfaz web

Se reutilizan el layout y los estilos originales de Sakai, el patrón de acceso Login.vue y el de campos uikit/FormLayout.vue con componentes PrimeVue. Laravel conserva rutas, validación, permisos, sesión, CSRF y operaciones de negocio. Las correcciones y pruebas del 29/10/2026 se realizaron con asistencia de Codex; el responsable debe revisar y comprender los cambios antes del commit y de solicitar aprobación. No se generaron imágenes ni un diseño visual independiente con IA. La explicación y los comandos están en docs/diseno/sakai-web.md desde la raíz del repositorio.
