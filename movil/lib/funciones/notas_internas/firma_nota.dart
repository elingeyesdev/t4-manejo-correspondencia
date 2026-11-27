import 'imagen_constancia.dart';

class FirmaNota {
  FirmaNota._(this.trazos, {this.imagenFirma, this.imagenSello});

  final List<List<List<int>>> trazos;
  final ImagenConstancia? imagenFirma, imagenSello;
  bool get tieneFirma => trazos.isNotEmpty || imagenFirma != null;
  bool get tieneImagenes => imagenFirma != null || imagenSello != null;

  factory FirmaNota.constancia({
    FirmaNota? trazo,
    ImagenConstancia? firma,
    ImagenConstancia? sello,
  }) => FirmaNota._(
    trazo?.trazos ?? const [],
    imagenFirma: firma,
    imagenSello: sello,
  );

  factory FirmaNota.desdeConstanciaJson(Object? valor) {
    if (valor is! Map || valor['trazos'] is! List) {
      throw const FormatException('Constancia guardada inválida');
    }
    final puntos = valor['trazos'] as List;
    return FirmaNota.constancia(
      trazo: puntos.isEmpty ? null : FirmaNota.desdeJson(puntos),
      firma: valor['imagen_firma'] == null
          ? null
          : ImagenConstancia.desdeJson(valor['imagen_firma']),
      sello: valor['imagen_sello'] == null
          ? null
          : ImagenConstancia.desdeJson(valor['imagen_sello']),
    );
  }

  Map<String, dynamic> constanciaJson() => {
    'trazos': trazos,
    if (imagenFirma != null) 'imagen_firma': imagenFirma!.toJson(),
    if (imagenSello != null) 'imagen_sello': imagenSello!.toJson(),
  };

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
