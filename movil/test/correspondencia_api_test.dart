import 'dart:async';
import 'dart:convert';

import 'package:t4_movil/config/api_config.dart';
import 'package:t4_movil/models/correspondencia.dart';
import 'package:t4_movil/services/correspondencia_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

CorrespondenciaApi apiConfigurada({required http.Client client}) =>
    CorrespondenciaApi(
      client: client,
      endpoint: Uri.parse('https://registro.example.test/api/correspondencias'),
    );

void main() {
  test('sin endpoint configurado no envía ninguna solicitud', () async {
    expect(ApiConfig.registroEndpoint, isNull);
    var llamadas = 0;
    final api = CorrespondenciaApi(
      client: MockClient((_) async {
        llamadas++;
        return http.Response('{}', 201);
      }),
    );
    addTearDown(api.close);
    expect(api.configurada, isFalse);
    await expectLater(
      api.registrar(
        Correspondencia(
          remitente: 'Prueba',
          asunto: 'Prueba',
          tipoDocumento: 'Carta',
          fechaRecepcion: DateTime(2026, 10, 21),
        ),
      ),
      throwsA(isA<ApiException>()),
    );
    expect(llamadas, 0);
  });
  final entrada = Correspondencia(
    remitente: ' Junta Vecinal ',
    asunto: ' Alumbrado público ',
    tipoDocumento: 'Carta',
    fechaRecepcion: DateTime(2026, 10, 12),
  );
  test('envía POST JSON y utiliza el correlativo del servidor', () async {
    final api = apiConfigurada(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url,
          Uri.parse('https://registro.example.test/api/correspondencias'),
        );
        expect(request.headers['content-type'], contains('application/json'));
        expect(jsonDecode(request.body), {
          'remitente': 'Junta Vecinal',
          'asunto': 'Alumbrado público',
          'tipoDocumento': 'Carta',
          'fechaRecepcion': '2026-10-12',
        });
        return http.Response(
          jsonEncode({
            'id': 37,
            'correlativo': 'CORR-0037',
            'mensaje': 'Correspondencia registrada correctamente.',
          }),
          201,
        );
      }),
    );
    addTearDown(api.close);
    final resultado = await api.registrar(entrada);
    expect(resultado.id, 37);
    expect(resultado.correlativo, 'CORR-0037');
  });
  test('interpreta los cuatro errores de validación 400', () async {
    final api = apiConfigurada(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'errores': [
              for (final campo in [
                'remitente',
                'asunto',
                'tipoDocumento',
                'fechaRecepcion',
              ])
                {'campo': campo, 'mensaje': 'Revise $campo.'},
            ],
          }),
          400,
        ),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      api.registrar(entrada),
      throwsA(
        isA<ApiException>().having((e) => e.errores.length, 'errores', 4),
      ),
    );
  });
  for (final status in [200, 500]) {
    test('no considera éxito HTTP $status', () async {
      final api = apiConfigurada(
        client: MockClient((_) async => http.Response('{}', status)),
      );
      addTearDown(api.close);
      await expectLater(api.registrar(entrada), throwsA(isA<ApiException>()));
    });
  }
  test('rechaza 201 sin correlativo', () async {
    final api = apiConfigurada(
      client: MockClient(
        (_) async => http.Response('{"id":1,"mensaje":"ok"}', 201),
      ),
    );
    addTearDown(api.close);
    await expectLater(api.registrar(entrada), throwsA(isA<ApiException>()));
  });
  test('convierte fallo de conexión en mensaje entendible', () async {
    final api = apiConfigurada(
      client: MockClient(
        (_) async => throw http.ClientException('Connection refused'),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      api.registrar(entrada),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensaje,
          'mensaje',
          contains('No se pudo conectar'),
        ),
      ),
    );
  });
  test(
    'convierte timeout en mensaje sin éxito ni reintento automático',
    () async {
      final api = apiConfigurada(
        client: MockClient((_) async => throw TimeoutException('timeout')),
      );
      addTearDown(api.close);
      await expectLater(
        api.registrar(entrada),
        throwsA(
          isA<ApiException>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('Verifique el registro'),
          ),
        ),
      );
    },
  );
}
