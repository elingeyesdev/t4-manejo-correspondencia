# Sistema de correspondencia — P04

Registro web de correspondencia entrante y consulta móvil por número de guía.

## Ejecutar backend y formulario web

Requisito: Node.js 20 o superior. No necesita dependencias npm.

```sh
node server.js
```

Abrir http://localhost:3000. Registrar remitente, destinatario y fecha; el backend genera la guía y guarda el estado inicial Registrado con la fecha real del registro como primer movimiento. Copiar la guía para consultarla desde Android.

Datos: data/correspondencia.json (ignorado por Git). PORT permite cambiar el puerto y DATA_DIR permite utilizar almacenamiento aislado. El servidor escucha 127.0.0.1 por defecto.

## Aplicación Android

Ver [movil/README.md](movil/README.md). El emulador utiliza http://10.0.2.2:3000 para acceder al servidor de la computadora. HTTP está habilitado únicamente para debug.

## API

- POST /api/correspondencia: registro (201); remitente, destinatario y fecha obligatorios, asunto opcional.
- GET /api/correspondencia: listado.
- GET /api/correspondencia/guia/{guia}: consulta individual (200), guía inexistente (404 con codigo GUIA_NO_ENCONTRADA), guía vacía (400), registro antiguo sin seguimiento (409).

La consulta devuelve el registro guardado con guia, estado y fechaUltimoMovimiento; no genera información en Flutter. Al registrar, estado es Registrado y fechaUltimoMovimiento es la fecha/hora del servidor en UTC. Registro es el único movimiento implementado en esta entrega; no se simulan entregas o derivaciones.

Los registros antiguos sin datos de seguimiento conservan sus datos y reciben un aviso 409. No se migran ni modifican silenciosamente.

## Pruebas

```sh
node --test
cd movil
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Las pruebas Node y Flutter con HTTP real crean datos ficticios en carpetas aisladas y no modifican datos reales.

La base del registro, formulario web y pruebas originales procede de feature/7-web-registro-correspondencia, commit da9e181 (Issue #7). Se reutilizó sin fusionar su PR. La extensión de consulta y la app móvil corresponden al Issue #9.
