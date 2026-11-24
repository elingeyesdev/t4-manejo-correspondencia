import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client clienteConAutoridad(List<int> certificado) {
  final contexto = SecurityContext(withTrustedRoots: false)
    ..setTrustedCertificatesBytes(certificado);
  return _TransporteTlsPiloto(IOClient(HttpClient(context: contexto)));
}

class _TransporteTlsPiloto extends http.BaseClient {
  _TransporteTlsPiloto(this._cliente);
  final IOClient _cliente;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      return await _cliente.send(request);
    } on HandshakeException catch (error) {
      throw http.ClientException(
        'No se pudo validar el certificado del servidor. $error',
        request.url,
      );
    }
  }

  @override
  void close() => _cliente.close();
}
