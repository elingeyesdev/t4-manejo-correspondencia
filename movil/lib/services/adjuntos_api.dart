import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'camara_documento.dart';
import 'laravel_api.dart';

const limiteAdjunto = 10 * 1024 * 1024;
const tiposAdjunto = ['image/jpeg', 'image/png', 'application/pdf'];

class Adjunto {
  const Adjunto({
    required this.id,
    required this.documentoId,
    required this.nombre,
    required this.mime,
    required this.tamano,
    required this.fecha,
  });
  final String id, documentoId, nombre, mime, fecha;
  final int tamano;
  factory Adjunto.leer(Object? raw, String documentoId) {
    if (raw is! Map ||
        raw['id'] is! String ||
        (raw['id'] as String).isEmpty ||
        raw['document_id'] != documentoId ||
        raw['nombre'] is! String ||
        (raw['nombre'] as String).isEmpty ||
        !tiposAdjunto.contains(raw['mime']) ||
        raw['tamano_bytes'] is! int ||
        (raw['tamano_bytes'] as int) < 1 ||
        (raw['tamano_bytes'] as int) > limiteAdjunto ||
        raw['creado_en'] is! String) {
      throw const ErrorLaravel('Los datos del adjunto no son válidos.');
    }
    return Adjunto(
      id: raw['id'],
      documentoId: documentoId,
      nombre: raw['nombre'],
      mime: raw['mime'],
      tamano: raw['tamano_bytes'],
      fecha: raw['creado_en'],
    );
  }
  String get tamanoTexto => tamano < 1024 * 1024
      ? '${(tamano / 1024).ceil()} KB'
      : '${(tamano / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class PaginaAdjuntos {
  const PaginaAdjuntos(this.archivos, this.actual, this.ultima);
  final List<Adjunto> archivos;
  final int actual, ultima;
}

class ContenidoAdjunto {
  const ContenidoAdjunto(this.adjunto, this.bytes);
  final Adjunto adjunto;
  final Uint8List bytes;
}

class AdjuntosApi {
  const AdjuntosApi(this.api);
  final ApiLaravel api;
  String _ruta(String documento) =>
      'documentos/${Uri.encodeComponent(documento)}/adjuntos';
  Uri _url(String ruta) =>
      Uri.parse('${api.baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/$ruta');

  Future<PaginaAdjuntos> listar(String documento, {int pagina = 1}) async {
    final r = await api.enviar('GET', '${_ruta(documento)}?page=$pagina');
    if (r['data'] is! List ||
        r['current_page'] != pagina ||
        r['last_page'] is! int ||
        (r['last_page'] as int) < pagina) {
      throw const ErrorLaravel('La lista de adjuntos recibida no es válida.');
    }
    return PaginaAdjuntos(
      (r['data'] as List).map((e) => Adjunto.leer(e, documento)).toList(),
      pagina,
      r['last_page'],
    );
  }

  static String tipoFoto(Uint8List bytes) {
    if (bytes.length >= 8 &&
        listEquals(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10])) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'image/jpeg';
    }
    throw const ErrorLaravel(
      'La foto no tiene un formato válido. Vuelve a tomarla.',
    );
  }

  Future<Adjunto> subir(
    String documento,
    FotoDocumento foto,
    String nombre,
  ) async {
    if (foto.bytes.isEmpty || foto.bytes.length > limiteAdjunto) {
      throw const ErrorLaravel('La foto debe ocupar entre 1 byte y 10 MiB.');
    }
    final mime = tipoFoto(foto.bytes);
    final request = http.MultipartRequest('POST', _url(_ruta(documento)))
      ..files.add(
        http.MultipartFile.fromBytes(
          'archivo',
          foto.bytes,
          filename: nombre,
          contentType: MediaType.parse(mime),
        ),
      );
    http.Response respuesta;
    try {
      respuesta = await api.enviarArchivo(request, limite: api.timeout * 3);
    } on ErrorLaravel catch (e) {
      if (e.codigo == 'RESPUESTA_INCIERTA' || (e.estado ?? 0) >= 500) {
        throw const ErrorLaravel(
          'No pudimos confirmar la subida. Comprueba los adjuntos antes de volver a enviar.',
          codigo: 'SUBIDA_INCIERTA',
        );
      }
      if (e.estado == 422) {
        throw ErrorLaravel(
          e.errores['archivo'] ??
              'El servidor rechazó la foto. Revisa su formato y tamaño.',
          estado: 422,
        );
      }
      rethrow;
    }
    try {
      if (respuesta.statusCode != 201) throw const FormatException();
      final adjunto = Adjunto.leer(
        jsonDecode(utf8.decode(respuesta.bodyBytes)),
        documento,
      );
      if (adjunto.nombre != nombre ||
          adjunto.tamano != foto.bytes.length ||
          adjunto.mime != mime) {
        throw const FormatException();
      }
      return adjunto;
    } catch (_) {
      // El servidor pudo guardar el archivo aunque su confirmación sea ilegible.
      throw const ErrorLaravel(
        'La respuesta no permitió confirmar la subida. Comprueba los adjuntos.',
        codigo: 'SUBIDA_INCIERTA',
      );
    }
  }

  Future<ContenidoAdjunto> descargar(Adjunto adjunto) async {
    // Se construye la ruta propia: nunca se envía el token a descarga_url de otro origen.
    final ruta =
        '${_ruta(adjunto.documentoId)}/${Uri.encodeComponent(adjunto.id)}/descarga';
    final r = await api.enviarArchivo(http.Request('GET', _url(ruta)));
    final mime = r.headers['content-type']
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    if (r.statusCode != 200 ||
        mime != adjunto.mime ||
        r.bodyBytes.length != adjunto.tamano ||
        r.bodyBytes.length > limiteAdjunto) {
      throw const ErrorLaravel(
        'El archivo recibido está incompleto o no coincide con el adjunto.',
      );
    }
    return ContenidoAdjunto(adjunto, r.bodyBytes);
  }

  Future<Adjunto?> comprobar(
    String documento,
    FotoDocumento foto,
    String nombre,
  ) async {
    var pagina = 1;
    while (true) {
      final r = await listar(documento, pagina: pagina);
      for (final adjunto in r.archivos) {
        if (adjunto.nombre == nombre &&
            adjunto.tamano == foto.bytes.length &&
            adjunto.mime == tipoFoto(foto.bytes)) {
          final copia = await descargar(adjunto);
          if (listEquals(copia.bytes, foto.bytes)) return adjunto;
        }
      }
      if (pagina >= r.ultima) return null;
      pagina++;
    }
  }
}
