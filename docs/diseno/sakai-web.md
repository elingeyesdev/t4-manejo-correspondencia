# Adaptación web a Sakai — tarea #17 / T07

## Procedencia y alcance

Se utiliza Sakai Vue 5.0.0 de PrimeFaces, commit `ec6b6ef53ad4fa7f2861277f50f2d9e236c40372`, y su submódulo sakai-assets, commit `eaa70ece4cfa9aeb8f60b36dce5a422b6bae8003`. La licencia MIT se conserva en `web/resources/js/sakai/LICENSE.md`. La adaptación usa los componentes, el layout y los patrones del template; no es un diseño visual nuevo generado con IA.

La tarea corresponde a la rama `feature/17-template-sakai`. Esta documentación no modifica el alcance ni las fechas de la planificación, ni acredita aceptación del docente o aprobación del compañero. Las correcciones y pruebas del 29/10/2026 se realizaron con asistencia de Codex; el integrante responsable debe revisarlas, comprenderlas y explicar su participación real.

## Cómo se conecta con Laravel

`resources/js/app.js` carga cada componente cuando su elemento de montaje existe. `primevue.js` concentra la configuración de PrimeVue con Aura. El layout original adaptado se monta con `SakaiApp.vue`; Laravel sigue entregando las páginas y ejecutando los formularios con POST, CSRF y, cuando corresponde, `_method=PUT`.

Los datos se serializan como JSON escapado en atributos `data-props` y `data-context`. Se presentan mediante interpolación de Vue; no se convierte el contenido de documentos en plantillas ejecutables.

| Pantalla | Componentes y función |
| --- | --- |
| Acceso | LoginForm: adaptación del acceso original de Sakai con InputText, Password, Button y Message. |
| Bandeja | DocumentsTable: DataTable y paginación del servidor; los permisos se mantienen en Laravel. |
| Registro | SakaiForm: campos y distribución basados en FormLayout del template; conserva valores anteriores y request_key para evitar duplicados. |
| Detalle | DocumentDetail: información real del documento, hoja de ruta y tabla de movimientos. |
| Administración | SakaiForm para unidades, catálogos y usuarios; conserva solo los valores y errores del formulario enviado. |

La validación del navegador ayuda a detectar campos faltantes y contraseñas distintas, pero la validación y autorización definitivas son las de Laravel. Los selectores de PrimeVue envían su valor con campos ocultos. Las contraseñas se inician vacías y no se incluyen en los datos de recuperación. Editar un usuario dejando la contraseña vacía conserva la existente.

El menú muestra registro únicamente a los roles autorizados y administración únicamente al administrador. Ocultar enlaces no sustituye los controles de acceso del servidor. En pantallas pequeñas se compacta la cabecera y el menú se abre con su botón original.

## Comandos para revisar en Visual Studio Code

Desde la raíz del repositorio, ejecutar uno por uno:

```powershell
git status --short --branch
git --no-pager diff --stat
git --no-pager diff -- web/resources/js/app.js web/resources/js/sakai/layout/AppMenu.vue
git diff --check
Set-Location .\web
npm.cmd run build
php artisan test
```

`status` muestra la rama y los archivos pendientes. `diff` compara cambios de archivos ya controlados por Git; los nuevos también se deben abrir y revisar. `diff --check` detecta errores de espacios. `build` compila los recursos para comprobar imports y componentes. `artisan test` ejecuta las pruebas del backend y de integración de vistas con la base de pruebas configurada; no demuestra por sí solo el funcionamiento en PostgreSQL ni la apariencia en el navegador.

Para inspeccionar un archivo nuevo sin agregarlo al índice:

```powershell
Get-Content .\resources\js\sakai\SakaiForm.vue
Get-Content .\resources\js\sakai\DocumentDetail.vue
```

Se usa `npm.cmd` porque la política local de PowerShell impide ejecutar `npm.ps1`; no hace falta deshabilitar esa protección.

## Verificación del 29/10/2026

- Compilación Vite correcta; carga de componentes por pantalla para evitar el bloque JavaScript único de más de 500 kB.
- Suite Laravel: 28 pruebas y 153 aserciones correctas, con SQLite de pruebas.
- Navegador con base SQLite aislada: acceso, rechazo de credenciales inválidas, roles, paginación, registro con hoja de ruta, detalle, validaciones, unidades, catálogos y edición de usuarios.
- Edición de usuario sin contraseña: acceso posterior con la contraseña de prueba anterior confirmado.
- Pantalla pequeña de 390 × 844: acceso, menú y formulario de registro revisados; es una comprobación de la web adaptable, no de la aplicación móvil Flutter.
- Las pruebas utilizan usuarios y documentos ficticios; no se modificó la base PostgreSQL habitual.

Antes de solicitar aprobación, revisar los archivos y la aplicación local con la configuración habitual. Después se realizarán manualmente el commit, push y pull request hacia la rama establecida por el equipo. El compañero debe revisar el diff y las pruebas antes de aprobar. No se debe fusionar ni declarar terminada la tarea solo porque la compilación pase.
