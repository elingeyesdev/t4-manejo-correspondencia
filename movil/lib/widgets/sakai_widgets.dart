import 'package:flutter/material.dart';

import '../theme/sakai_theme.dart';

class SakaiIcon extends StatelessWidget {
  const SakaiIcon(
    this.icon, {
    super.key,
    this.color = Sakai.blue,
    this.background = Sakai.blueLight,
    this.size = 44,
  });
  final IconData icon;
  final Color color, background;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: color, size: 22),
  );
}

class SakaiPanel extends StatelessWidget {
  const SakaiPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: padding, child: child),
  );
}

class SakaiStatus extends StatelessWidget {
  const SakaiStatus(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final registered = status.toUpperCase() == 'REGISTRADA';
    final label = registered ? 'Registrada' : status.replaceAll('_', ' ');
    return Semantics(
      label: 'Estado: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: registered ? Sakai.mint : Sakai.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: registered ? Sakai.green : Sakai.ink,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class SakaiSection extends StatelessWidget {
  const SakaiSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.color = Sakai.blue,
    this.background = Sakai.blueLight,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final Color color, background;
  @override
  Widget build(BuildContext context) => SakaiPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SakaiIcon(icon, color: color, background: background, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class SakaiField extends StatelessWidget {
  const SakaiField(this.label, this.value, {super.key});
  final String label;
  final Object? value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final text = SelectableText(
          '${value ?? 'Sin información'}',
          style: const TextStyle(color: Sakai.ink, fontSize: 14),
        );
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 19) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Sakai.muted)),
              const SizedBox(height: 4),
              text,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Text(label, style: const TextStyle(color: Sakai.muted)),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 6, child: text),
          ],
        );
      },
    ),
  );
}

String sakaiDate(Object? value) {
  final raw = value?.toString() ?? '';
  final date = DateTime.tryParse(raw);
  if (date == null) return raw.isEmpty ? 'Sin fecha' : raw;
  // Fechas de documento sin zona; eventos del servidor se presentan localmente.
  final local = raw.contains('T') ? date.toLocal() : date;
  final day =
      '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  return raw.contains('T')
      ? '$day · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}'
      : day;
}
