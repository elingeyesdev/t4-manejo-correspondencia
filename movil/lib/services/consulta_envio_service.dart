import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/envio_consulta.dart';

abstract interface class ConsultaEnvioService {
  Future<EnvioConsulta?> consultar(String numeroGuia);
}

class ConsultaEnvioException implements Exception {
  const ConsultaEnvioException(this.mensaje);
  final String mensaje;
}

class ErrorConexion extends ConsultaEnvioException {
  const ErrorConexion()
    : super('No se pudo conectar con el servidor. Intente nuevamente.');
}

class ConsultaEnvioApi implements ConsultaEnvioService {
  ConsultaEnvioApi({
    this.baseUrl = ApiConfig.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();
  final String baseUrl;
  final Duration timeout;
  final http.Client _client;
  void close() => _client.close();

  @override
  Future<EnvioConsulta?> consultar(String numeroGuia) async {
    final guia = numeroGuia.trim();
    if (guia.isEmpty) {
      throw const ConsultaEnvioException('Ingrese el número de guía.');
    }
    try {
      final response = await _client
          .get(
            ApiConfig.consulta(guia, base: baseUrl),
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is! Map<String, dynamic>) {
          throw const FormatException('Respuesta no válida.');
        }
        final envio = EnvioConsulta.fromJson(body);
        if (envio.numeroGuia.toUpperCase() != guia.toUpperCase()) {
          throw const FormatException('Guía diferente.');
        }
        return envio;
      }
      if (response.statusCode == 404) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map<String, dynamic> &&
            body['codigo'] == 'GUIA_NO_ENCONTRADA') {
          return null;
        }
      }
      if (response.statusCode == 409) {
        throw const ConsultaEnvioException(
          'El envío existe, pero todavía no tiene datos de seguimiento registrados.',
        );
      }
      if (response.statusCode == 400) {
        throw const ConsultaEnvioException(
          'Revise el número de guía e intente nuevamente.',
        );
      }
      throw const ConsultaEnvioException(
        'El servidor no pudo completar la consulta. Intente nuevamente.',
      );
    } on http.ClientException {
      throw const ErrorConexion();
    } on TimeoutException {
      throw const ConsultaEnvioException(
        'El servidor tardó demasiado en responder. Intente nuevamente.',
      );
    } on FormatException {
      throw const ConsultaEnvioException(
        'No se pudo interpretar la respuesta del servidor. Intente nuevamente.',
      );
    }
  }
}
