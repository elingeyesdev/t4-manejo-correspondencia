import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/correspondencia.dart';

class ApiException implements Exception {
  const ApiException(this.mensaje, {this.errores = const {}});
  final String mensaje;
  final Map<String, String> errores;
}

class CorrespondenciaApi {
  CorrespondenciaApi({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ?? ApiConfig.registroEndpoint;
  final http.Client _client;
  final Uri? _endpoint;
  bool get configurada => _endpoint != null;
  void close() => _client.close();
  Future<RegistroResultado> registrar(Correspondencia entrada) async {
    final endpoint = _endpoint;
    if (endpoint == null) {
      throw const ApiException(
        'El envío está pendiente de conexión a la API de registro. No se enviaron ni guardaron datos.',
      );
    }
    try {
      final response = await _client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(entrada.toJson()),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 201) {
        return RegistroResultado.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
        );
      }
      if (response.statusCode == 400) {
        final json =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final errores = <String, String>{};
        for (final item in (json['errores'] as List<dynamic>? ?? [])) {
          final error = item as Map<String, dynamic>;
          final campo = error['campo'];
          final mensaje = error['mensaje'];
          if (campo is String && mensaje is String) {
            errores.update(
              campo,
              (actual) => '$actual\n$mensaje',
              ifAbsent: () => mensaje,
            );
          }
        }
        throw ApiException('Revise los datos ingresados.', errores: errores);
      }
      throw const ApiException(
        'El servidor no pudo completar el registro. Intente nuevamente.',
      );
    } on TimeoutException {
      throw const ApiException(
        'El servidor tardó demasiado en responder. Verifique el registro antes de volver a enviarlo.',
      );
    } on http.ClientException {
      throw const ApiException(
        'No se pudo conectar con el servidor.\nVerifique que el servidor esté disponible e intente nuevamente.',
      );
    } on FormatException {
      throw const ApiException(
        'El servidor devolvió una respuesta que no se pudo interpretar. Verifique el registro antes de volver a enviarlo.',
      );
    } on TypeError {
      throw const ApiException(
        'El servidor devolvió una respuesta que no se pudo interpretar. Verifique el registro antes de volver a enviarlo.',
      );
    }
  }
}
