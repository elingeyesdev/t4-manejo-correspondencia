# Git usado para preparar el diseño móvil

Fecha: 28/10/2026. Estos comandos los ejecutó Codex por indicación del usuario.
La guía permite repetir y explicar el proceso; no acredita ejecución manual del
estudiante. No se hizo commit, push, PR ni merge de esta adaptación.

En CMD, primero entrar al repositorio oficial:

```bat
cd /d C:\Users\ElniComp2023\Downloads\t4-manejo-correspondencia
```

Comprobaciones ejecutadas:

```bat
git status --short
git branch --show-current
git remote -v
```

`status` muestra archivos pendientes; `branch --show-current` indica la rama;
`remote -v` muestra el repositorio de destino. El estado inicial estaba limpio
en develop y origin apuntaba al repositorio oficial del equipo.

Creación de la rama ejecutada:

```bat
git switch -c codex/diseno-sakai-movil
```

Separa los cambios nuevos de develop. Crear una rama no sube archivos a GitHub.
No se volvió a modificar develop directamente.

Revisión de los cambios locales:

```bat
git diff --stat
git diff --check
git diff -- web/
git status --short
```

`--stat` resume archivos y líneas; `--check` detecta problemas de espacios;
`git diff -- web/` permite comprobar que esta adaptación no modifica la web.
Los archivos nuevos aún sin seguimiento se ven en `status`, no en `diff`.

## Lo siguiente todavía NO se ejecutó

Después de revisar el diseño, registrar su tarea en la iteración de la semana
correspondiente y acordar los criterios con el compañero. La elección de plantilla
es una corrección de diseño, no un supuesto avance funcional adicional del plan.

Para publicar se explicarán y ejecutarán por separado `git add`, `git commit`
y `git push -u origin codex/diseno-sakai-movil`. El commit guarda localmente y
push envía a GitHub. Después se abre el PR hacia develop para revisión del otro
integrante. No se inventa un número de issue ni se fusiona sin autorización.

Consulta adicional ejecutada: git log -1 --oneline (muestra el último commit existente; no crea un commit).
Comprobación ejecutada: git check-ignore movil/build/app/outputs/flutter-apk/app-debug.apk movil/.dart_tool/package_config.json (confirma que son archivos ignorados).
