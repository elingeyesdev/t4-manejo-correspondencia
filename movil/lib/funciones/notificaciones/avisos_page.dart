import 'package:flutter/material.dart';

import '../../compartido/diseno/institucional.dart';
import '../../compartido/diseno/sakai_widgets.dart';
import 'avisos_controller.dart';

class AvisosPage extends StatefulWidget {
  const AvisosPage({super.key, required this.controller});
  final AvisosController controller;
  @override
  State<AvisosPage> createState() => _AvisosPageState();
}

class _AvisosPageState extends State<AvisosPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.refrescar();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller, pagina = c.pagina;
      return Scaffold(
        appBar: CabeceraInstitucional(
          titulo: 'Avisos',
          actions: [
            IconButton(
              tooltip: 'Actualizar avisos',
              icon: const Icon(Icons.refresh),
              onPressed: () => c.refrescar(),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (c.mensaje != null) Text(c.mensaje!),
            if (!c.disponible)
              const Text(
                'Los avisos del teléfono aún no están configurados. Puedes consultar los avisos del sistema aquí.',
              ),
            if (pagina == null && c.mensaje == null)
              const LinearProgressIndicator(),
            if (pagina != null) ...[
              Text('${pagina.noLeidas} sin leer'),
              if (pagina.avisos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No tienes avisos.'),
                ),
              for (final aviso in pagina.avisos)
                ListTile(
                  leading: Icon(
                    aviso.leida
                        ? Icons.mark_email_read_outlined
                        : Icons.mark_email_unread_outlined,
                  ),
                  title: const Text('Tienes una nueva tarea'),
                  subtitle: Text(sakaiDate(aviso.fecha.toIso8601String())),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => c.abrir(aviso.id),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: pagina.pagina > 1
                        ? () => c.refrescar(numero: pagina.pagina - 1)
                        : null,
                    child: const Text('Anterior'),
                  ),
                  Text('${pagina.pagina} / ${pagina.ultima}'),
                  TextButton(
                    onPressed: pagina.pagina < pagina.ultima
                        ? () => c.refrescar(numero: pagina.pagina + 1)
                        : null,
                    child: const Text('Siguiente'),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
}
