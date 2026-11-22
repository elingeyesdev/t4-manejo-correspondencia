import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/compartido/diseno/institucional.dart';
import 'package:t4_movil/funciones/notas_internas/bandeja_notas_page.dart';
import 'package:t4_movil/funciones/notas_internas/detalle_nota_page.dart';
import 'package:t4_movil/funciones/notas_internas/firmar_nota_page.dart';

Map<String, dynamic> _nota(int index) => {
  'id': 'nota-$index',
  'cite': 'NI-TEC-2026-01$index',
  'asunto': [
    'Solicitud de materiales',
    'Revisión de inventario',
    'Solicitud de información',
  ][index],
  'cuerpo': 'Solicitamos la revisión de los materiales necesarios para el trabajo de la unidad.',
  'estado': 'pendiente_revision',
  'version': 3,
  'unidad_origen': {'id': 1, 'nombre': 'Departamento de Tecnología'},
  'unidad_destinataria': {'id': 2, 'nombre': 'Asesoría Jurídica'},
  'autor': {'id': 1, 'nombre': 'Funcionario de demostración'},
  'unidad_actual': {'id': 1, 'nombre': 'Jefatura de unidad'},
  'destino_pendiente': null,
  'documento_id': null,
  'hoja_id': null,
  'fecha_ultimo_movimiento': '2026-11-18T16:00:00Z',
  'acciones_permitidas': ['dar_conformidad'],
  'movimientos_nota': [
    {
      'id': 'evento-1',
      'accion': 'Nota emitida',
      'actor': {'nombre': 'Funcionario de demostración'},
      'fecha': '2026-11-18T16:00:00Z',
      'estado_resultante': 'pendiente_revision',
    },
  ],
};

Future<void> _capturar(WidgetTester tester, String nombre) async {
  if (!const bool.fromEnvironment('CAPTURAR_INSTITUCIONAL')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('captura-institucional')),
    );
    final imagen = await boundary.toImage(pixelRatio: 2);
    final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
    final archivo = File('build/revision/institucional/$nombre.png');
    await archivo.parent.create(recursive: true);
    await archivo.writeAsBytes(bytes!.buffer.asUint8List());
    imagen.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURAR_INSTITUCIONAL')) return;
    final sdk =
        Platform.environment['FLUTTER_ROOT'] ?? r'C:\src\flutter\flutter';
    final roboto = FontLoader('Roboto');
    for (final peso in ['regular', 'medium', 'bold']) {
      roboto.addFont(
        Future.value(
          ByteData.sublistView(
            await File(
              '$sdk/bin/cache/artifacts/material_fonts/roboto-$peso.ttf',
            ).readAsBytes(),
          ),
        ),
      );
    }
    await roboto.load();
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(
            ByteData.sublistView(
              await File(
                '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
              ).readAsBytes(),
            ),
          ),
        ))
        .load();
  });

  test(
    'cabecera blanca y acciones institucionales mantienen contraste legible',
    () {
      double contraste(Color a, Color b) {
        final valores = [a.computeLuminance(), b.computeLuminance()]..sort();
        return (valores.last + .05) / (valores.first + .05);
      }

      expect(
        contraste(Colors.white, Institucional.tinta),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contraste(Institucional.accion, Colors.white),
        greaterThanOrEqualTo(4.5),
      );
    },
  );

  testWidgets('comparacion visual del mismo expediente real ficticio', (
    tester,
  ) async {
    final reference = jsonDecode(
      File(const String.fromEnvironment('REFERENCIA_API_NOTAS'))
          .readAsStringSync(),
    ) as Map;
    final detail = reference['detalle'] as Map;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api =
        ApiLaravel(
            baseUrl: 'http://captura.test',
            client: MockClient(
              (r) async => http.Response(
                jsonEncode(
                  r.url.path.endsWith('/${reference['id']}')
                      ? detail
                      : reference['bandeja'],
                ),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              ),
            ),
          )
          ..token = 'captura-sin-credenciales'
          ..cuentaId = '1';
    addTearDown(api.close);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('captura-institucional'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: BandejaNotasPage(api: api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('buscar-notas')),
      reference['cite'] as String,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text(reference['cite'] as String),
      ),
      findsOneWidget,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _capturar(tester, 'bandeja_misma_nota');
    final row = find.byKey(ValueKey(reference['id'] as String));
    if (row.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
    }
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('Firmar y dar conformidad'), findsOneWidget);
    expect(find.text(reference['cite'] as String), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capturar(tester, 'detalle_misma_nota');
  }, skip: const String.fromEnvironment('REFERENCIA_API_NOTAS').isEmpty);

  testWidgets(
    'bandeja y detalle institucional conservan datos, búsqueda y acciones',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api =
          ApiLaravel(
              baseUrl: 'http://api.test',
              client: MockClient((r) async {
                final Object datos = r.url.path.endsWith('/nota-0')
                    ? _nota(0)
                    : {
                        'data': [for (var i = 0; i < 3; i++) _nota(i)],
                        'meta': {
                          'current_page': 1,
                          'last_page': 1,
                          'total': 3,
                          'per_page': 15,
                        },
                      };
                return http.Response(
                  jsonEncode(datos),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                );
              }),
            )
            ..token = 'sesion-ficticia'
            ..cuentaId = '1';
      addTearDown(api.close);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('captura-institucional'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: BandejaNotasPage(api: api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(AppBar)))
            .appBarTheme
            .backgroundColor,
        Colors.white,
      );
      expect(tester.takeException(), isNull);
      await _capturar(tester, 'bandeja_notas');
      await tester.enterText(
        find.byKey(const ValueKey('buscar-notas')),
        'NI-TEC-2026-010',
      );
      await tester.pumpAndSettle();
      expect(find.text('Solicitud de materiales'), findsOneWidget);
      expect(find.text('Revisión de inventario'), findsNothing);
      await tester.tap(find.text('Solicitud de materiales'));
      await tester.pumpAndSettle();
      expect(find.text('Firmar y dar conformidad'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capturar(tester, 'detalle_nota');
      await tester.binding.setSurfaceSize(const Size(320, 568));
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Firmar y dar conformidad').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('Firmar y dar conformidad'));
      await tester.pumpAndSettle();
      expect(find.byType(FirmarNotaPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byType(DetalleNotaPage, skipOffstage: false), findsOneWidget);
    },
  );
}
