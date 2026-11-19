import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/funciones/notas_internas/almacen_intentos_nota.dart';
import 'package:t4_movil/funciones/notas_internas/detalle_nota_page.dart';
import 'package:t4_movil/funciones/notas_internas/nota_interna.dart';
import 'package:t4_movil/funciones/notas_internas/notas_api.dart';

import 'notas_internas_test.dart' as fixture;

class _Almacen implements AlmacenIntentosNota {
  final datos = <String, String>{};
  bool fallarLectura = false, fallarEscritura = false, fallarBorrado = false;
  @override
  Future<String?> leer(String clave) async {
    if (fallarLectura) throw StateError('Almacén inaccesible');
    return datos[clave];
  }

  @override
  Future<void> guardar(String clave, String valor) async {
    if (fallarEscritura) throw StateError('Almacén inaccesible');
    datos[clave] = valor;
  }

  @override
  Future<void> eliminar(String clave) async {
    if (fallarBorrado) throw StateError('Almacén inaccesible');
    datos.remove(clave);
  }
}

Map<String, dynamic> _estado(AccionNota accion, bool aplicada) {
  final datos = fixture.nota(
    version: aplicada ? 4 : 3,
    vinculada: aplicada && accion == AccionNota.primeraRecepcion,
    estado: accion == AccionNota.primeraRecepcion
        ? aplicada
              ? 'recibida'
              : 'pendiente_recepcion'
        : 'pendiente_revision',
    acciones: aplicada
        ? []
        : [
            accion == AccionNota.conformidad
                ? 'dar_conformidad'
                : 'confirmar_primera_recepcion',
          ],
  );
  if (aplicada && accion == AccionNota.conformidad) {
    datos['movimientos_nota'] = [
      {
        'id': 7,
        'accion': 'conformidad',
        'actor': {'id': 1, 'nombre': 'Funcionario ficticio'},
        'fecha': '2026-11-18T16:00:00Z',
        'estado_resultante': 'pendiente_revision',
      },
    ];
  }
  return datos;
}

ApiLaravel _api(
  Future<http.Response> Function(http.Request) responder, {
  String cuenta = '1',
  String token = 'token-1',
  String base = 'http://api.test',
}) {
  final api = ApiLaravel(baseUrl: base, client: MockClient(responder))
    ..token = token
    ..cuentaId = cuenta;
  addTearDown(api.close);
  return api;
}

