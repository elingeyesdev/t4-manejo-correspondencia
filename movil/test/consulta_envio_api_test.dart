import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:t4_movil/services/consulta_envio_service.dart';

void main() {
  const guia = 'COR-2026-000001';
  final registro = {
    'guia': guia,
    'estado': 'Registrado',
    'fechaUltimoMovimiento': '2026-10-15T12:30:00.000Z',
  };
  ConsultaEnvioApi crear(
    Future<http.Response> Function(http.Request) handler, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    final api = ConsultaEnvioApi(
      baseUrl: 'http://localhost:3000',
      client: MockClient(handler),
      timeout: timeout,
    );
    addTearDown(api.close);
    return api;
  }

  test('consulta la ruta real y conserva estado y fecha recibidos', () async {
    final api = crear((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        'http://localhost:3000/api/correspondencia/guia/$guia',
      );
      expect(request.headers['Accept'], 'application/json');
      return http.Response(jsonEncode(registro), 200);
    });
    final result = await api.consultar(' $guia ');
    expect(result!.numeroGuia, guia);
    expect(result.estado, 'Registrado');
    expect(result.fechaUltimoMovimiento, DateTime.utc(2026, 10, 15, 12, 30));
  });
  test('no consulta guías vacías', () async {
    var llamadas = 0;
    final api = crear((_) async {
      llamadas++;
      return http.Response('{}', 500);
    });
    await expectLater(
      api.consultar('  '),
      throwsA(isA<ConsultaEnvioException>()),
    );
    expect(llamadas, 0);
  });
  test('404 de guía inexistente devuelve null', () async {
    final api = crear(
      (_) async => http.Response('{"codigo":"GUIA_NO_ENCONTRADA"}', 404),
    );
    expect(await api.consultar(guia), isNull);
  });
  test('404 de ruta equivocada no se presenta como guía inexistente', () async {
    final api = crear(
      (_) async => http.Response('{"error":"Recurso no encontrado"}', 404),
    );
    await expectLater(
      api.consultar(guia),
      throwsA(isA<ConsultaEnvioException>()),
    );
  });
  test('409 informa que el registro antiguo no tiene seguimiento', () async {
    final api = crear((_) async => http.Response('{}', 409));
    await expectLater(
      api.consultar(guia),
      throwsA(
        isA<ConsultaEnvioException>().having(
          (e) => e.mensaje,
          'mensaje',
          contains('no tiene datos de seguimiento'),
        ),
      ),
    );
  });
  test('error de red se transforma en mensaje de conexión', () async {
    final api = crear(
      (_) async => throw http.ClientException('Connection refused'),
    );
    await expectLater(api.consultar(guia), throwsA(isA<ErrorConexion>()));
  });
  test('timeout no reintenta automáticamente', () async {
    var llamadas = 0;
    final api = crear((_) {
      llamadas++;
      return Completer<http.Response>().future;
    }, timeout: const Duration(milliseconds: 5));
    await expectLater(
      api.consultar(guia),
      throwsA(
        isA<ConsultaEnvioException>().having(
          (e) => e.mensaje,
          'mensaje',
          contains('tardó demasiado'),
        ),
      ),
    );
    expect(llamadas, 1);
  });
  for (final body in [
    '{}',
    '{"guia":"$guia","estado":"Registrado"}',
    '<html>error</html>',
    jsonEncode({...registro, 'guia': 'OTRA-GUIA'}),
  ]) {
    test(
      'respuesta incompleta, ilegible o de otra guía no fabrica resultados: $body',
      () async {
        final api = crear((_) async => http.Response(body, 200));
        await expectLater(
          api.consultar(guia),
          throwsA(isA<ConsultaEnvioException>()),
        );
      },
    );
  }
  test('error 500 muestra un mensaje sin datos técnicos', () async {
    final api = crear((_) async => http.Response('stack trace técnico', 500));
    await expectLater(
      api.consultar(guia),
      throwsA(
        isA<ConsultaEnvioException>().having(
          (e) => e.mensaje,
          'mensaje',
          isNot(contains('stack trace')),
        ),
      ),
    );
  });
}
