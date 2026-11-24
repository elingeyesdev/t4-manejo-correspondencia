import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cliente_api_web.dart'
    if (dart.library.io) 'cliente_api_io.dart'
    as plataforma;

http.Client crearClienteApi(
  String baseUrl, {
  String certificadoBase64 = const String.fromEnvironment('API_CA_CERT_BASE64'),
  String origenCertificado = const String.fromEnvironment('API_CA_ORIGIN'),
}) {
  if (certificadoBase64.isEmpty && origenCertificado.isEmpty) {
    return http.Client();
  }
  final base = Uri.tryParse(baseUrl);
  final origen = Uri.tryParse(origenCertificado);
  if (certificadoBase64.isEmpty ||
      base == null ||
      origen == null ||
      base.scheme != 'https' ||
      origen.scheme != 'https' ||
      base.host.isEmpty ||
      origen.host.isEmpty ||
      base.userInfo.isNotEmpty ||
      base.hasQuery ||
      base.hasFragment ||
      origen.userInfo.isNotEmpty ||
      (origen.path.isNotEmpty && origen.path != '/') ||
      origen.hasQuery ||
      origen.hasFragment ||
      base.origin != origen.origin) {
    throw ArgumentError('La autoridad del piloto requiere su origen HTTPS.');
  }
  final certificado = base64Decode(certificadoBase64);
  if (certificado.isEmpty) {
    throw ArgumentError('El certificado del piloto está vacío.');
  }
  return ClienteApiDelOrigen(
    plataforma.clienteConAutoridad(certificado),
    origen.origin,
  );
}

class ClienteApiDelOrigen extends http.BaseClient {
  ClienteApiDelOrigen(this._cliente, this._origen);
  final http.Client _cliente;
  final String _origen;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.scheme != 'https' || request.url.origin != _origen) {
      throw http.ClientException(
        'La solicitud no pertenece al servidor del piloto.',
        request.url,
      );
    }
    request.followRedirects = false;
    return _cliente.send(request);
  }

  @override
  void close() => _cliente.close();
}
