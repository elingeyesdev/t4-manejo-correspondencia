import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ErrorLaravel implements Exception {
  const ErrorLaravel(
    this.mensaje, {
    this.estado,
    this.errores = const {},
    this.codigo,
  });
  final String mensaje;
  final int? estado;
  final String? codigo;
  final Map<String, String> errores;
}

class ApiLaravel {
  ApiLaravel({
    this.baseUrl = ApiConfig.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;
  final Duration timeout;
  String? token;
  Future<void> Function()? alVencerSesion;

  Future<Map<String, dynamic>> enviar(
    String metodo,
    String ruta, {
    Map<String, dynamic>? datos,
    Map<String, String> cabeceras = const {},
    bool autenticado = true,
  }) async {
    final tokenEnviado = token;
    if (autenticado && (tokenEnviado == null || tokenEnviado.isEmpty)) {
      throw const ErrorLaravel('Inicia sesión para continuar.', estado: 401);
    }
    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/$ruta',
    );
    final headers = {
      'Accept': 'application/json',
      if (datos != null) 'Content-Type': 'application/json; charset=utf-8',
      if (autenticado) 'Authorization': 'Bearer $tokenEnviado',
      ...cabeceras,
    };
    http.Response response;
    try {
      final request = http.Request(metodo, uri)..headers.addAll(headers);
      if (datos != null) request.body = jsonEncode(datos);
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } on TimeoutException {
      throw const ErrorLaravel(
        'El servidor tardó demasiado. Revisa la conexión y vuelve a intentar.',
      );
    } on http.ClientException {
      throw const ErrorLaravel(
        'No se pudo conectar con el servidor. Revisa la conexión.',
      );
    }
    return await _interpretar(response, tokenEnviado, autenticado);
  }

  Future<Map<String, dynamic>> _interpretar(
    http.Response response,
    String? tokenEnviado,
    bool autenticado,
  ) async {
    if (response.statusCode == 401) {
      if (autenticado && token == tokenEnviado) await alVencerSesion?.call();
      throw const ErrorLaravel(
        'Tu sesión venció. Vuelve a ingresar.',
        estado: 401,
      );
    }
    if (response.statusCode == 204) return {};
    Map<String, dynamic>? body;
    try {
      final parsed = jsonDecode(utf8.decode(response.bodyBytes));
      if (parsed is Map<String, dynamic>) body = parsed;
    } on FormatException {
      /* La respuesta se valida antes de utilizarla. */
    }
    final errors = <String, String>{};
    if (body?['errors'] case final Map map) {
      for (final entry in map.entries) {
        if (entry.key is String) {
          final value = entry.value;
          if (value is List && value.every((e) => e is String)) {
            errors[entry.key as String] = value.join('\n');
          } else if (value is String) {
            errors[entry.key as String] = value;
          }
        }
      }
    }
    if (response.statusCode >= 400) {
      final mensaje = switch (response.statusCode) {
        403 => 'No tienes permiso para realizar esta operación o tu cuenta fue deshabilitada.',
        404 =>
          body?['codigo'] == 'GUIA_NO_ENCONTRADA'
              ? 'No se encontró un envío con ese número de guía.'
              : 'El documento no está disponible.',
        409 => 'La solicitud cambió o ya se utilizó con otros datos. Revisa el registro antes de continuar.',
        422 => 'Revisa los datos ingresados.',
        429 =>
          'Demasiados intentos. Espera un momento antes de volver a ingresar.',
        _ => 'El servidor no pudo completar la operación. Intenta nuevamente.',
      };
      throw ErrorLaravel(
        mensaje,
        estado: response.statusCode,
        errores: errors,
        codigo: body?['codigo'] is String ? body!['codigo'] as String : null,
      );
    }
    if (body == null) {
      throw const ErrorLaravel(
        'No se pudo interpretar la respuesta del servidor.',
      );
    }
    return body;
  }

  /// Transporte autenticado de archivos; nunca sigue enlaces externos ni redirecciones.
  Future<http.Response> enviarArchivo(
    http.BaseRequest request, {
    Duration? limite,
  }) async {
    final origen = Uri.parse(baseUrl);
    if (request.url.origin != origen.origin ||
        !request.url.path.startsWith(
          '${origen.path.replaceAll(RegExp(r'/+$'), '')}/api/',
        )) {
      throw const ErrorLaravel('La dirección del adjunto no es válida.');
    }
    final enviado = token;
    if (enviado == null || enviado.isEmpty) {
      throw const ErrorLaravel('Inicia sesión para continuar.', estado: 401);
    }
    request.headers['Authorization'] = 'Bearer $enviado';
    request.headers['Accept'] = 'application/json';
    request.followRedirects = false;
    final espera = limite ?? timeout;
    Future<http.Response> recibir() async {
      final streamed = await _client.send(request);
      const maximo = 10 * 1024 * 1024 + 64 * 1024;
      if ((streamed.contentLength ?? 0) > maximo) {
        await streamed.stream.listen(null).cancel();
        throw const ErrorLaravel(
          'El archivo recibido supera el tamaño permitido.',
        );
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in streamed.stream) {
        if (bytes.length + chunk.length > maximo) {
          throw const ErrorLaravel(
            'El archivo recibido supera el tamaño permitido.',
          );
        }
        bytes.add(chunk);
      }
      return http.Response.bytes(
        bytes.takeBytes(),
        streamed.statusCode,
        headers: streamed.headers,
      );
    }

    http.Response response;
    try {
      response = await recibir().timeout(espera);
    } on TimeoutException {
      throw const ErrorLaravel(
        'El servidor tardó demasiado. Revisa la conexión.',
        codigo: 'RESPUESTA_INCIERTA',
      );
    } on http.ClientException {
      throw const ErrorLaravel(
        'No se pudo conectar con el servidor.',
        codigo: 'RESPUESTA_INCIERTA',
      );
    }
    if (token != enviado) {
      throw const ErrorLaravel(
        'Tu sesión cambió. Vuelve a abrir el documento.',
        estado: 401,
      );
    }
    if (response.statusCode >= 300) {
      if (response.statusCode < 400) {
        throw const ErrorLaravel('El servidor intentó redirigir la descarga.');
      }
      await _interpretar(response, enviado, true);
    }
    return response;
  }

  void close() => _client.close();
}

String nuevaClaveSolicitud() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
