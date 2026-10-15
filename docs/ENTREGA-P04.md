# Entrega P04 — Registro de correspondencia entrante

Fecha: 15 de octubre de 2026. EDT: P04. Issue: #7.
Milestone existente: Iteración 02 (registro web).

## Historia
Como recepcionista, quiero registrar la correspondencia que llega para tener control de lo recibido.

## Qué cambió
Formulario con remitente, destinatario y fecha obligatorios; asunto opcional. Validación en navegador y servidor. Guía generada por el servidor, listado con búsqueda y almacenamiento persistente en archivo JSON. Interfaz adaptable a dispositivos móviles.

## Cómo probar
1. Ejecutar `node server.js` y abrir http://localhost:3000.
2. Intentar guardar sin campos obligatorios: el navegador impide enviar.
3. Registrar Alcaldía → Secretaría, fecha 2026-10-15, asunto Solicitud de informe.
4. Verificar mensaje de confirmación, guía COR-2026-000001 (en una instalación vacía) y fila en el listado.
5. Registrar otro documento: la guía debe ser diferente.
6. Buscar por remitente o guía.
7. Reiniciar el servidor: los registros deben seguir visibles.

## Evidencia automatizada
Comando: `node --test`. Resultado: 8 pruebas aprobadas, 0 fallidas (incluye prueba principal y 7 subpruebas).
Se verificaron campos vacíos, fecha inexistente, JSON inválido, generación de guía sin aceptar una guía del cliente, cinco solicitudes simultáneas con guías diferentes, listado de seis documentos, reinicio con continuación de secuencia, interfaz HTTP y ruta inexistente.
Las pruebas usan una carpeta temporal aislada, sin crear documentos de demostración en los datos reales.

## Flujo Git y GitHub
Base develop creada porque el repositorio no contenía commits. Rama feature/7-web-registro-correspondencia desde develop. Tres commits de funcionalidad: servidor, interfaz y pruebas/documentación. PR hacia develop con Closes #7.
El milestone Iteración 02 ya existía; se reutilizó para mantener el cronograma del proyecto.

## Revisión por compañero
Pendiente de revisión y aprobación por compañero P05. No se ha simulado aprobación ni realizado merge.

## Alcance
Entrega local para demostración. Una instancia del servidor, datos en JSON. No incluye autenticación ni despliegue público.
