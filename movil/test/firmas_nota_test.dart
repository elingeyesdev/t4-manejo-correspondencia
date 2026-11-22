import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/funciones/notas_internas/bandeja_notas_page.dart';
import 'package:t4_movil/funciones/notas_internas/detalle_nota_page.dart';
import 'package:t4_movil/funciones/notas_internas/firma_nota.dart';
import 'package:t4_movil/funciones/notas_internas/firmar_nota_page.dart';
import 'package:t4_movil/funciones/notas_internas/nota_interna.dart';
import 'package:t4_movil/funciones/notas_internas/notas_api.dart';

import 'notas_internas_test.dart' as fixture;

final _trazo = [
  [
    [100, 200],
    [300, 400],
    [700, 250],
  ],
];
Map<String, dynamic> _borrador({bool firmado = false, int version = 3}) => {
  ...fixture.nota(
    estado: 'borrador',
    version: version,
    acciones: [firmado ? 'emitir' : 'firmar_borrador'],
  ),
  'estado_firma': firmado ? 'firmada' : 'pendiente',
};
SolicitudNota _solicitud(ApiLaravel api, AccionNota accion) => SolicitudNota(
  nota: NotaInterna.desdeJson(
    accion == AccionNota.firmaRemitente ? _borrador() : fixture.nota(),
  ),
  accion: accion,
  token: api.token,
  cuentaId: api.cuentaId,
  firma: FirmaNota.desdeJson(_trazo),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'rechaza marcas vacías y conserva el trazo confirmado sin mutaciones',
    () {
      for (final invalida in [
        [],
        [
          [
            [1, 1],
            [1, 1],
          ],
        ],
        [
          [
            [1, 1],
            [1001, 300],
          ],
        ],
        [
          [
            [1.0, 1],
            [20, 30],
          ],
        ],
      ]) {
        expect(() => FirmaNota.desdeJson(invalida), throwsFormatException);
      }
      final fuente = [
        for (final t in _trazo)
          [
            for (final p in t) [...p],
          ],
      ];
      final firma = FirmaNota.desdeJson(fuente);
      fuente.first.first[0] = 999;
      expect(firma.toJson(), _trazo);
    },
  );
  for (final accion in [AccionNota.firmaRemitente, AccionNota.conformidad]) {
    for (final fallo in ['202', '503', 'respuesta perdida']) {
      test(
        '${accion.name}: reinicio tras $fallo y 429 conserva firma y versión',
        () async {
          final posts = <http.Request>[];
          final api = fixture.conectar((r) async {
            posts.add(r);
            final guardado = await const FlutterSecureStorage().readAll();
            expect(
              guardado.values
                  .map(jsonDecode)
                  .any(
                    (v) =>
                        v['clave'] == r.headers['Idempotency-Key'] &&
                        jsonEncode(v['firma']) == jsonEncode(_trazo),
                  ),
              isTrue,
            );
            if (posts.length == 1) {
              if (fallo == 'respuesta perdida') {
                throw http.ClientException('Sin respuesta');
              }
              return fixture.respuesta({}, int.parse(fallo));
            }
            if (posts.length == 2) return fixture.respuesta({}, 429);
            return fixture.respuesta(
              accion == AccionNota.firmaRemitente
                  ? _borrador(firmado: true)
                  : fixture.nota(version: 4, acciones: []),
            );
          });
          var servicio = NotasApi(api);
          final original = _solicitud(api, accion);
          await expectLater(
            servicio.ejecutar(original),
            throwsA(isA<ErrorLaravel>()),
          );
          servicio = NotasApi(api);
          final recuperada = (await servicio.pendientePara('nota-1'))!;
          expect(recuperada.firma!.toJson(), _trazo);
          await expectLater(
            servicio.ejecutar(recuperada),
            throwsA(isA<ErrorLaravel>()),
          );
          servicio = NotasApi(api);
          final reintento = (await servicio.pendientePara('nota-1'))!;
          expect((await servicio.ejecutar(reintento)).id, 'nota-1');
          expect(await servicio.pendientePara('nota-1'), isNull);
          expect(posts.map((r) => r.body).toSet().length, 1);
          expect(posts.map((r) => r.headers['Idempotency-Key']).toSet(), {
            original.clave,
          });
          expect(jsonDecode(posts.last.body), {'version': 3, 'firma': _trazo});
          expect(posts.last.url.path.endsWith('/${accion.ruta}'), isTrue);
        },
      );
    }
  }
  test(
    'firma aplicada se reconcilia con la misma versión sin reenviar',
    () async {
      var posts = 0;
      final api = fixture.conectar((_) async {
        posts++;
        throw http.ClientException('Respuesta perdida');
      });
      final servicio = NotasApi(api);
      final intento = _solicitud(api, AccionNota.firmaRemitente);
      await expectLater(
        servicio.ejecutar(intento),
        throwsA(isA<ErrorLaravel>()),
      );
      expect(
        await servicio.confirmarSiAplicado(
          NotaInterna.desdeJson(_borrador(firmado: true, version: 4)),
          intento,
        ),
        isFalse,
      );
      expect(
        await servicio.confirmarSiAplicado(
          NotaInterna.desdeJson(_borrador(firmado: true)),
          intento,
        ),
        isTrue,
      );
      expect(await servicio.pendientePara('nota-1'), isNull);
      expect(posts, 1);
    },
  );
  testWidgets(
    'editar en web tras perder la respuesta no bloquea la nueva firma',
    (tester) async {
      var posts = 0;
      final api = fixture.conectar((r) async {
        if (r.method == 'POST') {
          posts++;
          throw http.ClientException('Respuesta perdida');
        }
        return fixture.respuesta(_borrador(version: 4));
      });
      await expectLater(
        NotasApi(api).ejecutar(_solicitud(api, AccionNota.firmaRemitente)),
        throwsA(isA<ErrorLaravel>()),
      );
      await fixture.abrir(tester, DetalleNotaPage(api: api, id: 'nota-1'));
      expect(await NotasApi(api).pendientePara('nota-1'), isNull);
      expect(find.text('Firmar borrador'), findsOneWidget);
      expect(find.text('Comprobar mismo intento'), findsNothing);
      expect(
        posts,
        1,
        reason: 'La firma anterior nunca se envía para la nueva versión.',
      );
    },
  );
  test(
    'un reintento aplicado que devuelve una versión nueva exige revisión',
    () async {
      final api = fixture.conectar(
        (_) async => fixture.respuesta(_borrador(version: 4)),
      );
      await expectLater(
        NotasApi(api).ejecutar(_solicitud(api, AccionNota.firmaRemitente)),
        throwsA(
          isA<ErrorLaravel>().having(
            (e) => e.estado,
            'conflicto de versión',
            409,
          ),
        ),
      );
      expect(await NotasApi(api).pendientePara('nota-1'), isNull);
    },
  );
  test('otra cuenta u otro servidor no recuperan el trazo pendiente', () async {
    final api = fixture.conectar((_) async => fixture.respuesta({}, 202));
    await expectLater(
      NotasApi(api).ejecutar(_solicitud(api, AccionNota.firmaRemitente)),
      throwsA(isA<ErrorLaravel>()),
    );
    api.cuentaId = '2';
    expect(await NotasApi(api).pendientePara('nota-1'), isNull);
    final otro = ApiLaravel(baseUrl: 'https://otro.test')
      ..cuentaId = '1'
      ..token = 'sesion-1';
    addTearDown(otro.close);
    expect(await NotasApi(otro).pendientePara('nota-1'), isNull);
    api.cuentaId = '1';
    expect(
      (await NotasApi(api).pendientePara('nota-1'))!.firma!.toJson(),
      _trazo,
    );
  });
  testWidgets('Por firmar consulta al servidor y abre el borrador', (
    tester,
  ) async {
    final consultas = <String?>[];
    final api = fixture.conectar((r) async {
      if (r.url.path.endsWith('/nota-1')) return fixture.respuesta(_borrador());
      final bandeja = r.url.queryParameters['bandeja'];
      consultas.add(bandeja);
      return fixture.pagina(bandeja == 'por_firmar' ? [_borrador()] : []);
    });
    await fixture.abrir(tester, BandejaNotasPage(api: api));
    await fixture.pulsar(tester, 'Por firmar');
    expect(consultas, ['por_revisar', 'por_firmar']);
    await fixture.pulsar(tester, 'Solicitud de inspección nota-1');
    expect(find.text('Firmar borrador'), findsOneWidget);
    expect(find.text('Pendiente de firma del remitente'), findsOneWidget);
  });
  testWidgets(
    'captura impide firma vacía, permite limpiar y se adapta al teléfono',
    (tester) async {
      await fixture.abrir(
        tester,
        FirmarNotaPage(
          nota: NotaInterna.desdeJson(_borrador()),
          titulo: 'Firmar borrador',
        ),
      );
      FilledButton confirmar() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirmar firma'),
      );
      expect(find.text('Verificar el parque de la unidad.'), findsOneWidget);
      expect(confirmar().onPressed, isNull);
      final area = find.byKey(const ValueKey('area-firma'));
      await tester.ensureVisible(area);
      await tester.drag(area, const Offset(70, 35));
      await tester.pumpAndSettle();
      expect(confirmar().onPressed, isNotNull);
      await fixture.pulsar(tester, 'Limpiar firma');
      expect(confirmar().onPressed, isNull);
      await tester.binding.setSurfaceSize(const Size(320, 568));
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  for (final accion in [AccionNota.firmaRemitente, AccionNota.conformidad]) {
    testWidgets('${accion.name}: solo envía después de revisar y confirmar', (
      tester,
    ) async {
      var estado = accion == AccionNota.firmaRemitente
          ? _borrador()
          : fixture.nota();
      final posts = <http.Request>[];
      final api = fixture.conectar((r) async {
        if (r.method == 'POST') {
          posts.add(r);
          estado = accion == AccionNota.firmaRemitente
              ? _borrador(firmado: true)
              : fixture.nota(version: 4, acciones: []);
        }
        return fixture.respuesta(estado);
      });
      await fixture.abrir(tester, DetalleNotaPage(api: api, id: 'nota-1'));
      await fixture.pulsar(tester, accion.titulo);
      expect(find.byType(FirmarNotaPage), findsOneWidget);
      expect(posts, isEmpty);
      await fixture.pulsar(tester, 'Confirmar');
      expect(posts, hasLength(1));
      final payload = jsonDecode(posts.single.body);
      expect(payload['version'], 3);
      expect(() => FirmaNota.desdeJson(payload['firma']), returnsNormally);
      expect(find.text(accion.titulo), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
