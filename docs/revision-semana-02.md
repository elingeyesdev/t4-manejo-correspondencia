# Guía de revisión cruzada — #11

Autor del trabajo web/API: Mathew. Revisor previsto: Russel. Estado: pendiente de revisión humana, no aprobado por este documento.

## Preparación

Seguir README desde una copia de la rama. Crear bases aisladas y administrador propio. No compartir contraseñas. Ejecutar pruebas rápidas y PostgreSQL. Registrar versiones, fecha, comando y resultado real.

## Recorrido manual

1. Intentar abrir /documentos sin sesión; debe pedir acceso. Probar credenciales incorrectas.
2. Entrar como administrador. Crear una unidad y comprobar código y nombre repetidos.
3. Crear tipo y prioridad; deshabilitar uno y verificar que no se ofrece al registrar.
4. Crear usuarios de recepción y funcionario con unidad habilitada. Intentar asignar unidad deshabilitada y contraseña inválida.
5. Entrar como recepción: registrar remitente, asunto, fecha, tipo, prioridad y unidad propia. Verificar códigos distintos de documento/hoja, guía, estado y movimiento con actor/hora.
6. Repetir la solicitud con misma clave: un solo documento. Cambiar datos con la misma clave: conflicto. Verificar también con pruebas API.
7. Consultar desde otra unidad y como funcionario: sin acceso a documentos ajenos, registro o administración.
8. Deshabilitar usuario: no puede iniciar ni continuar operaciones; movimientos anteriores conservados.
9. Cerrar sesión y verificar que el acceso protegido vuelva a exigir autenticación.
10. Revisar contrato con Android: token, 401/403, puerto, estado y significado de 409. Crear las tareas móviles necesarias sin dar integración por realizada.

## Evidencias y decisión

- [ ] Ejecución reproducible en el equipo del revisor.
- [ ] Pruebas aprobadas y errores observados registrados.
- [ ] Lectura de cambios de esquema, autorización e idempotencia.
- [ ] Contrato revisado con responsable móvil.
- [ ] Correcciones atendidas y verificadas.
- [ ] Aprobación formal del compañero registrada en GitHub antes de integrar.

Mathew debe revisar por separado el trabajo de Russel en #10 y registrar observaciones reales. El PR #10 ya integrado no acredita retrospectivamente una aprobación que no figure en GitHub. El PR #8 continúa abierto: comparar su contenido ya reutilizado antes de decidir su cierre o actualización.
