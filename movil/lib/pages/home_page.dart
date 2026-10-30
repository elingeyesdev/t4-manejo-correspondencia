import 'package:flutter/material.dart';

import '../theme/sakai_theme.dart';
import '../widgets/sakai_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onConsultar,
    required this.onVerDiseno,
    required this.onNuevoRegistro,
    this.onBandeja,
    this.puedeRegistrar = true,
    this.nombre = '',
  });
  final bool puedeRegistrar;
  final String nombre;
  final VoidCallback? onBandeja;
  final VoidCallback onConsultar, onVerDiseno, onNuevoRegistro;

  Widget _acceso(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    required String descripcion,
    required VoidCallback onTap,
    Color color = Sakai.blue,
    Color fondo = Sakai.blueLight,
    bool destacado = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(destacado ? 20 : 16),
          child: Row(
            children: [
              SakaiIcon(
                icono,
                color: color,
                background: fondo,
                size: destacado ? 52 : 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      descripcion,
                      style: const TextStyle(color: Sakai.muted, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (destacado)
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Sakai.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PrimeIcons.chevronRight,
                    color: Colors.white,
                    size: 14,
                  ),
                )
              else
                const Icon(
                  PrimeIcons.chevronRight,
                  size: 14,
                  color: Sakai.muted,
                ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              nombre.isEmpty
                  ? 'Correspondencia\ninstitucional'
                  : 'Hola, ${nombre.trim().split(' ').first}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              nombre.isEmpty
                  ? 'Consulte el estado de su envío con el número de guía.'
                  : 'Gestiona los documentos de tu unidad.',
              style: const TextStyle(color: Sakai.muted, height: 1.5),
            ),
            const SizedBox(height: 26),
            _acceso(
              context,
              icono: PrimeIcons.search,
              titulo: 'Consultar envío',
              descripcion: 'Busca por número de guía',
              onTap: onConsultar,
              destacado: true,
            ),
            const SizedBox(height: 14),
            Text(
              'Accesos rápidos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            if (puedeRegistrar)
              _acceso(
                context,
                icono: PrimeIcons.plus,
                titulo: 'Nueva correspondencia',
                descripcion: 'Registrar un documento recibido',
                onTap: onNuevoRegistro,
                color: Sakai.green,
                fondo: Sakai.mint,
              ),
            if (onBandeja != null)
              _acceso(
                context,
                icono: PrimeIcons.inbox,
                titulo: 'Mi bandeja',
                descripcion: 'Documentos de tu unidad',
                onTap: onBandeja!,
              ),
            _acceso(
              context,
              icono: PrimeIcons.folder,
              titulo: 'Gestión documental',
              descripcion: 'Diseño de recepción y atención',
              onTap: onVerDiseno,
              color: Sakai.violet,
              fondo: Sakai.violetLight,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
