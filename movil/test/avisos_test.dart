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
  Completer<String?>? esperandoToken;
  Completer<void>? esperandoBorrado;
  Completer<void>? esperandoCancelacion;
  int canceladas = 0;
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
  Future<String?> token() async => esperandoToken?.future ?? tokenActual;
  @override
  Future<String?> inicial() async => desdeCerrada;
  @override
  Future<void> borrarToken() async {
    borrado = true;
    await esperandoBorrado?.future;
  }

  @override
  Future<void> cancelarVisibles() async {
    canceladas++;
    await esperandoCancelacion?.future;
  }

  @override
  Future<void> cerrar() async {
    await abiertosController.close();
    await recibidosController.close();
    await tokensController.close();
  }
}

class SesionMemoria implements AlmacenSesion {
  bool eliminada = false;
  @override
  Future<String?> leer() async => null;
  @override
  Future<void> guardar(String valor) async {}
  @override
  Future<void> eliminar() async {
    eliminada = true;
  }
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
  for (final fase in ['permiso', 'token', 'borrado', 'cancelacion']) {
    testWidgets(
      'cerrar sesión revoca Laravel si Firebase no responde en $fase',
      (tester) async {
        final rutas = <String>[];
        final s = sesion((r) async {
          rutas.add('${r.method} ${r.url.path}');
          return r.method == 'GET'
              ? fixture.respuesta(pagina())
              : http.Response('', 204);
        });
        final push = PushPrueba();
        if (fase == 'permiso') push.esperandoPermiso = Completer<bool>();
        if (fase == 'token') push.esperandoToken = Completer<String?>();
        if (fase == 'borrado') push.esperandoBorrado = Completer<void>();
        if (fase == 'cancelacion') {
          push.esperandoCancelacion = Completer<void>();
        }
        final c = AvisosController(sesion: s, push: push);
        addTearDown(c.dispose);
        await c.iniciar();
        await tester.pump();
        var termino = false;
        final salida = s.salir().then((_) => termino = true);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        expect(rutas, contains('DELETE /api/sesiones/actual'));
        expect(termino, isTrue);
        expect(s.autenticada, isFalse);
        expect(s.api.token, isNull);
        expect((s.almacen as SesionMemoria).eliminada, isTrue);
        push.esperandoPermiso?.complete(true);
        push.esperandoToken?.complete('token-tardio');
        push.esperandoBorrado?.complete();
        push.esperandoCancelacion?.complete();
        await tester.pump();
        await salida;
      },
    );
  }
  for (final fase in ['permiso', 'token', 'borrado']) {
    testWidgets('Firebase tardío en $fase no desvincula la cuenta nueva', (
      tester,
    ) async {
      final requests = <http.Request>[];
      final s = sesion((r) async {
        requests.add(r);
        if (r.url.path == '/api/sesiones') {
          return fixture.respuesta({
            'token': 'token-2',
            'user': {
              'id': 2,
              'name': 'Otra cuenta ficticia',
              'role': 'funcionario',
            },
          });
        }
        return r.method == 'GET'
            ? fixture.respuesta(pagina())
            : http.Response('', 204);
      });
      final permiso = Completer<bool>();
      final token = Completer<String?>();
      final borrado = Completer<void>();
      final push = PushPrueba();
      if (fase == 'permiso') push.esperandoPermiso = permiso;
      if (fase == 'token') push.esperandoToken = token;
      if (fase == 'borrado') push.esperandoBorrado = borrado;
      final c = AvisosController(sesion: s, push: push);
      addTearDown(c.dispose);
      await c.iniciar();
      await tester.pump();
      final salida = s.salir();
      await tester.pump(const Duration(seconds: 3));
      await salida;
      push.esperandoPermiso = null;
      push.esperandoToken = null;
      push.esperandoBorrado = null;
      push.tokenActual = 'fcm-cuenta-nueva';
      await s.ingresar('otra@example.test', 'solo-dato-ficticio');
      await tester.pump();
      final antes = requests
          .where(
            (r) =>
                r.method == 'PUT' &&
                r.headers['Authorization'] == 'Bearer token-2',
          )
          .length;
      expect(antes, 1);
      if (fase == 'permiso') permiso.complete(true);
      if (fase == 'token') token.complete('fcm-antiguo');
      if (fase == 'borrado') {
        push.tokenActual = 'fcm-tras-borrado-tardio';
        borrado.complete();
      }
      await tester.pump();
      expect(s.api.cuentaId, '2');
      expect(s.autenticada, isTrue);
      expect(
        requests.where(
          (r) =>
              r.method == 'DELETE' &&
              r.headers['Authorization'] == 'Bearer token-2',
        ),
        isEmpty,
      );
      final nuevos = requests
          .where(
            (r) =>
                r.method == 'PUT' &&
                r.headers['Authorization'] == 'Bearer token-2',
          )
          .toList();
      expect(nuevos.length, fase == 'borrado' ? 2 : 1);
      expect(jsonDecode(nuevos.last.body)['token_fcm'], push.tokenActual);
      expect(push.canceladas, 1);
    });
  }
  testWidgets('la baja y la revocación conservan el orden del PUT ya enviado', (
    tester,
  ) async {
    final rutas = <String>[];
    final registro = Completer<http.Response>();
    final s = sesion((r) async {
      rutas.add('${r.method} ${r.url.path}');
      if (r.method == 'PUT' && r.url.path.contains('/dispositivos/')) {
        return registro.future;
      }
      return r.method == 'GET'
          ? fixture.respuesta(pagina())
          : http.Response('', 204);
    });
    final c = AvisosController(sesion: s, push: PushPrueba());
    addTearDown(c.dispose);
    await c.iniciar();
    await tester.pump();
    final salida = s.salir();
    await tester.pump(const Duration(seconds: 3));
    expect(rutas.any((r) => r.startsWith('DELETE')), isFalse);
    registro.complete(http.Response('', 204));
    await tester.pump();
    await salida;
    final baja = rutas.indexWhere(
      (r) => r.startsWith('DELETE /api/notificaciones/dispositivos/'),
    );
    expect(baja, greaterThan(0));
    expect(rutas.indexOf('DELETE /api/sesiones/actual'), greaterThan(baja));
  });
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
    'dos avisos abren sus notas sin cerrar el primer detalle ni esperar su lectura',
    (tester) async {
      final rutas = <String>[];
      final lecturaPrimera = Completer<http.Response>();
      final s = sesion((r) async {
        rutas.add('${r.method} ${r.url.path}');
        if (r.url.path == '/api/notificaciones/aviso-1/lectura') {
          return lecturaPrimera.future;
        }
        if (r.method == 'PUT') return http.Response('', 204);
        if (r.url.path == '/api/notificaciones') {
          return fixture.respuesta(pagina());
        }
        if (r.url.path.startsWith('/api/notificaciones/')) {
          final segundo = r.url.path.endsWith('aviso-2');
          return fixture.respuesta({
            ...aviso(),
            if (segundo) 'id': 'aviso-2',
            if (segundo) 'nota_id': 'nota-2',
          });
        }
        return fixture.respuesta(
          fixture.nota(
            id: r.url.path.endsWith('nota-2') ? 'nota-2' : 'nota-1',
            acciones: [],
          ),
        );
      });
      final push = PushPrueba()..desdeCerrada = 'aviso-1';
      try {
        await tester.pumpWidget(CorrespondenciaApp(sesion: s, push: push));
        await tester.pumpAndSettle();
        expect(
          tester.widget<DetalleNotaPage>(find.byType(DetalleNotaPage)).id,
          'nota-1',
        );
        push.abiertosController.add('aviso-2');
        await tester.pumpAndSettle();
        expect(
          tester.widget<DetalleNotaPage>(find.byType(DetalleNotaPage)).id,
          'nota-2',
        );
        expect(
          find.byType(DetalleNotaPage, skipOffstage: false),
          findsNWidgets(2),
        );
        expect(rutas, contains('PUT /api/notificaciones/aviso-2/lectura'));
        expect(lecturaPrimera.isCompleted, isFalse);
      } finally {
        lecturaPrimera.complete(http.Response('', 204));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );
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
