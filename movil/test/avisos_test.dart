import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:t4_movil/main.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/funciones/iniciar_sesion/sesion_controller.dart';
import 'package:t4_movil/funciones/notificaciones/avisos_api.dart';
import 'package:t4_movil/funciones/notificaciones/avisos_controller.dart';
import 'package:t4_movil/funciones/notificaciones/transporte_push.dart';
import 'package:t4_movil/funciones/notas_internas/detalle_nota_page.dart';

import 'notas_internas_test.dart' as fixture;

class PushPrueba implements TransportePush {
  final abiertosController = StreamController<String>.broadcast();
  final recibidosController = StreamController<String>.broadcast();
  final tokensController = StreamController<String>.broadcast();
  bool permiso = true, configurado = true, borrado = false;
  String? desdeCerrada;
  String tokenActual = 'fcm-ficticio-1';
  Completer<bool>? esperandoPermiso;
  @override
  Stream<String> get abiertos => abiertosController.stream;
  @override
  Stream<String> get recibidos => recibidosController.stream;
  @override
  Stream<String> get tokens => tokensController.stream;
  @override
  Future<bool> iniciar() async => configurado;
  @override
  Future<bool> pedirPermiso() async => esperandoPermiso?.future ?? permiso;
  @override
  Future<String?> token() async => tokenActual;
  @override
  Future<String?> inicial() async => desdeCerrada;
  @override
  Future<void> borrarToken() async {
    borrado = true;
  }

  @override
  Future<void> cancelarVisibles() async {}
  @override
  Future<void> cerrar() async {
    await abiertosController.close();
    await recibidosController.close();
    await tokensController.close();
  }
}

class SesionMemoria implements AlmacenSesion {
  @override
  Future<String?> leer() async => null;
  @override
  Future<void> guardar(String valor) async {}
  @override
  Future<void> eliminar() async {}
}

Map<String, dynamic> aviso() => {
  'id': 'aviso-1',
  'nota_id': 'nota-1',
  'tipo': 'revision_via_pendiente',
  'creada_en': '2026-11-22T20:00:00Z',
  'leida_en': null,
};
Map<String, dynamic> pagina() => {
  'data': [aviso()],
  'no_leidas': 1,
  'meta': {'current_page': 1, 'last_page': 1, 'per_page': 15, 'total': 1},
};

SesionController sesion(
  Future<http.Response> Function(http.Request) responder,
) {
  final api =
      ApiLaravel(baseUrl: 'http://api.test', client: MockClient(responder))
        ..token = 'token-1'
        ..cuentaId = '1';
  final s = SesionController(api: api, almacen: SesionMemoria())
    ..inicializada = true
    ..usuario = {
      'id': 1,
      'name': 'Funcionario ficticio',
      'role': 'funcionario',
    };
  addTearDown(() {
    s.dispose();
    api.close();
  });
  return s;
}

