import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/funciones/notas_internas/bandeja_notas_page.dart';
import 'package:t4_movil/funciones/notas_internas/detalle_nota_page.dart';
import 'package:t4_movil/funciones/notas_internas/nota_interna.dart';
import 'package:t4_movil/funciones/notas_internas/notas_api.dart';
import 'package:t4_movil/funciones/notas_internas/firmar_nota_page.dart';

Map<String, dynamic> nota({
  String id = 'nota-1',
  int version = 3,
  List<String> acciones = const ['dar_conformidad'],
  bool vinculada = false,
  String estado = 'pendiente_revision',
}) => {
  'id': id,
  'cite': 'CM/TI/001',
  'asunto': 'Solicitud de inspección $id',
  'cuerpo': 'Verificar el parque de la unidad.',
  'referencia': 'Parque central',
  'estado': estado,
  'version': version,
  'fecha_ultimo_movimiento': '2026-11-18T16:00:00Z',
  'unidad_origen': {'id': 1, 'nombre': 'Tecnología'},
  'unidad_actual': {'id': 1, 'nombre': 'Tecnología'},
  'destino_pendiente': {'id': 2, 'nombre': 'Jurídica'},
  'documento_id': vinculada ? 'doc-1' : null,
  'hoja_id': vinculada ? 'hoja-1' : null,
  'acciones_permitidas': acciones,
  'movimientos_nota': [
    {
      'id': 'evento-1',
      'accion': 'EMISION',
      'actor': {'nombre': 'Funcionario de prueba'},
      'fecha': '2026-11-18T16:00:00Z',
      'estado_resultante': 'pendiente_revision',
    },
  ],
};

