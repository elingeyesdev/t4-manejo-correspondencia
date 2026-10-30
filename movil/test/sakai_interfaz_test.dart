import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:t4_movil/main.dart';
import 'package:t4_movil/services/laravel_api.dart';
import 'package:t4_movil/services/sesion_controller.dart';

class _Memoria implements AlmacenSesion {
  String? dato;
  @override
  Future<String?> leer() async => dato;
  @override
  Future<void> guardar(String valor) async {
    dato = valor;
  }

  @override
  Future<void> eliminar() async {
    dato = null;
  }
}

const _doc = {
  'id': 'visual-001',
  'codigo': 'DOC-2026-001',
  'guia': 'COR-2026-001',
  'asunto': 'Solicitud de información',
  'remitente': 'Secretaría General',
  'fecha': '2026-10-28',
  'estado': 'REGISTRADA',
  'tipo': {'name': 'Informe'},
  'prioridad': {'name': 'Normal'},
  'unidad': {'name': 'Recepción'},
  'hoja': {'codigo': 'HR-2026-001'},
  'movimientos': [
    {'action': 'REGISTRO', 'occurred_at': '2026-10-28T14:42:00Z'},
  ],
};
Future<void> _preparar(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final api = ApiLaravel(
    client: MockClient((request) async {
      final Object data = switch (request.url.path) {
        '/api/sesiones' => {
          'token': 'visual',
          'user': {
            'name': 'Russell',
            'role': 'recepcion',
            'email': 'visual@example.test',
          },
        },
        '/api/documentos' => {
          'data': [_doc],
          'last_page': 1,
        },
        '/api/configuracion-registro' => {
          'tipos': [
            {'id': 1, 'name': 'Carta'},
          ],
          'prioridades': [
            {'id': 1, 'name': 'Normal'},
          ],
          'unidades': [
            {'id': 1, 'name': 'Recepción'},
          ],
        },
        _ => _doc,
      };
      return http.Response(
        jsonEncode(data),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  final sesion = SesionController(api: api, almacen: _Memoria());
  addTearDown(api.close);
  addTearDown(sesion.dispose);
  await sesion.ingresar('visual@example.test', 'solo-datos-de-prueba');
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('captura'),
      child: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: CorrespondenciaApp(sesion: sesion),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _capturar(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURAR_SAKAI')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('captura')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/revision/sakai/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURAR_SAKAI')) return;
    final sdk =
        Platform.environment['FLUTTER_ROOT'] ?? r'C:\src\flutter\flutter';
    final font = File(
      '$sdk/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    );
    if (await font.exists()) {
      await (FontLoader('Roboto')..addFont(
            Future.value(ByteData.sublistView(await font.readAsBytes())),
          ))
          .load();
    }
    final material = File(
      '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    );
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(ByteData.sublistView(await material.readAsBytes())),
        ))
        .load();
    await (FontLoader(
      'PrimeIcons',
    )..addFont(rootBundle.load('assets/fonts/primeicons.ttf'))).load();
  });

  testWidgets('deslizar sincroniza pestañas y conserva guía y búsqueda', (
    tester,
  ) async {
    await _preparar(tester);
    final paginas = find.byKey(const ValueKey('secciones-deslizables'));
    await tester.drag(paginas, const Offset(-330, 0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    await tester.enterText(find.byType(TextField), 'Secretaría');
    await tester.drag(paginas, const Offset(-330, 0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    await tester.enterText(find.byType(TextFormField), 'COR-DESLIZAR');
    await tester.drag(paginas, const Offset(-330, 0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
    await tester.drag(paginas, const Offset(330, 0));
    await tester.pumpAndSettle();
    expect(find.text('COR-DESLIZAR'), findsOneWidget);
    await tester.drag(paginas, const Offset(330, 0));
    await tester.pumpAndSettle();
    expect(find.text('Secretaría'), findsOneWidget);
    await tester.drag(paginas, const Offset(330, 0));
    await tester.pumpAndSettle();
    expect(find.text('Hola, Russell'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Diseño de próximas pantallas'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Diseño de próximas pantallas'), findsNothing);
  });
  testWidgets('barra inferior conserva la consulta y Atrás retorna a Inicio', (
    tester,
  ) async {
    await _preparar(tester);
    await _capturar(tester, 'inicio');
    await tester.tap(find.text('Consulta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'COR-CONSERVADA');
    await tester.tap(find.text('Cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('visual@example.test'), findsOneWidget);
    await tester.tap(find.text('Consulta'));
    await tester.pumpAndSettle();
    expect(find.text('COR-CONSERVADA'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Hola, Russell'), findsOneWidget);
  });

  testWidgets(
    'búsqueda local no inventa resultados y conserva acceso al detalle',
    (tester) async {
      await _preparar(tester);
      await tester.tap(find.text('Bandeja'));
      await tester.pumpAndSettle();
      await _capturar(tester, 'bandeja');
      await tester.enterText(find.byType(TextField), 'No existe');
      await tester.pumpAndSettle();
      expect(
        find.text('Sin coincidencias en los documentos cargados.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Secretaría');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solicitud de información'));
      await tester.pumpAndSettle();
      expect(find.text('HR-2026-001'), findsOneWidget);
      expect(find.text('COR-2026-001'), findsOneWidget);
      await _capturar(tester, 'detalle');
      await tester.scrollUntilVisible(
        find.text('Volver a mi bandeja'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Volver a mi bandeja'));
      await tester.pumpAndSettle();
      expect(find.text('Solicitud de información'), findsOneWidget);
    },
  );

  testWidgets(
    'pantalla estrecha y letra ampliada mantienen acceso a registro',
    (tester) async {
      await _preparar(tester, size: const Size(320, 740), scale: 1.5);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Nueva correspondencia'));
      await tester.tap(find.text('Nueva correspondencia'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Registrar correspondencia'));
      expect(tester.takeException(), isNull);
    },
  );
}
