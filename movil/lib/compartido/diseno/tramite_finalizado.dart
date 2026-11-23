import 'package:flutter/material.dart';

import 'institucional.dart';

class TramiteFinalizado extends StatelessWidget {
  const TramiteFinalizado({super.key});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Institucional.accion.withValues(alpha: .06),
      border: Border.all(color: Institucional.accion),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline, color: Institucional.accion),
        SizedBox(height: 8),
        Text(
          'Trámite finalizado',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text(
          'La nota está cerrada. Puedes seguir consultando el documento y su historial.',
        ),
      ],
    ),
  );
}

class VolverInicioFinalizado extends StatelessWidget {
  const VolverInicioFinalizado({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Institucional.borde)),
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.home_outlined),
        label: const Text('Volver al inicio'),
      ),
    ),
  );
}
