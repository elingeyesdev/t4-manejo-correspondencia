import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:t4_movil/compartido/api/cliente_api.dart';

void main() {
  test('sin autoridad de piloto conserva el transporte habitual', () {
    final cliente = crearClienteApi('http://localhost:8000');
    addTearDown(cliente.close);
    expect(cliente, isNot(isA<ClienteApiDelOrigen>()));
  });

  for (final caso in <(String, String, String)>[
    ('http://piloto.test:443', 'https://piloto.test:443', 'YQ=='),
    ('https://otro.test:443', 'https://piloto.test:443', 'YQ=='),
    ('https://piloto.test:444', 'https://piloto.test:443', 'YQ=='),
    ('https://piloto.test', 'https://piloto.test/otra-ruta', 'YQ=='),
    ('https://piloto.test', 'https://usuario@piloto.test', 'YQ=='),
    ('https://piloto.test', 'https://piloto.test?opcion=1', 'YQ=='),
    ('https://piloto.test', 'https://piloto.test', ''),
    ('https://piloto.test', '', 'YQ=='),
  ]) {
    test('rechaza configuración fuera del origen ${caso.$1} ${caso.$2}', () {
      expect(
        () => crearClienteApi(
          caso.$1,
          origenCertificado: caso.$2,
          certificadoBase64: caso.$3,
        ),
        throwsArgumentError,
      );
    });
  }

  test('no envía credenciales a otro origen ni sigue redirecciones', () async {
    var enviados = 0;
    final transporte = MockClient((request) async {
      enviados++;
      expect(request.followRedirects, false);
      return http.Response(
        '',
        302,
        headers: {'location': 'https://otro.test/'},
      );
    });
    final cliente = ClienteApiDelOrigen(transporte, 'https://piloto.test');
    addTearDown(cliente.close);
    for (final url in [
      'https://otro.test/api/sesiones',
      'http://piloto.test/api/sesiones',
      'https://piloto.test:444/api/sesiones',
    ]) {
      await expectLater(
        () => cliente.post(
          Uri.parse(url),
          headers: {'Authorization': 'ficticia'},
        ),
        throwsA(isA<http.ClientException>()),
      );
    }
    expect(enviados, 0);
    final respuesta = await cliente.get(Uri.parse('https://piloto.test/api/'));
    expect(respuesta.statusCode, 302);
    expect(enviados, 1);
  });

  group('validación TLS real', () {
    late HttpServer servidor;
    final carpeta = 'test/fixtures/tls_piloto';
    String origen(String host) => 'https://$host:${servidor.port}';
    http.Client conCa(String ca, [String host = '127.0.0.1']) =>
        crearClienteApi(
          origen(host),
          origenCertificado: origen(host),
          certificadoBase64: base64Encode(
            File('$carpeta/$ca').readAsBytesSync(),
          ),
        );

    setUp(() async {
      final contexto = SecurityContext()
        ..useCertificateChain('$carpeta/servidor.crt')
        ..usePrivateKey('$carpeta/servidor.key');
      servidor = await HttpServer.bindSecure(
        InternetAddress.anyIPv4,
        0,
        contexto,
      );
      servidor.listen(
        (request) {
          request.response.write('piloto');
          request.response.close();
        },
        onError: (Object error) {
          // Un rechazo TLS del cliente también interrumpe su conexión al servidor.
        },
      );
    });
    tearDown(() => servidor.close(force: true));

    test('acepta el servidor con su CA y nombre válidos', () async {
      final cliente = conCa('ca.crt');
      addTearDown(cliente.close);
      final respuesta = await cliente.get(
        Uri.parse('${origen('127.0.0.1')}/up'),
      );
      expect(respuesta.statusCode, 200);
      expect(respuesta.body, 'piloto');
    });

    test('rechaza una CA diferente', () async {
      final cliente = conCa('otra-ca.crt');
      addTearDown(cliente.close);
      await expectLater(
        cliente.get(Uri.parse('${origen('127.0.0.1')}/up')),
        throwsA(isA<http.ClientException>()),
      );
    });

    test('la CA del piloto no modifica el cliente global', () async {
      final piloto = conCa('ca.crt');
      addTearDown(piloto.close);
      expect(
        (await piloto.get(Uri.parse('${origen('127.0.0.1')}/up'))).statusCode,
        200,
      );
      final normal = http.Client();
      addTearDown(normal.close);
      await expectLater(
        normal.get(Uri.parse('${origen('127.0.0.1')}/up')),
        throwsA(isA<HandshakeException>()),
      );
    });

    test('conserva la verificación del nombre del servidor', () async {
      final cliente = conCa('ca.crt', '127.0.0.2');
      addTearDown(cliente.close);
      await expectLater(
        cliente.get(Uri.parse('${origen('127.0.0.2')}/up')),
        throwsA(
          isA<http.ClientException>().having(
            (error) => error.message.toLowerCase(),
            'error de nombre',
            contains('mismatch'),
          ),
        ),
      );
    });
  });
}
