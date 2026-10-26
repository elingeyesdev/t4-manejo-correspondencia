import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onConsultar,
    required this.onVerDiseno,
    required this.onNuevoRegistro,
    this.onBandeja,
    this.puedeRegistrar = true,
  });
  final bool puedeRegistrar;
  final VoidCallback? onBandeja;
  final VoidCallback onConsultar;
  final VoidCallback onVerDiseno;
  final VoidCallback onNuevoRegistro;

  Widget _acceso({
    required IconData icono,
    required String titulo,
    required String descripcion,
    required VoidCallback onTap,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF3E9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icono, color: const Color(0xFF456B2F)),
      ),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(descripcion),
      ),
      trailing: const Icon(Icons.chevron_right, size: 22),
      onTap: onTap,
    ),
  );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'GESTIÓN DOCUMENTAL',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF62705B),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Correspondencia\ninstitucional',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.15,
                letterSpacing: -.7,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Consulte el estado de su envío con el número de guía.',
              style: TextStyle(color: Color(0xFF667064), height: 1.6),
            ),
            const SizedBox(height: 28),
            Material(
              color: const Color(0xFF456B2F),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: onConsultar,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.travel_explore_outlined,
                            color: Colors.white,
                            size: 32,
                          ),
                          Spacer(),
                          Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 22,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Consultar envío',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Estado y último movimiento de tu correspondencia.',
                        style: TextStyle(color: Color(0xFFE5EEDC), height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Más opciones',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            if (puedeRegistrar)
              _acceso(
                icono: Icons.note_add_outlined,
                titulo: 'Nueva correspondencia',
                descripcion: 'Remitente, asunto, tipo y fecha de recepción.',
                onTap: onNuevoRegistro,
              ),
            if (onBandeja != null)
              _acceso(
                icono: Icons.inbox_outlined,
                titulo: 'Mi bandeja',
                descripcion: 'Documentos e historial de tu unidad.',
                onTap: onBandeja!,
              ),
            _acceso(
              icono: Icons.folder_open_outlined,
              titulo: 'Gestión documental',
              descripcion: 'Diseño de recepción, archivos y atención.',
              onTap: onVerDiseno,
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 15,
                  color: Color(0xFF788273),
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Sistema de correspondencia',
                    style: TextStyle(fontSize: 12, color: Color(0xFF788273)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
