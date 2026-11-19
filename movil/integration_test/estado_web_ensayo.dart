bool contieneEstadoNotaWeb(String html, String codigo, String etiqueta) {
  final estados = RegExp(
    r'''data-state\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  ).allMatches(html).toList();
  if (estados.isNotEmpty) {
    return estados.any((e) => e.group(1)!.toLowerCase() == codigo);
  }
  return html.contains('<dd>$etiqueta</dd>');
}
