class FirmaNota {
  FirmaNota._(this.trazos);

  final List<List<List<int>>> trazos;

  factory FirmaNota.desdeJson(Object? valor) {
    if (valor is! List || valor.isEmpty || valor.length > 32) {
      throw const FormatException('La firma debe contener un trazo válido.');
    }
    var puntos = 0;
    var segmento = false;
    final trazos = <List<List<int>>>[];
    for (final trazo in valor) {
      if (trazo is! List || trazo.isEmpty || (puntos += trazo.length) > 2000) {
        throw const FormatException('La firma excede los límites permitidos.');
      }
      final normalizado = <List<int>>[];
      for (final punto in trazo) {
        if (punto is! List ||
            punto.length != 2 ||
            punto.any((p) => p is! int || p < 0 || p > 1000)) {
          throw const FormatException('La firma contiene puntos inválidos.');
        }
        final xy = List<int>.unmodifiable(punto.cast<int>());
        if (normalizado.isNotEmpty &&
            (xy[0] != normalizado.first[0] || xy[1] != normalizado.first[1])) {
          segmento = true;
        }
        normalizado.add(xy);
      }
      trazos.add(List.unmodifiable(normalizado));
    }
    if (!segmento) {
      throw const FormatException('Dibuja tu firma antes de confirmar.');
    }
    return FirmaNota._(List.unmodifiable(trazos));
  }

  List<List<List<int>>> toJson() => trazos;
}
