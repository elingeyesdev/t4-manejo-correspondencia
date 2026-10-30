import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:t4_movil/main.dart';
import 'package:t4_movil/services/laravel_api.dart';
import 'package:t4_movil/services/sesion_controller.dart';

class _Almacen implements AlmacenSesion {
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

const _documento = {
  'id': 'e552ed39-1c35-46fe-a656-0dc3364b1b68',
  'guia': 'COR-2026-014',
  'codigo': 'DOC-2026-014',
  'asunto': 'Solicitud de informe',
  'remitente': 'Dirección',
  'fecha': '2026-10-25',
  'estado': 'REGISTRADA',
  'hoja': {'codigo': 'HR-2026-014'},
  'movimientos': [],
};
Future<void> _iniciar(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(430, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final api = ApiLaravel(
    client: MockClient((r) async {
      final Object data = switch (r.url.path) {
        '/api/sesiones' => {
          'token': 'token-de-prueba',
          'user': {'id': 1, 'name': 'Recepción', 'role': 'recepcion'},
        },
        '/api/documentos' => {
          'data': [_documento],
          'last_page': 1,
        },
        '/api/configuracion-registro' => {
          'tipos': <Object>[],
          'prioridades': <Object>[],
          'unidades': <Object>[],
        },
        _ => _documento,
      };
      return http.Response(
        jsonEncode(data),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  final sesion = SesionController(api: api, almacen: _Almacen());
  addTearDown(api.close);
  addTearDown(sesion.dispose);
  await sesion.ingresar('recepcion@example.test', 'clave-de-prueba');
  await tester.pumpWidget(CorrespondenciaApp(sesion: sesion));
  await tester.pumpAndSettle();
}

Future<void> _atras(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Atrás vuelve a Inicio desde cada sección sin perder la guía', (
    tester,
  ) async {
    await _iniciar(tester);
    for (final seccion in [
      'Consultar envío',
      'Nueva correspondencia',
      'Mi bandeja',
    ]) {
      await tester.ensureVisible(find.text(seccion));
      await tester.tap(find.text(seccion));
      await tester.pumpAndSettle();
      if (seccion == 'Consultar envío') {
        await tester.enterText(find.byType(TextFormField), 'COR-CONSERVADA');
      }
      await _atras(tester);
      expect(find.text('Hola, Recepción'), findsOneWidget);
      expect(find.text('¿Salir de Correspondencia?'), findsNothing);
    }
    await tester.tap(find.text('Consultar envío'));
    await tester.pumpAndSettle();
    expect(find.text('COR-CONSERVADA'), findsOneWidget);
  });
  testWidgets('Atrás cierra el menú antes de volver a Inicio', (tester) async {
    await _iniciar(tester);
    await tester.tap(find.text('Consultar envío'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await _atras(tester);
    expect(
      find.text('Inicio'),
      findsOneWidget,
    ); // Barra inferior, menú ya cerrado.
    expect(
      find.text(
        'Ingrese el número de guía para conocer el estado y el último movimiento.',
      ),
      findsOneWidget,
    );
    await _atras(tester);
    expect(find.text('Hola, Recepción'), findsOneWidget);
  });
  testWidgets('Atrás desde detalle vuelve a bandeja y luego a Inicio', (
    tester,
  ) async {
    await _iniciar(tester);
    await tester.ensureVisible(find.text('Mi bandeja'));
    await tester.tap(find.text('Mi bandeja'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Solicitud de informe'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle de correspondencia'), findsOneWidget);
    await _atras(tester);
    expect(find.text('Bandeja de correspondencia'), findsOneWidget);
    await _atras(tester);
    expect(find.text('Hola, Recepción'), findsOneWidget);
  });
  testWidgets(
    'Inicio pide confirmación y solo salir explícitamente cierra Android',
    (tester) async {
      final llamadas = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          llamadas.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _iniciar(tester);
      await _atras(tester);
      expect(find.text('¿Salir de Correspondencia?'), findsOneWidget);
      expect(llamadas, isNot(contains('SystemNavigator.pop')));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Hola, Recepción'), findsOneWidget);
      await _atras(tester);
      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();
      expect(llamadas.where((m) => m == 'SystemNavigator.pop'), hasLength(1));
    },
  );
  testWidgets('Atrás recorre el diseño antes de regresar a la app principal', (
    tester,
  ) async {
    await _iniciar(tester);
    await tester.ensureVisible(find.text('Gestión documental'));
    await tester.tap(find.text('Gestión documental'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Abrir bandeja'));
    await tester.tap(find.text('Abrir bandeja'));
    await tester.pumpAndSettle();
    await _atras(tester);
    expect(find.text('Abrir bandeja'), findsOneWidget);
    await _atras(tester);
    expect(find.text('Hola, Recepción'), findsOneWidget);
    expect(find.text('¿Salir de Correspondencia?'), findsNothing);
  });
}
