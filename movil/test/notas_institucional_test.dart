import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/compartido/diseno/institucional.dart';
import 'package:t4_movil/funciones/notas_internas/bandeja_notas_page.dart';
import 'package:t4_movil/funciones/notas_internas/detalle_nota_page.dart';

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
    'verde claro con texto negro y acciones mantienen contraste legible',
    () {
      double contraste(Color a, Color b) {
        final valores = [a.computeLuminance(), b.computeLuminance()]..sort();
        return (valores.last + .05) / (valores.first + .05);
      }

      expect(
        contraste(Institucional.cabecera, Institucional.tinta),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contraste(Institucional.accion, Colors.white),
        greaterThanOrEqualTo(4.5),
      );
    },
  );

  testWidgets(
    'bandeja y detalle institucional conservan datos, búsqueda y acciones',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = ApiLaravel(
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
      )..token = 'sesion-ficticia';
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
        Institucional.cabecera,
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
      expect(find.text('Dar conformidad'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capturar(tester, 'detalle_nota');
      await tester.binding.setSurfaceSize(const Size(320, 568));
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Dar conformidad').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Dar conformidad'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byType(DetalleNotaPage), findsOneWidget);
    },
  );
}
