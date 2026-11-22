import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/funciones/notas_internas/notas_api.dart';
import 'package:t4_movil/funciones/notas_internas/detalle_nota_page.dart';
import 'package:t4_movil/funciones/notas_internas/firmar_nota_page.dart';
import 'package:t4_movil/funciones/notas_internas/firma_nota.dart';

import 'notas_internas_test.dart' as fixture;

const _reservada = '11111111-1111-4111-8111-111111111111';
String get _claveLocal =>
    'correspondencia.nota.intento.v1.${base64Url.encode(utf8.encode(jsonEncode(['http://api.test', '1', 'nota-1', 'conformidad'])))}';

Map<String, String> _registroAnterior() => {
  _claveLocal: jsonEncode({
    'schema': 1,
    'origen': 'http://api.test',
    'cuenta': '1',
    'nota': 'nota-1',
    'accion': 'conformidad',
    'clave': _reservada,
    'version': 3,
  }),
};

Map<String, dynamic> _confirmada() => {
  ...fixture.nota(version: 4, acciones: []),
  'movimientos_nota': [
    {
      'accion': 'conformidad',
      'actor': {'id': 1, 'nombre': 'VÍA ficticia'},
      'fecha': '2026-11-22T20:00:00Z',
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues(_registroAnterior()));

  testWidgets('actualización captura y reabre con clave y versión originales', (
    tester,
  ) async {
    final posts = <http.Request>[];
    var aplicada = false;
    Future<http.Response> responder(http.Request r) async {
      if (r.method == 'POST') {
        posts.add(r);
        expect(r.headers['Idempotency-Key'], _reservada);
        final payload = jsonDecode(r.body);
        expect(payload['version'], 3);
        expect(() => FirmaNota.desdeJson(payload['firma']), returnsNormally);
        final guardado = jsonDecode(
          (await const FlutterSecureStorage().read(key: _claveLocal))!,
        );
        expect(guardado['schema'], 2);
        expect(guardado['clave'], _reservada);
        expect(guardado['firma'], payload['firma']);
        if (posts.length == 1) return fixture.respuesta({}, 202);
        aplicada = true;
        return fixture.respuesta(_confirmada());
      }
      return fixture.respuesta(aplicada ? _confirmada() : fixture.nota());
    }

    final api = fixture.conectar(responder);
    await fixture.abrir(tester, DetalleNotaPage(api: api, id: 'nota-1'));
    await fixture.pulsar(tester, 'Firmar y recuperar el mismo intento');
    expect(find.byType(FirmarNotaPage), findsOneWidget);
    expect(posts, isEmpty);
    expect(find.text('3'), findsOneWidget);
    await fixture.pulsar(tester, 'Confirmar');
    expect(posts, hasLength(1));
    expect(find.text('Comprobar mismo intento'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    final renovada = fixture.conectar(responder)..token = 'sesion-renovada';
    await tester.pumpWidget(
      MaterialApp(
        home: DetalleNotaPage(api: renovada, id: 'nota-1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FirmarNotaPage), findsNothing);
    await fixture.pulsar(tester, 'Comprobar mismo intento');
    expect(posts, hasLength(2));
    expect(posts.first.body, posts.last.body);
    expect(posts.last.headers['Authorization'], 'Bearer sesion-renovada');
    expect(await const FlutterSecureStorage().read(key: _claveLocal), isNull);
    expect(find.text('Conformidad registrada.'), findsOneWidget);
  });

  testWidgets('cancelar la captura conserva el registro antiguo sin enviarlo', (
    tester,
  ) async {
    var posts = 0;
    final api = fixture.conectar((r) async {
      if (r.method == 'POST') posts++;
      return fixture.respuesta(fixture.nota());
    });
    await fixture.abrir(tester, DetalleNotaPage(api: api, id: 'nota-1'));
    await fixture.pulsar(tester, 'Firmar y recuperar el mismo intento');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(posts, 0);
    expect(
      jsonDecode(
        (await const FlutterSecureStorage().read(key: _claveLocal))!,
      )['clave'],
      _reservada,
    );
    expect(find.text('Firmar y recuperar el mismo intento'), findsOneWidget);
  });

  testWidgets('no dibuja una firma sobre contenido de otra versión', (
    tester,
  ) async {
    var posts = 0;
    final api = fixture.conectar((r) async {
      if (r.method == 'POST') posts++;
      return fixture.respuesta(fixture.nota(version: 4));
    });
    await fixture.abrir(tester, DetalleNotaPage(api: api, id: 'nota-1'));
    await fixture.pulsar(tester, 'Firmar y recuperar el mismo intento');
    expect(find.byType(FirmarNotaPage), findsNothing);
    expect(
      find.textContaining('No se puede firmar el intento anterior'),
      findsOneWidget,
    );
    expect(
      await const FlutterSecureStorage().read(key: _claveLocal),
      isNotNull,
    );
    expect(posts, 0);
  });

  testWidgets(
    'una conformidad anterior aplicada se reconcilia sin otra firma',
    (tester) async {
      var posts = 0;
      final api = fixture.conectar((r) async {
        if (r.method == 'POST') posts++;
        return fixture.respuesta(_confirmada());
      });
      await fixture.abrir(tester, DetalleNotaPage(api: api, id: 'nota-1'));
      expect(find.byType(FirmarNotaPage), findsNothing);
      expect(await const FlutterSecureStorage().read(key: _claveLocal), isNull);
      expect(posts, 0);
    },
  );

  testWidgets(
    'cambiar de cuenta durante la firma conserva la reserva anterior',
    (tester) async {
      var posts = 0;
      final api = fixture.conectar((r) async {
        if (r.method == 'POST') posts++;
        return fixture.respuesta(fixture.nota());
      });
      await fixture.abrir(tester, DetalleNotaPage(api: api, id: 'nota-1'));
      await fixture.pulsar(tester, 'Firmar y recuperar el mismo intento');
      api
        ..token = 'otra-sesion'
        ..cuentaId = '2';
      await fixture.pulsar(tester, 'Confirmar');
      expect(posts, 0);
      expect(
        jsonDecode(
          (await const FlutterSecureStorage().read(key: _claveLocal))!,
        )['clave'],
        _reservada,
      );
      expect(await NotasApi(api).pendientePara('nota-1'), isNull);
    },
  );

  test(
    'un 422 posterior no elimina una clave de conformidad reservada',
    () async {
      final posts = <http.Request>[];
      final api = fixture.conectar((r) async {
        posts.add(r);
        return posts.length == 1
            ? fixture.respuesta({
                'message': 'Validación de firma pendiente',
              }, 422)
            : fixture.respuesta(_confirmada());
      });
      var servicio = NotasApi(api);
      final original = (await servicio.pendientePara('nota-1'))!;
      await expectLater(
        servicio.ejecutar(
          original.conFirma(FirmaNota.desdeJson(fixture.firmaPrueba)),
        ),
        throwsA(isA<ErrorLaravel>()),
      );
      servicio = NotasApi(api);
      final recuperada = (await servicio.pendientePara('nota-1'))!;
      await servicio.ejecutar(recuperada);
      expect(recuperada.clave, _reservada);
      expect(posts.first.body, posts.last.body);
      expect(await servicio.pendientePara('nota-1'), isNull);
    },
  );

  test('dos capturas no reemplazan una firma pendiente ya guardada', () async {
    final posts = <http.Request>[];
    final api = fixture.conectar((r) async {
      posts.add(r);
      return fixture.respuesta({}, 202);
    });
    final servicio = NotasApi(api);
    final anterior = (await servicio.pendientePara('nota-1'))!;
    final primera = anterior.conFirma(FirmaNota.desdeJson(fixture.firmaPrueba));
    await expectLater(servicio.ejecutar(primera), throwsA(isA<ErrorLaravel>()));
    final distinta = anterior.conFirma(
      FirmaNota.desdeJson([
        [
          [10, 20],
          [30, 40],
        ],
      ]),
    );
    await expectLater(
      servicio.ejecutar(distinta),
      throwsA(isA<ErrorLaravel>()),
    );
    expect(posts, hasLength(1));
    expect(
      (await servicio.pendientePara('nota-1'))!.firma!.toJson(),
      fixture.firmaPrueba,
    );
  });

  test(
    'actualización conserva la reserva anterior cuando falta la firma',
    () async {
      final posts = <http.Request>[];
      final api = fixture.conectar((r) async {
        posts.add(r);
        return fixture.respuesta({
          'message': 'Dibuja la firma antes de confirmar.',
          'errors': {
            'firma': ['Dibuja la firma antes de confirmar.'],
          },
        }, 422);
      });
      final servicio = NotasApi(api);
      final intento = (await servicio.pendientePara('nota-1'))!;
      expect(intento.clave, _reservada);
      expect(intento.firma, isNull);
      await expectLater(
        servicio.ejecutar(intento),
        throwsA(isA<ErrorLaravel>()),
      );
      expect(
        await const FlutterSecureStorage().read(key: _claveLocal),
        isNotNull,
        reason: 'La actualización no puede perder la reserva de Laravel.',
      );
      expect(
        posts,
        isEmpty,
        reason:
            'Primero se debe pedir la firma, sin enviar un POST incompleto.',
      );
    },
  );
}
