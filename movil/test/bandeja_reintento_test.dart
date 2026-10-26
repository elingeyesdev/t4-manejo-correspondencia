import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:t4_movil/pages/bandeja_laravel_page.dart';
import 'package:t4_movil/services/laravel_api.dart';

Map<String, dynamic> _documento(String id, String asunto) => {
  'id': id,
  'asunto': asunto,
  'remitente': 'Dirección',
  'guia': 'COR-$id',
  'estado': 'REGISTRADA',
  'fecha': '2026-10-26',
};
http.Response _pagina(
  List<Map<String, dynamic>> documentos, {
  int ultima = 2,
}) => http.Response(
  jsonEncode({'data': documentos, 'last_page': ultima}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Future<void> _abrir(
  WidgetTester tester,
  http.Response Function(int pagina) responder,
) async {
  await tester.binding.setSurfaceSize(const Size(430, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final api = ApiLaravel(
    client: MockClient(
      (r) async => responder(int.parse(r.url.queryParameters['page']!)),
    ),
  )..token = 'token-de-prueba';
  addTearDown(api.close);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: BandejaLaravelPage(api: api)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pulsar(WidgetTester tester, String texto) async {
  await tester.ensureVisible(find.text(texto));
  await tester.tap(find.text(texto));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'reintentar una actualización fallida repite página 1 y reemplaza la lista',
    (tester) async {
      final peticiones = <int>[];
      await _abrir(tester, (pagina) {
        peticiones.add(pagina);
        if (peticiones.length == 1) {
          return _pagina([_documento('1', 'Documento antiguo')]);
        }
        if (peticiones.length == 2) throw http.ClientException('Sin conexión');
        return _pagina([
          _documento('nuevo', 'Documento actualizado'),
        ], ultima: 1);
      });
      await tester.tap(find.byTooltip('Actualizar bandeja'));
      await tester.pumpAndSettle();
      expect(find.text('Documento antiguo'), findsOneWidget);
      await _pulsar(tester, 'Reintentar');
      expect(peticiones, [1, 1, 1]);
      expect(find.text('Documento antiguo'), findsNothing);
      expect(find.text('Documento actualizado'), findsOneWidget);
      expect(find.text('Cargar más documentos'), findsNothing);
    },
  );
  testWidgets('actualizar tras varias páginas reinicia también al reintentar', (
    tester,
  ) async {
    final peticiones = <int>[];
    await _abrir(tester, (pagina) {
      peticiones.add(pagina);
      return switch (peticiones.length) {
        1 => _pagina([_documento('1', 'Primera anterior')]),
        2 => _pagina([_documento('2', 'Segunda anterior')]),
        3 => throw http.ClientException('Sin conexión'),
        4 => _pagina([_documento('3', 'Primera actualizada')]),
        _ => _pagina([_documento('4', 'Segunda actualizada')]),
      };
    });
    await _pulsar(tester, 'Cargar más documentos');
    await tester.tap(find.byTooltip('Actualizar bandeja'));
    await tester.pumpAndSettle();
    await _pulsar(tester, 'Reintentar');
    expect(peticiones, [1, 2, 1, 1]);
    expect(find.text('Primera anterior'), findsNothing);
    expect(find.text('Segunda anterior'), findsNothing);
    expect(find.text('Primera actualizada'), findsOneWidget);
    await _pulsar(tester, 'Cargar más documentos');
    expect(peticiones, [1, 2, 1, 1, 2]);
    expect(find.text('Segunda actualizada'), findsOneWidget);
  });
  testWidgets(
    'reintentar Cargar más repite la página fallida y conserva las anteriores',
    (tester) async {
      final peticiones = <int>[];
      await _abrir(tester, (pagina) {
        peticiones.add(pagina);
        if (peticiones.length == 1) {
          return _pagina([_documento('1', 'Primera página')]);
        }
        if (peticiones.length == 2) throw http.ClientException('Sin conexión');
        return _pagina([_documento('2', 'Segunda página')]);
      });
      await _pulsar(tester, 'Cargar más documentos');
      await _pulsar(tester, 'Reintentar');
      expect(peticiones, [1, 2, 2]);
      expect(find.text('Primera página'), findsOneWidget);
      expect(find.text('Segunda página'), findsOneWidget);
      expect(find.text('Cargar más documentos'), findsNothing);
    },
  );
  testWidgets('reintentar una carga inicial fallida pide página 1', (
    tester,
  ) async {
    final peticiones = <int>[];
    await _abrir(tester, (pagina) {
      peticiones.add(pagina);
      if (peticiones.length == 1) throw http.ClientException('Sin conexión');
      return _pagina([_documento('1', 'Documento disponible')], ultima: 1);
    });
    await _pulsar(tester, 'Reintentar');
    expect(peticiones, [1, 1]);
    expect(find.text('Documento disponible'), findsOneWidget);
  });
}
