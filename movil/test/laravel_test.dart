import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:t4_movil/main.dart';
import 'package:t4_movil/pages/registro_laravel_page.dart';
import 'package:t4_movil/services/consulta_envio_service.dart';
import 'package:t4_movil/services/laravel_api.dart';
import 'package:t4_movil/services/sesion_controller.dart';

class AlmacenMemoria implements AlmacenSesion {
  String? valor;
  bool fallar = false;
  @override
  Future<String?> leer() async => valor;
  @override
  Future<void> guardar(String v) async {
    if (fallar) throw StateError('almacenamiento');
    valor = v;
  }

  @override
  Future<void> eliminar() async {
    valor = null;
  }
}

final usuario = {
  'id': 1,
  'name': 'Recepción',
  'role': 'recepcion',
  'unit_id': 1,
};
final documento = {
  'id': 'c0d57e32-b6d0-480c-ac05-c6b8531deffb',
  'guia': 'COR-2026-01ABCDEF',
  'codigo': 'DOC-2026-01ABCDEF',
  'estado': 'REGISTRADA',
  'fechaUltimoMovimiento': '2026-10-24T14:30:00Z',
  'remitente': 'Dirección',
  'asunto': 'Solicitud',
  'fecha': '2026-10-24',
  'hoja': {'codigo': 'HR-2026-01ABCDEF'},
};
final configuracion = {
  'tipos': [
    {'id': 1, 'name': 'Oficio'},
  ],
  'prioridades': [
    {'id': 2, 'name': 'Normal'},
  ],
  'unidades': [
    {'id': 3, 'name': 'Recepción'},
  ],
};
http.Response json(Object data, [int estado = 200]) => http.Response(
  jsonEncode(data),
  estado,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
ApiLaravel apiMock(FutureOr<http.Response> Function(http.Request) f) =>
    ApiLaravel(
      baseUrl: 'http://localhost:8000',
      client: MockClient((r) async => f(r)),
    );

void main() {
  test(
    '404 de otra ruta no se interpreta como guía inexistente en Laravel',
    () async {
      final api = apiMock((_) => json({}, 404))..token = 'token';
      addTearDown(api.close);
      await expectLater(
        ConsultaEnvioApi(api: api).consultar('COR-123'),
        throwsA(isA<ConsultaEnvioException>()),
      );
    },
  );
  testWidgets('sesión vencida cierra también el detalle privado', (
    tester,
  ) async {
    var vencido = false;
    final api = apiMock((r) {
      if (vencido) return json({}, 401);
      if (r.url.path.endsWith('/sesiones')) {
        return json({'token': 'token', 'user': usuario});
      }
      if (r.url.path == '/api/documentos') {
        return json({
          'data': [documento],
          'last_page': 1,
        });
      }
      return json(documento);
    });
    final s = SesionController(api: api, almacen: AlmacenMemoria());
    addTearDown(api.close);
    addTearDown(s.dispose);
    await s.ingresar('a@b.test', 'clave');
    await tester.pumpWidget(CorrespondenciaApp(sesion: s));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mi bandeja'));
    await tester.tap(find.text('Mi bandeja'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Solicitud'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle de correspondencia'), findsOneWidget);
    vencido = true;
    await expectLater(
      api.enviar('GET', 'documentos'),
      throwsA(isA<ErrorLaravel>()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Detalle de correspondencia'), findsNothing);
  });

  test(
    'sesión real de contrato, credencial protegida y cierre revocable',
    () async {
      final llamadas = <http.Request>[];
      final api = apiMock((r) {
        llamadas.add(r);
        return r.method == 'DELETE'
            ? http.Response('', 204)
            : json({'token': 'secreto-local', 'user': usuario});
      });
      final almacen = AlmacenMemoria();
      final sesion = SesionController(api: api, almacen: almacen);
      addTearDown(api.close);
      addTearDown(sesion.dispose);
      await sesion.ingresar(' recepcion@example.test ', 'ClavePrivada123');
      expect(sesion.autenticada, true);
      expect(sesion.puedeRegistrar, true);
      expect(llamadas.first.url.path, '/api/sesiones');
      expect(
        jsonDecode(llamadas.first.body)['email'],
        'recepcion@example.test',
      );
      expect(llamadas.first.headers.containsKey('Authorization'), false);
      expect(jsonDecode(almacen.valor!)['token'], 'secreto-local');
      expect(almacen.valor, isNot(contains('ClavePrivada123')));
      await sesion.salir();
      expect(sesion.autenticada, false);
      expect(almacen.valor, null);
      expect(llamadas.last.url.path, '/api/sesiones/actual');
      expect(llamadas.last.headers['Authorization'], 'Bearer secreto-local');
    },
  );
  test('401 borra sesión protegida y no inventa datos', () async {
    final api = apiMock(
      (r) => r.url.path.endsWith('/sesiones')
          ? json({'token': 'token', 'user': usuario})
          : json({}, 401),
    );
    final almacen = AlmacenMemoria();
    final sesion = SesionController(api: api, almacen: almacen);
    addTearDown(api.close);
    addTearDown(sesion.dispose);
    await sesion.ingresar('a@b.test', 'clave');
    await expectLater(
      ConsultaEnvioApi(api: api).consultar('GUIA'),
      throwsA(isA<ConsultaEnvioException>()),
    );
    expect(sesion.autenticada, false);
    expect(almacen.valor, null);
  });
  test('credencial rechazada 422 no crea sesión', () async {
    final api = apiMock((_) => json({}, 422));
    final almacen = AlmacenMemoria();
    final s = SesionController(api: api, almacen: almacen);
    addTearDown(api.close);
    addTearDown(s.dispose);
    await s.ingresar('a@b.test', 'incorrecta');
    expect(s.autenticada, false);
    expect(almacen.valor, null);
    expect(s.mensaje, contains('no válidos'));
  });
  test('fallo al proteger token revoca y rechaza acceso', () async {
    var revoco = false;
    final api = apiMock((r) {
      if (r.method == 'DELETE') {
        revoco = true;
        return http.Response('', 204);
      }
      return json({'token': 'token', 'user': usuario});
    });
    final s = SesionController(
      api: api,
      almacen: AlmacenMemoria()..fallar = true,
    );
    addTearDown(api.close);
    addTearDown(s.dispose);
    await s.ingresar('a@b.test', 'clave');
    expect(s.autenticada, false);
    expect(revoco, true);
    expect(api.token, null);
  });
  test(
    'restauración valida token en Laravel y vencimiento local lo elimina',
    () async {
      var peticiones = 0;
      final api = apiMock((r) {
        peticiones++;
        return json({'data': []});
      });
      final a = AlmacenMemoria();
      a.valor = jsonEncode({
        'token': 'guardado',
        'usuario': usuario,
        'origen': api.baseUrl,
        'vence': DateTime.now()
            .toUtc()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });
      final s = SesionController(api: api, almacen: a);
      addTearDown(api.close);
      addTearDown(s.dispose);
      await s.restaurar();
      expect(s.autenticada, true);
      expect(peticiones, 1);
      final otro = SesionController(api: api, almacen: a);
      addTearDown(otro.dispose);
      a.valor = jsonEncode({
        'token': 'vencido',
        'usuario': usuario,
        'origen': api.baseUrl,
        'vence': '2020-01-01T00:00:00Z',
      });
      await otro.restaurar();
      expect(otro.autenticada, false);
      expect(a.valor, null);
      expect(peticiones, 1);
    },
  );
  test('consulta autenticada interpreta guía Laravel y 404', () async {
    final api = apiMock((r) {
      expect(r.headers['Authorization'], 'Bearer token');
      expect(r.url.path, '/api/correspondencia/guia/COR-2026-01ABCDEF');
      return json(documento);
    })..token = 'token';
    addTearDown(api.close);
    final resultado = await ConsultaEnvioApi(api: api)
        .consultar('COR-2026-01ABCDEF');
    expect(resultado!.numeroGuia, documento['guia']);
    final ausente = apiMock((_) => json({'codigo': 'GUIA_NO_ENCONTRADA'}, 404))
      ..token = 'token';
    addTearDown(ausente.close);
    expect(await ConsultaEnvioApi(api: ausente).consultar('INEXISTENTE'), null);
  });
  for (final codigo in [403, 409, 422, 429, 500]) {
    test('HTTP $codigo se informa y conserva validaciones', () async {
      final api = apiMock(
        (_) => json({
          'errors': {
            'remitente': ['Revisa el remitente.'],
          },
        }, codigo),
      )..token = 'token';
      addTearDown(api.close);
      await expectLater(
        api.enviar('POST', 'documentos', datos: {}),
        throwsA(
          isA<ErrorLaravel>()
              .having((e) => e.estado, 'estado', codigo)
              .having(
                (e) => e.errores['remitente'],
                'campo',
                'Revisa el remitente.',
              ),
        ),
      );
    });
  }
  test('sin token no envía solicitudes protegidas', () async {
    var llamadas = 0;
    final api = apiMock((_) {
      llamadas++;
      return json({});
    });
    addTearDown(api.close);
    await expectLater(
      api.enviar('GET', 'documentos'),
      throwsA(isA<ErrorLaravel>()),
    );
    expect(llamadas, 0);
  });
  test('corte de red no devuelve éxito', () async {
    final api = apiMock((_) => throw http.ClientException('offline'))
      ..token = 'token';
    addTearDown(api.close);
    await expectLater(
      api.enviar('GET', 'documentos'),
      throwsA(isA<ErrorLaravel>().having((e) => e.estado, 'sin HTTP', null)),
    );
  });
  test('claves de reintento son UUID distintos', () {
    final claves = List.generate(100, (_) => nuevaClaveSolicitud());
    expect(claves.toSet().length, 100);
    expect(
      claves.every(
        (c) => RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ).hasMatch(c),
      ),
      true,
    );
  });
  testWidgets('acceso valida y funcionario no ve registro', (tester) async {
    final api = apiMock(
      (_) => json({
        'token': 'token',
        'user': {...usuario, 'role': 'funcionario'},
      }),
    );
    final s = SesionController(api: api, almacen: AlmacenMemoria());
    addTearDown(api.close);
    addTearDown(s.dispose);
    await tester.pumpWidget(CorrespondenciaApp(sesion: s));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa un correo válido.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.test');
    await tester.enterText(find.byType(TextFormField).at(1), 'clave');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Consultar envío'), findsOneWidget);
    expect(find.text('Nueva correspondencia'), findsNothing);
    expect(find.text('Mi bandeja'), findsOneWidget);
  });
  testWidgets('registro usa catálogos reales y conserva clave en reintento', (
    tester,
  ) async {
    final claves = <String>[];
    var intentos = 0;
    final api = apiMock((r) {
      if (r.method == 'GET') return json(configuracion);
      final data = jsonDecode(r.body);
      expect(data['tipo_id'], 1);
      expect(data['prioridad_id'], 2);
      expect(data['unidad_id'], 3);
      expect(data.containsKey('tipoDocumento'), false);
      claves.add(r.headers['Idempotency-Key']!);
      intentos++;
      if (intentos == 1) throw http.ClientException('offline');
      return json(documento, 201);
    })..token = 'token';
    addTearDown(api.close);
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RegistroLaravelPage(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Dirección');
    await tester.enterText(find.byType(TextFormField).at(1), 'Solicitud');
    await tester.tap(find.byType(DropdownButtonFormField<int>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oficio').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Normal').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Registrar correspondencia'));
    await tester.tap(find.text('Registrar correspondencia'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No se pudo conectar'), findsOneWidget);
    await tester.ensureVisible(find.text('Registrar correspondencia'));
    await tester.tap(find.text('Registrar correspondencia'));
    await tester.pumpAndSettle();
    expect(claves[0], claves[1]);
    expect(find.text(documento['guia'] as String), findsOneWidget);
    expect(find.text('Correspondencia registrada'), findsOneWidget);
  });
}