Future<void> drenar() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('registra y rota el token sobre la misma instalación, y desvincula antes de salir', () async {
    final requests = <http.Request>[];
    final s = sesion((r) async {
      requests.add(r);
      return r.method == 'GET'
          ? fixture.respuesta(pagina())
          : http.Response('', 204);
    });
    final push = PushPrueba();
    final c = AvisosController(sesion: s, push: push);
    addTearDown(c.dispose);
    await c.iniciar();
    await drenar();
    push.tokenActual = 'fcm-rotado';
    push.tokensController.add('fcm-rotado');
    await drenar();
    final puts = requests.where((r) => r.method == 'PUT').toList();
    expect(puts.length, 2);
    expect(puts.first.url, puts.last.url);
    expect(jsonDecode(puts.last.body)['token_fcm'], 'fcm-rotado');
    await s.salir();
    final deletes = requests.where((r) => r.method == 'DELETE').toList();
    expect(deletes.first.url.path, contains('/notificaciones/dispositivos/'));
    expect(deletes.last.url.path, '/api/sesiones/actual');
    expect(push.borrado, isTrue);
    expect(c.pagina, isNull);
  });
  test(
    'permiso denegado conserva el centro de avisos sin registrar un token',
    () async {
      final requests = <http.Request>[];
      final s = sesion((r) async {
        requests.add(r);
        return fixture.respuesta(pagina());
      });
      final push = PushPrueba()..permiso = false;
      final c = AvisosController(sesion: s, push: push);
      addTearDown(c.dispose);
      await c.iniciar();
      await drenar();
      expect(requests.every((r) => r.method == 'GET'), isTrue);
      expect(c.pagina?.noLeidas, 1);
    },
  );
  test('deduplica avisos abiertos y en primer plano', () async {
    final s = sesion(
      (r) async => r.method == 'GET'
          ? fixture.respuesta(pagina())
          : http.Response('', 204),
    );
    final push = PushPrueba();
    final c = AvisosController(sesion: s, push: push);
    addTearDown(c.dispose);
    await c.iniciar();
    await drenar();
    push.abiertosController.add('aviso-1');
    await drenar();
    expect(c.pendiente, 'aviso-1');
    c.consumido('aviso-1');
    push.abiertosController.add('aviso-1');
    await drenar();
    expect(c.pendiente, isNull);
    push.recibidosController.add('aviso-1');
    await drenar();
    expect(c.avisoVisible, 'aviso-1');
    c.abrir('aviso-1');
    push.recibidosController.add('aviso-1');
    await drenar();
    expect(c.avisoVisible, isNull);
  });
  test('un permiso que termina después de cambiar de cuenta no registra datos antiguos', () async {
    final puts = <http.Request>[];
    final s = sesion((r) async {
      if (r.method == 'PUT') puts.add(r);
      return fixture.respuesta(pagina());
    });
    final permiso = Completer<bool>();
    final push = PushPrueba()..esperandoPermiso = permiso;
    final c = AvisosController(sesion: s, push: push);
    addTearDown(c.dispose);
    await c.iniciar();
    await drenar();
    await s.invalidar();
    permiso.complete(true);
    await drenar();
    expect(puts, isEmpty);
    expect(c.pagina, isNull);
  });
  test(
    'resuelve el ID por el servidor y no marca leído si la nota devuelve 404',
    () async {
      final rutas = <String>[];
      final s = sesion((r) async {
        rutas.add('${r.method} ${r.url.path}');
        return r.url.path.contains('/notificaciones/')
            ? fixture.respuesta(aviso())
            : fixture.respuesta({}, 404);
      });
      await expectLater(
        AvisosApi(s.api).resolver('aviso-1'),
        throwsA(isA<ErrorLaravel>()),
      );
      expect(rutas, [
        'GET /api/notificaciones/aviso-1',
        'GET /api/notas-internas/nota-1',
      ]);
      await expectLater(
        AvisosApi(s.api).resolver('https://otro.test'),
        throwsA(isA<ErrorLaravel>()),
      );
      expect(rutas.length, 2);
    },
  );
  test('arranque desde aviso espera autenticación y descarta el aviso al cambiar de cuenta', () async {
    final requests = <http.Request>[];
    final s = sesion((r) async {
      requests.add(r);
      if (r.url.path == '/api/sesiones') {
        return fixture.respuesta({
          'token': 'sesion-nueva',
          'user': {
            'id': 1,
            'name': 'Funcionario ficticio',
            'role': 'funcionario',
          },
        });
      }
      return r.method == 'GET'
          ? fixture.respuesta(pagina())
          : http.Response('', 204);
    });
    s.usuario = null;
    s.api.token = null;
    s.api.cuentaId = null;
    final push = PushPrueba()..desdeCerrada = 'aviso-1';
    final c = AvisosController(sesion: s, push: push);
    addTearDown(c.dispose);
    await c.iniciar();
    await drenar();
    expect(c.pendiente, 'aviso-1');
    expect(requests, isEmpty);
    await s.ingresar('ficticio@example.test', 'solo-dato-ficticio');
    await drenar();
    expect(c.pendiente, 'aviso-1');
    await s.invalidar();
    await drenar();
    expect(c.pendiente, isNull);
    expect(c.pagina, isNull);
  });
  testWidgets(
    'tocar el aviso en arranque frío abre la nota autorizada y después marca leído',
    (tester) async {
      final rutas = <String>[];
      final s = sesion((r) async {
        rutas.add('${r.method} ${r.url.path}');
        if (r.method == 'PUT') return http.Response('', 204);
        if (r.url.path == '/api/notificaciones') {
          return fixture.respuesta(pagina());
        }
        if (r.url.path == '/api/notificaciones/aviso-1') {
          return fixture.respuesta(aviso());
        }
        return fixture.respuesta(fixture.nota(acciones: []));
      });
      final push = PushPrueba()..desdeCerrada = 'aviso-1';
      await tester.pumpWidget(CorrespondenciaApp(sesion: s, push: push));
      await tester.pumpAndSettle();
      expect(find.byType(DetalleNotaPage), findsOneWidget);
      final cargar = rutas.indexOf('GET /api/notas-internas/nota-1');
      final leer = rutas.indexOf('PUT /api/notificaciones/aviso-1/lectura');
      expect(cargar, greaterThanOrEqualTo(0));
      expect(leer, greaterThan(cargar));
      expect(rutas.where((r) => r.startsWith('POST')), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
