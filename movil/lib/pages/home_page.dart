import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onConsultar});
  final VoidCallback onConsultar;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              'Sistema de Correspondencia',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text('Consulte el estado de su envío con el número de guía.'),
            const SizedBox(height: 32),
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: const Color(0xFFF4F5F2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Consultar envío'),
                subtitle: const Text('Buscar por número de guía'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onConsultar,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