http.Response respuesta(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response pagina(
  List<Map<String, dynamic>> notas, {
  int actual = 1,
  int ultima = 1,
}) => respuesta({
  'data': notas,
  'meta': {
    'current_page': actual,
    'last_page': ultima,
    'total': 2,
    'per_page': 15,
  },
});

ApiLaravel conectar(Future<http.Response> Function(http.Request) responder) {
  final api =
      ApiLaravel(baseUrl: 'http://api.test', client: MockClient(responder))
        ..token = 'sesion-1'
        ..cuentaId = '1';
  addTearDown(api.close);
  return api;
}

Future<void> abrir(WidgetTester tester, Widget pantalla) async {
  await tester.binding.setSurfaceSize(const Size(480, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: pantalla));
  await tester.pumpAndSettle();
}

Future<void> pulsar(WidgetTester tester, String texto) async {
  if (texto == 'Confirmar' &&
      find.byType(FirmarNotaPage).evaluate().isNotEmpty) {
    final area = find.byKey(const ValueKey('area-firma'));
    await tester.ensureVisible(area);
    await tester.pumpAndSettle();
    final inicio = tester.getTopLeft(area) + const Offset(30, 30);
    final gesto = await tester.startGesture(inicio);
    await gesto.moveBy(const Offset(65, 35));
    await gesto.moveBy(const Offset(35, -20));
    await gesto.up();
    await tester.pumpAndSettle();
    texto = 'Confirmar firma';
  }
  if (find.text(texto).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(texto),
      200,
      scrollable: find.byType(Scrollable).last,
    );
  }
  final boton = find.text(texto).last;
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('consulta las cinco bandejas con paginación del contrato', () async {
    final rutas = <Uri>[];
    final api = conectar((r) async {
      rutas.add(r.url);
      return pagina([nota()]);
    });
    for (final bandeja in BandejaNota.values) {
      final resultado = await NotasApi(api).bandeja(bandeja);
      expect(resultado.notas.single.origen, 'Tecnología');
    }
    expect(rutas.map((r) => r.queryParameters['bandeja']), [
      'por_firmar',
      'por_revisar',
      'por_recibir',
      'por_atender',
      'copias',
    ]);
    expect(rutas.every((r) => r.queryParameters['per_page'] == '15'), isTrue);
  });

  for (final fallo in [
    'pendiente',
    'sin conexión',
    'malformada',
    'identidad',
    'versión',
  ]) {
    test('reintento tras $fallo conserva la clave y los datos', () async {
      final peticiones = <http.Request>[];
      final api = conectar((r) async {
        peticiones.add(r);
        if (peticiones.length == 1) {
          if (fallo == 'pendiente') {
            return respuesta({'estado': 'pendiente'}, 202);
          }
          if (fallo == 'sin conexión') {
            throw http.ClientException('conexión perdida');
          }
          if (fallo == 'malformada') return respuesta({'id': 'nota-1'});
          return respuesta(
            nota(id: fallo == 'identidad' ? 'otra' : 'nota-1', version: 3),
          );
        }
        return respuesta(nota(version: 4, acciones: []));
      });
      final solicitud = SolicitudNota(
        nota: NotaInterna.desdeJson(nota()),
        accion: AccionNota.conformidad,
        token: api.token,
        cuentaId: api.cuentaId,
      );
      final servicio = NotasApi(api);
      await expectLater(
        servicio.ejecutar(solicitud),
        throwsA(isA<ErrorLaravel>()),
      );
      expect((await servicio.ejecutar(solicitud)).version, 4);
      expect(
        peticiones[0].headers['Idempotency-Key'],
        peticiones[1].headers['Idempotency-Key'],
      );
      expect(peticiones[0].body, peticiones[1].body);
      expect(jsonDecode(peticiones[0].body), {'version': 3});
    });
  }

  test(
    'primera recepción requiere ambos vínculos y no confunde los IDs',
    () async {
      var completa = false;
      final api = conectar(
        (r) async => respuesta(
          nota(
            version: 4,
            vinculada: completa,
            acciones: [],
            estado: 'recibida',
          ),
        ),
      );
      final solicitud = SolicitudNota(
        nota: NotaInterna.desdeJson(nota()),
        accion: AccionNota.primeraRecepcion,
        token: api.token,
        cuentaId: api.cuentaId,
      );
      await expectLater(
        NotasApi(api).ejecutar(solicitud),
        throwsA(isA<ErrorLaravel>()),
      );
      completa = true;
      final recibida = await NotasApi(api).ejecutar(solicitud);
      expect(recibida.documentoId, 'doc-1');
      expect(recibida.hojaId, 'hoja-1');
    },
  );

  test('un intento no puede enviarse con otra sesión', () async {
    var llamadas = 0;
    final api = conectar((r) async {
      llamadas++;
      return respuesta(nota(version: 4));
    });
    final solicitud = SolicitudNota(
      nota: NotaInterna.desdeJson(nota()),
      accion: AccionNota.conformidad,
      token: api.token,
      cuentaId: api.cuentaId,
    );
    api.token = 'otra-sesion';
    await expectLater(
      NotasApi(api).ejecutar(solicitud),
      throwsA(isA<ErrorLaravel>().having((e) => e.estado, 'estado', 401)),
    );
    expect(llamadas, 0);
  });

  testWidgets('volver a abrir una nota pendiente recupera el mismo intento', (
    tester,
  ) async {
    final claves = <String?>[];
    final api = conectar((r) async {
      if (r.method == 'POST') {
        claves.add(r.headers['Idempotency-Key']);
        if (claves.length == 1) return respuesta({}, 202);
        return respuesta(nota(version: 4, acciones: []));
      }
      return respuesta(
        nota(
          version: claves.length > 1 ? 4 : 3,
          acciones: claves.length > 1 ? [] : ['dar_conformidad'],
        ),
      );
    });
    await abrir(tester, DetalleNotaPage(api: api, id: 'nota-1'));
    await pulsar(tester, 'Firmar y dar conformidad');
    await pulsar(tester, 'Confirmar');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(
        home: DetalleNotaPage(api: api, id: 'nota-1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Firmar y dar conformidad'), findsNothing);
    await pulsar(tester, 'Comprobar mismo intento');
    expect(claves.length, 2);
    expect(claves[0], claves[1]);
    expect(find.text('Conformidad registrada.'), findsOneWidget);
  });

  testWidgets('cambiar de bandeja descarta una respuesta tardía', (
    tester,
  ) async {
    final tardia = Completer<http.Response>();
    final api = conectar(
      (r) async => r.url.queryParameters['bandeja'] == 'por_revisar'
          ? tardia.future
          : pagina([nota(id: 'copia', acciones: [])]),
    );
    await tester.pumpWidget(MaterialApp(home: BandejaNotasPage(api: api)));
    await tester.pump();
    await tester.tap(find.text('Copias'));
    await tester.pumpAndSettle();
    tardia.complete(pagina([nota(id: 'vieja')]));
    await tester.pumpAndSettle();
    expect(find.text('Solicitud de inspección copia'), findsOneWidget);
    expect(find.text('Solicitud de inspección vieja'), findsNothing);
    expect(find.text('Ver copia'), findsOneWidget);
  });

  testWidgets('al fallar la actualización repite página 1, no pagina 3', (
    tester,
  ) async {
    final paginas = <int>[];
    var fallar = false;
    final api = conectar((r) async {
      final p = int.parse(r.url.queryParameters['page']!);
      paginas.add(p);
      if (fallar) {
        fallar = false;
        return respuesta({}, 503);
      }
      return pagina([nota(id: 'nota-$p')], actual: p, ultima: 2);
    });
    await abrir(tester, BandejaNotasPage(api: api));
    await pulsar(tester, 'Cargar más notas');
    fallar = true;
    await tester.tap(find.byTooltip('Actualizar notas'));
    await tester.pumpAndSettle();
    await pulsar(tester, 'Reintentar');
    expect(paginas, [1, 2, 1, 1]);
    expect(find.text('Solicitud de inspección nota-2'), findsNothing);
  });

  testWidgets('paginación fallida repite la página y elimina duplicados', (
    tester,
  ) async {
    var intentos = 0;
    final paginas = <int>[];
    final api = conectar((r) async {
      final p = int.parse(r.url.queryParameters['page']!);
      paginas.add(p);
      if (p == 2 && intentos++ == 0) return respuesta({}, 503);
      return pagina(
        [nota(), if (p == 2) nota(id: 'otra')],
        actual: p,
        ultima: 2,
      );
    });
    await abrir(tester, BandejaNotasPage(api: api));
    await pulsar(tester, 'Cargar más notas');
    await pulsar(tester, 'Reintentar');
    expect(paginas, [1, 2, 2]);
    expect(find.text('Solicitud de inspección nota-1'), findsOneWidget);
    expect(find.text('Solicitud de inspección otra'), findsOneWidget);
  });

  testWidgets(
    'Copias sólo consulta aunque el detalle incluya permisos de otro rol',
    (tester) async {
      var posts = 0;
      final api = conectar((r) async {
        if (r.method == 'POST') posts++;
        return respuesta(
          nota(acciones: ['dar_conformidad', 'confirmar_primera_recepcion']),
        );
      });
      await abrir(
        tester,
        DetalleNotaPage(api: api, id: 'nota-1', soloLectura: true),
      );
      expect(find.text('Copia para conocimiento.'), findsOneWidget);
      expect(find.text('Firmar y dar conformidad'), findsNothing);
      expect(find.text('Confirmar recepción'), findsNothing);
      expect(posts, 0);
    },
  );

  for (final status in [403, 404]) {
    testWidgets('CC conserva la nota autorizada si la hoja devuelve $status', (
      tester,
    ) async {
      var posts = 0;
      final api = conectar((r) async {
        if (r.method == 'POST') posts++;
        if (r.url.path.endsWith('/hojas/hoja-1')) {
          return respuesta({'message': 'Recurso no autorizado'}, status);
        }
        return respuesta(
          nota(vinculada: true, acciones: [], estado: 'cerrada'),
        );
      });
      await abrir(
        tester,
        DetalleNotaPage(api: api, id: 'nota-1', soloLectura: true),
      );
      expect(find.text('CM/TI/001'), findsOneWidget);
      expect(find.text('Copia para conocimiento.'), findsOneWidget);
      expect(
        find.textContaining('Tu cuenta puede consultar la nota'),
        findsOneWidget,
      );
      expect(find.text('Firmar y dar conformidad'), findsNothing);
      expect(find.text('Confirmar recepción'), findsNothing);
      expect(find.text('Registrar atención'), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Ver expediente y adjuntos'),
            )
            .onPressed,
        isNull,
      );
      expect(posts, 0);
    });
  }

  testWidgets('401 de la hoja sí limpia la nota porque la sesión caducó', (
    tester,
  ) async {
    final api = conectar((r) async {
      if (r.url.path.endsWith('/hojas/hoja-1')) {
        return respuesta({'message': 'Unauthenticated.'}, 401);
      }
      return respuesta(nota(vinculada: true, acciones: []));
    });
    await abrir(
      tester,
      DetalleNotaPage(api: api, id: 'nota-1', soloLectura: true),
    );
    expect(find.text('CM/TI/001'), findsNothing);
    expect(find.text('Copia para conocimiento.'), findsNothing);
  });

  testWidgets('202 no muestra éxito y reintenta con la misma clave', (
    tester,
  ) async {
    final posts = <http.Request>[];
    var confirmada = false;
    final api = conectar((r) async {
      if (r.method == 'POST') {
        posts.add(r);
        if (posts.length == 1) return respuesta({'estado': 'pendiente'}, 202);
        confirmada = true;
      }
      return respuesta(
        nota(
          version: confirmada ? 4 : 3,
          acciones: confirmada ? [] : ['dar_conformidad'],
        ),
      );
    });
    await abrir(tester, DetalleNotaPage(api: api, id: 'nota-1'));
    await pulsar(tester, 'Firmar y dar conformidad');
    await pulsar(tester, 'Confirmar');
    expect(find.byKey(const ValueKey('nota-confirmada')), findsNothing);
    expect(find.text('Firmar y dar conformidad'), findsNothing);
    await pulsar(tester, 'Comprobar mismo intento');
    expect(find.text('Conformidad registrada.'), findsOneWidget);
    expect(posts.length, 2);
    expect(
      posts[0].headers['Idempotency-Key'],
      posts[1].headers['Idempotency-Key'],
    );
    expect(find.text('Firmar y dar conformidad'), findsNothing);
  });

  testWidgets('Copias mantiene consulta al abrir el expediente vinculado', (
    tester,
  ) async {
    final documento = {
      'id': 'doc-1',
      'asunto': 'Expediente vinculado',
      'estado': 'RECIBIDA',
      'hoja': {'id': 'hoja-1', 'version': 8},
      'acciones_permitidas': ['atender', 'derivar'],
    };
    final api = conectar((r) async {
      if (r.url.path.endsWith('/historial')) return respuesta({'data': []});
      if (r.url.path.endsWith('/adjuntos')) {
        return respuesta({'data': [], 'current_page': 1, 'last_page': 1});
      }
      if (r.url.path.endsWith('/hoja-1') || r.url.path.endsWith('/doc-1')) {
        return respuesta(documento);
      }
      return respuesta(nota(vinculada: true, acciones: ['registrar_atencion']));
    });
    await abrir(
      tester,
      DetalleNotaPage(api: api, id: 'nota-1', soloLectura: true),
    );
    await pulsar(tester, 'Ver expediente y adjuntos');
    expect(find.text('Expediente vinculado'), findsOneWidget);
    expect(find.text('Registrar atención'), findsNothing);
    expect(find.text('Derivar hoja'), findsNothing);
    expect(find.text('Adjuntar foto'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cambiar de cuenta durante la confirmación impide el envío', (
    tester,
  ) async {
    var posts = 0;
    final api = conectar((r) async {
      if (r.method == 'POST') posts++;
      return respuesta(nota());
    });
    await abrir(tester, DetalleNotaPage(api: api, id: 'nota-1'));
    await pulsar(tester, 'Firmar y dar conformidad');
    api.token = 'cuenta-distinta';
    await pulsar(tester, 'Confirmar');
    expect(posts, 0);
    expect(find.text('Solicitud de inspección nota-1'), findsNothing);
    expect(find.textContaining('Tu sesión cambió.'), findsOneWidget);
  });

  testWidgets('409 obliga a cargar la versión antes de un nuevo intento', (
    tester,
  ) async {
    final versiones = <int>[];
    final claves = <String?>[];
    var actual = 3;
    final api = conectar((r) async {
      if (r.method == 'POST') {
        versiones.add(jsonDecode(r.body)['version'] as int);
        claves.add(r.headers['Idempotency-Key']);
        actual++;
        if (versiones.length == 1) return respuesta({}, 409);
      }
      return respuesta(
        nota(
          version: actual,
          acciones: versiones.length == 2 ? [] : ['dar_conformidad'],
        ),
      );
    });
    await abrir(tester, DetalleNotaPage(api: api, id: 'nota-1'));
    await pulsar(tester, 'Firmar y dar conformidad');
    await pulsar(tester, 'Confirmar');
    expect(find.textContaining('La nota cambió.'), findsOneWidget);
    expect(find.text('Versión 4'), findsOneWidget);
    await pulsar(tester, 'Firmar y dar conformidad');
    await pulsar(tester, 'Confirmar');
    expect(versiones, [3, 4]);
    expect(claves[0], isNot(claves[1]));
  });

  for (final status in [401, 403, 404]) {
    testWidgets('$status al actualizar limpia la nota y su historial', (
      tester,
    ) async {
      var denegar = false, vencimientos = 0;
      final api = conectar(
        (r) async => denegar ? respuesta({}, status) : respuesta(nota()),
      );
      api.alVencerSesion = () async {
        vencimientos++;
      };
      await abrir(tester, DetalleNotaPage(api: api, id: 'nota-1'));
      expect(find.textContaining('Funcionario de prueba'), findsOneWidget);
      denegar = true;
      await tester.tap(find.byTooltip('Actualizar nota'));
      await tester.pumpAndSettle();
      expect(find.text('Solicitud de inspección nota-1'), findsNothing);
      expect(find.textContaining('Funcionario de prueba'), findsNothing);
      expect(find.text('Firmar y dar conformidad'), findsNothing);
      expect(vencimientos, status == 401 ? 1 : 0);
    });
  }

  testWidgets('doble toque abre una sola confirmación y envía una vez', (
    tester,
  ) async {
    var posts = 0;
    final api = conectar((r) async {
      if (r.method == 'POST') posts++;
      return respuesta(
        nota(
          version: posts == 0 ? 3 : 4,
          acciones: posts == 0 ? ['dar_conformidad'] : [],
        ),
      );
    });
    await abrir(tester, DetalleNotaPage(api: api, id: 'nota-1'));
    await tester.tap(find.text('Firmar y dar conformidad'));
    await tester.tap(
      find.text('Firmar y dar conformidad'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.byType(FirmarNotaPage), findsOneWidget);
    await pulsar(tester, 'Confirmar');
    expect(posts, 1);
  });

  for (final demorar in [false, true]) {
    testWidgets(
      'recepción y atención usan versión de hoja; red con demora: $demorar',
      (tester) async {
        var recibida = false, atendida = false;
        final rutas = <String>[];
        final api = conectar((r) async {
          if (demorar) {
            await Future<void>.delayed(const Duration(milliseconds: 80));
          }
          rutas.add('${r.method} ${r.url.path}');
          if (r.url.path.endsWith('/notas-internas/nota-1/recepciones')) {
            expect(jsonDecode(r.body)['version'], 3);
            recibida = true;
          }
          if (r.url.path.endsWith('/hojas/hoja-1/atenciones')) {
            expect(jsonDecode(r.body)['version'], 8);
            atendida = true;
            return respuesta({
              'documento_id': 'doc-1',
              'hoja': {
                'id': 'hoja-1',
                'version': 9,
                'estado': 'EN_ATENCION',
                'responsable_id': 2,
                'unidad_vigente_id': 2,
                'destino_pendiente_id': null,
              },
              'movimiento': {'id': 'atencion-1', 'accion': 'ATENCION'},
            });
          }
          if (r.url.path.endsWith('/hojas/hoja-1')) {
            return respuesta({
              'id': 'doc-1',
              'hoja': {'id': 'hoja-1', 'version': atendida ? 9 : 8},
              'acciones_permitidas': atendida
                  ? (demorar ? ['atender'] : [])
                  : ['atender', 'derivar'],
            });
          }
          return respuesta(
            nota(
              version: recibida ? 4 : 3,
              vinculada: recibida,
              acciones: atendida
                  ? (demorar ? ['registrar_atencion'] : [])
                  : recibida
                  ? ['registrar_atencion']
                  : ['confirmar_primera_recepcion'],
              estado: atendida
                  ? 'en_atencion'
                  : recibida
                  ? 'recibida'
                  : 'pendiente_recepcion',
            ),
          );
        });
        await abrir(tester, DetalleNotaPage(api: api, id: 'nota-1'));
        if (demorar) {
          await tester.binding.setSurfaceSize(const Size(393, 740));
          await tester.pumpAndSettle();
        }
        await pulsar(tester, 'Confirmar recepción');
        await pulsar(tester, 'Confirmar');
        expect(find.text('Recepción confirmada.'), findsOneWidget);
        expect(find.text('Derivar hoja'), findsNothing);
        await pulsar(tester, 'Registrar atención');
        await tester.enterText(
          find.byType(TextFormField),
          'Se verificó el parque.',
        );
        if (demorar) {
          final guardar = find.text('Guardar atención');
          await tester.ensureVisible(guardar);
          await tester.tap(guardar);
          // Renderiza el indicador mientras el POST sigue en vuelo, como
          // sucede en el teléfono; un HTTP inmediato ocultaba la regresión.
          await tester.pump();
          await tester.pumpAndSettle(
            const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate,
            const Duration(seconds: 5),
          );
        } else {
          await pulsar(tester, 'Guardar atención');
        }
        expect(atendida, isTrue);
        if (demorar) {
          await tester.scrollUntilVisible(
            find.text('En atención'),
            -250,
            scrollable: find.byType(Scrollable).last,
          );
        }
        expect(find.text('En atención'), findsOneWidget);
        expect(
          rutas.where((r) => r == 'POST /api/hojas/hoja-1/atenciones').length,
          1,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == 'Actualizar nota',
                ),
              )
              .onPressed,
          isNotNull,
        );
      },
    );
  }

  testWidgets('lista y detalle se adaptan a teléfono angosto y texto grande', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = conectar(
      (r) async =>
          r.url.path.endsWith('/nota-1') ? respuesta(nota()) : pagina([nota()]),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: BandejaNotasPage(api: api),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await pulsar(tester, 'Solicitud de inspección nota-1');
    expect(tester.takeException(), isNull);
    await pulsar(tester, 'Firmar y dar conformidad');
    expect(tester.takeException(), isNull);
  });
}