SolicitudNota _solicitud(
  ApiLaravel api, [
  AccionNota accion = AccionNota.conformidad,
]) => SolicitudNota(
  nota: NotaInterna.desdeJson(_estado(accion, false)),
  accion: accion,
  token: api.token,
  cuentaId: api.cuentaId,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final accion in AccionNota.values) {
    for (final fallo in [
      '202',
      'respuesta perdida antes de aplicar',
      'respuesta perdida después de aplicar',
    ]) {
      testWidgets(
        '${accion.name}: reinicio tras $fallo conserva intención y evita duplicados',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(480, 1100));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final posts = <http.Request>[];
          final lecturas = <String>[];
          var aplicada = false, aplicaciones = 0;
          String? reservada;
          Future<http.Response> servidor(http.Request r) async {
            if (r.method == 'POST') {
              final almacenados = await const FlutterSecureStorage().readAll();
              final valores = almacenados.values.map(jsonDecode).toList();
              expect(
                valores.any(
                  (v) =>
                      v['clave'] == r.headers['Idempotency-Key'] &&
                      v['version'] == 3 &&
                      v['cuenta'] == '1' &&
                      v['accion'] == accion.name,
                ),
                isTrue,
                reason:
                    'El intento debe estar guardado antes de enviar el POST.',
              );
              posts.add(r);
              reservada ??= r.headers['Idempotency-Key'];
              if (r.headers['Idempotency-Key'] != reservada ||
                  jsonDecode(r.body)['version'] != 3) {
                return fixture.respuesta({}, 409);
              }
              if (posts.length == 1) {
                if (fallo == '202') return fixture.respuesta({}, 202);
                if (fallo.endsWith('después de aplicar')) {
                  aplicada = true;
                  aplicaciones++;
                }
                throw http.ClientException('Respuesta perdida');
              }
              if (!aplicada) {
                aplicada = true;
                aplicaciones++;
              }
              return fixture.respuesta(_estado(accion, aplicada));
            }
            lecturas.add(r.url.path);
            if (r.url.path.endsWith('/hojas/hoja-1')) {
              return fixture.respuesta({
                'id': 'doc-1',
                'hoja': {'id': 'hoja-1', 'version': 1},
                'acciones_permitidas': [],
              });
            }
            return fixture.respuesta(_estado(accion, aplicada));
          }

          final anterior = _api(servidor);
          await fixture.abrir(
            tester,
            DetalleNotaPage(api: anterior, id: 'nota-1'),
          );
          await fixture.pulsar(tester, accion.titulo);
          await fixture.pulsar(tester, 'Confirmar');
          expect(find.byKey(const ValueKey('nota-confirmada')), findsNothing);
          expect(await const FlutterSecureStorage().readAll(), isNotEmpty);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          anterior.close();
          lecturas.clear();
          final nueva = _api(servidor, token: 'token-renovado');
          await tester.pumpWidget(
            MaterialApp(
              home: DetalleNotaPage(api: nueva, id: 'nota-1'),
            ),
          );
          await tester.pumpAndSettle();
          expect(lecturas.first, '/api/notas-internas/nota-1');
          if (!aplicada) {
            expect(find.text('Comprobar mismo intento'), findsOneWidget);
            await fixture.pulsar(tester, 'Comprobar mismo intento');
            expect(posts.length, 2);
            expect(
              posts[1].headers['Idempotency-Key'],
              posts[0].headers['Idempotency-Key'],
            );
            expect(posts[1].body, posts[0].body);
            expect(posts[1].headers['Authorization'], 'Bearer token-renovado');
          } else {
            expect(
              posts.length,
              1,
              reason: 'El GET confirma la acción y evita otro POST.',
            );
            expect(find.textContaining('ya está registrada.'), findsOneWidget);
          }
          expect(aplicaciones, 1);
          expect(await const FlutterSecureStorage().readAll(), isEmpty);
          expect(find.text('Comprobar mismo intento'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final accion in AccionNota.values) {
    testWidgets(
      '${accion.name}: reserva tras 429 conserva clave y versión al reiniciar',
      (tester) async {
        final posts = <http.Request>[];
        var aplicada = false, aplicaciones = 0;
        String? claveReservada;
        Future<http.Response> servidor(http.Request r) async {
          if (r.method == 'POST') {
            posts.add(r);
            claveReservada ??= r.headers['Idempotency-Key'];
            if (r.headers['Idempotency-Key'] != claveReservada ||
                jsonDecode(r.body)['version'] != 3) {
              return fixture.respuesta({}, 409);
            }
            if (posts.length == 1) return fixture.respuesta({}, 202);
            if (posts.length == 2) {
              return http.Response(
                '<html>Too Many Requests</html>',
                429,
                headers: {'content-type': 'text/html', 'retry-after': '1'},
              );
            }
            if (!aplicada) {
              aplicada = true;
              aplicaciones++;
            }
            return fixture.respuesta(_estado(accion, aplicada));
          }
          if (r.url.path.endsWith('/hojas/hoja-1')) {
            return fixture.respuesta({
              'id': 'doc-1',
              'hoja': {'id': 'hoja-1', 'version': 1},
              'acciones_permitidas': [],
            });
          }
          return fixture.respuesta(_estado(accion, aplicada));
        }

        final api = _api(servidor);
        await fixture.abrir(tester, DetalleNotaPage(api: api, id: 'nota-1'));
        await fixture.pulsar(tester, accion.titulo);
        await fixture.pulsar(tester, 'Confirmar');
        await fixture.pulsar(tester, 'Comprobar mismo intento');
        expect(posts.length, 2);
        expect(find.byKey(const ValueKey('nota-confirmada')), findsNothing);
        expect(
          await const FlutterSecureStorage().readAll(),
          isNotEmpty,
          reason: 'Un 429 no demuestra que la reserva anterior haya sido rechazada.',
        );
        expect(find.text('Comprobar mismo intento'), findsOneWidget);
        expect(
          find.textContaining('se conservaron su clave y versión'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        api.close();
        final reiniciada = _api(servidor, token: 'sesion-renovada');
        await tester.pumpWidget(
          MaterialApp(
            home: DetalleNotaPage(api: reiniciada, id: 'nota-1'),
          ),
        );
        await tester.pumpAndSettle();
        await fixture.pulsar(tester, 'Comprobar mismo intento');
        expect(posts.length, 3);
        expect(posts.map((r) => r.headers['Idempotency-Key']).toSet(), {
          claveReservada,
        });
        expect(posts.map((r) => r.body).toSet(), {
          jsonEncode({'version': 3}),
        });
        expect(posts.last.headers['Authorization'], 'Bearer sesion-renovada');
        expect(aplicaciones, 1);
        expect(await const FlutterSecureStorage().readAll(), isEmpty);
        expect(find.text('Comprobar mismo intento'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('no transmite la acción si falla guardar o leer el almacén', () async {
    for (final escritura in [true, false]) {
      var posts = 0;
      final almacen = _Almacen()
        ..fallarEscritura = escritura
        ..fallarLectura = !escritura;
      final api = _api((r) async {
        posts++;
        return fixture.respuesta(_estado(AccionNota.conformidad, true));
      });
      await expectLater(
        NotasApi(api, almacen: almacen).ejecutar(_solicitud(api)),
        throwsA(
          isA<ErrorLaravel>().having(
            (e) => e.codigo,
            'codigo',
            'ALMACEN_LOCAL',
          ),
        ),
      );
      expect(posts, 0);
    }
  });

  test('el intento persiste por cuenta, servidor, nota y acción sin guardar credenciales', () async {
    final almacen = _Almacen();
    final api = _api((r) async => fixture.respuesta({}, 202));
    final solicitud = _solicitud(api);
    await expectLater(
      NotasApi(api, almacen: almacen).ejecutar(solicitud),
      throwsA(isA<ErrorLaravel>()),
    );
    final guardado = jsonDecode(almacen.datos.values.single) as Map;
    expect(guardado.keys.toSet(), {
      'schema',
      'origen',
      'cuenta',
      'nota',
      'accion',
      'clave',
      'version',
    });
    expect(almacen.datos.values.single.contains('token-1'), isFalse);
    final otra = _api((r) async => fixture.respuesta({}), cuenta: '2');
    final otroServidor = _api(
      (r) async => fixture.respuesta({}),
      base: 'http://otro.test',
    );
    expect(
      await NotasApi(otra, almacen: almacen).pendientePara('nota-1'),
      isNull,
    );
    expect(
      await NotasApi(otroServidor, almacen: almacen).pendientePara('nota-1'),
      isNull,
    );
    expect(
      await NotasApi(api, almacen: almacen).pendientePara('otra-nota'),
      isNull,
    );
    final restaurada = await NotasApi(
      _api((r) async => fixture.respuesta({}), token: 'sesion-nueva'),
      almacen: almacen,
    ).pendientePara('nota-1');
    expect(restaurada?.clave, solicitud.clave);
    expect(restaurada?.accion, solicitud.accion);
    expect(restaurada?.version, solicitud.version);
    expect(restaurada?.token, 'sesion-nueva');
  });

  test('no descarta una conformidad por un cambio de versión sin prueba de su actor', () async {
    final almacen = _Almacen();
    final api = _api((r) async => fixture.respuesta({}, 202));
    final servicio = NotasApi(api, almacen: almacen);
    final solicitud = _solicitud(api);
    await expectLater(
      servicio.ejecutar(solicitud),
      throwsA(isA<ErrorLaravel>()),
    );
    final otraConformidad = _estado(AccionNota.conformidad, true);
    (otraConformidad['movimientos_nota'] as List).first['actor']['id'] = 2;
    expect(
      await servicio.confirmarSiAplicado(
        NotaInterna.desdeJson(otraConformidad),
        solicitud,
      ),
      isFalse,
    );
    expect((await servicio.pendientePara('nota-1'))?.clave, solicitud.clave);
  });

  test(
    'un almacén ilegible bloquea intentos nuevos sin borrar el anterior',
    () async {
      var posts = 0;
      final almacen = _Almacen();
      final api = _api((r) async {
        posts++;
        return fixture.respuesta({}, 202);
      });
      final servicio = NotasApi(api, almacen: almacen);
      await expectLater(
        servicio.ejecutar(_solicitud(api)),
        throwsA(isA<ErrorLaravel>()),
      );
      almacen.datos[almacen.datos.keys.single] = '{ilegible';
      await expectLater(
        servicio.ejecutar(_solicitud(api)),
        throwsA(
          isA<ErrorLaravel>().having(
            (e) => e.codigo,
            'codigo',
            'ALMACEN_LOCAL',
          ),
        ),
      );
      expect(posts, 1);
      expect(almacen.datos, isNotEmpty);
    },
  );

  test(
    'un fallo al limpiar se recupera consultando el resultado, sin otro POST',
    () async {
      var posts = 0;
      final almacen = _Almacen()..fallarBorrado = true;
      final api = _api((r) async {
        posts++;
        return fixture.respuesta(_estado(AccionNota.conformidad, true));
      });
      final servicio = NotasApi(api, almacen: almacen),
          solicitud = _solicitud(api);
      await expectLater(
        servicio.ejecutar(solicitud),
        throwsA(
          isA<ErrorLaravel>().having(
            (e) => e.codigo,
            'codigo',
            'LIMPIEZA_PENDIENTE',
          ),
        ),
      );
      expect(almacen.datos, isNotEmpty);
      almacen.fallarBorrado = false;
      expect(
        await servicio.confirmarSiAplicado(
          NotaInterna.desdeJson(_estado(AccionNota.conformidad, true)),
          solicitud,
        ),
        isTrue,
      );
      expect(almacen.datos, isEmpty);
      expect(posts, 1);
    },
  );

  test(
    'dos pantallas no sobrescriben la reserva con una clave nueva',
    () async {
      final almacen = _Almacen();
      final recibido = Completer<void>(),
          respuesta = Completer<http.Response>();
      var posts = 0;
      final api = _api((r) async {
        posts++;
        recibido.complete();
        return respuesta.future;
      });
      final servicio = NotasApi(api, almacen: almacen);
      final primera = _solicitud(api);
      final primerResultado = expectLater(
        servicio.ejecutar(primera),
        throwsA(isA<ErrorLaravel>()),
      );
      await recibido.future;
      final segundoResultado = expectLater(
        servicio.ejecutar(_solicitud(api)),
        throwsA(
          isA<ErrorLaravel>().having(
            (e) => e.codigo,
            'codigo',
            'INTENTO_EXISTENTE',
          ),
        ),
      );
      respuesta.complete(fixture.respuesta({}, 202));
      await Future.wait([primerResultado, segundoResultado]);
      expect(posts, 1);
      expect((await servicio.pendientePara('nota-1'))?.clave, primera.clave);
    },
  );
}
