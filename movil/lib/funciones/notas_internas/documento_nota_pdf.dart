import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../compartido/api/laravel_api.dart';

class DocumentoNotaPdf {
  DocumentoNotaPdf._(this.bytes, this.version);
  final Uint8List bytes;
  final int version;

  factory DocumentoNotaPdf.desdeRespuesta(
    http.Response respuesta,
    int version,
  ) {
    final bytes = respuesta.bodyBytes;
    final mime = respuesta.headers['content-type']
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    final recibida = int.tryParse(respuesta.headers['x-note-version'] ?? '');
    if (respuesta.statusCode != 200 ||
        mime != 'application/pdf' ||
        recibida != version ||
        bytes.length < 10 ||
        ascii.decode(bytes.take(5).toList(), allowInvalid: true) != '%PDF-' ||
        !ascii
            .decode(
              bytes.sublist(bytes.length > 1024 ? bytes.length - 1024 : 0),
              allowInvalid: true,
            )
            .contains('%%EOF')) {
      throw const ErrorLaravel(
        'No se pudo comprobar el documento completo de esta versión. Vuelve a cargar la nota.',
      );
    }
    return DocumentoNotaPdf._(
      Uint8List.fromList(bytes).asUnmodifiableView(),
      version,
    );
  }
}
