import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:t4_movil/main.dart';
import 'package:t4_movil/models/envio_consulta.dart';
import 'package:t4_movil/services/consulta_envio_service.dart';

class ServicioControlado implements ConsultaEnvioService {
  ServicioControlado(this.responder);
  final Future<EnvioConsulta?> Function(String) responder;
  int llamadas = 0;
  String? ultimaGuia;
  @override
  Future<EnvioConsulta?> consultar(String numeroGuia) {
    llamadas++;
    ultimaGuia = numeroGuia;
    return responder(numeroGuia);
  }
}

Future<void> preparar(
  WidgetTester tester,
  ConsultaEnvioService servicio,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(CorrespondenciaApp(servicio: servicio));
  await tester.tap(find.text('Consultar envío'));
  await tester.pumpAndSettle();
}

Future<void> consultar(WidgetTester tester, String guia) async {
  await tester.enterText(find.byType(TextFormField), guia);
  await tester.tap(find.text('Consultar'));
  await tester.pumpAndSettle();
}

void main() {
  final envio = EnvioConsulta(
    numeroGuia: 'PRUEBA-014',
    estado: 'Estado de prueba',
    fechaUltimoMovimiento: DateTime(2026, 10, 15, 9, 30),
  );

  testWidgets('número vacío o espacios no consulta el servicio', (
    tester,
  ) async {
    final servicio = ServicioControlado((_) async => null);
    await preparar(tester, servicio);
    await consultar(tester, '   ');
    expect(find.text('Ingrese el número de guía.'), findsOneWidget);
    expect(servicio.llamadas, 0);
  });

  testWidgets('consulta correcta muestra solamente los datos recibidos', (
    tester,
  ) async {
    final servicio = ServicioControlado((_) async => envio);
    await preparar(tester, servicio);
    await consultar(tester, ' PRUEBA-014 ');
    expect(servicio.ultimaGuia, 'PRUEBA-014');
    expect(find.text('PRUEBA-014'), findsOneWidget);
    expect(find.text('Estado de prueba'), findsOneWidget);
    expect(find.text('15/10/2026 09:30'), findsOneWidget);
    expect(find.text('Resultado de la consulta'), findsOneWidget);
    expect(find.text('Responsable'), findsNothing);
    expect(find.text('Remitente'), findsNothing);
    await tester.enterText(find.byType(TextFormField), 'OTRA-GUIA');
    await tester.pump();
    expect(find.text('Resultado de la consulta'), findsNothing);
  });

  testWidgets('guía inexistente muestra aviso y permite otra consulta', (
    tester,
  ) async {
    final servicio = ServicioControlado((_) async => null);
    await preparar(tester, servicio);
    await consultar(tester, 'NO-EXISTE');
    expect(
      find.text('No se encontró un envío con ese número de guía.'),
      findsOneWidget,
    );
    expect(find.text('Resultado de la consulta'), findsNothing);
    await consultar(tester, 'OTRA');
    expect(servicio.llamadas, 2);
  });

  testWidgets('fallo de conexión no borra la guía y permite reintentar', (
    tester,
  ) async {
    final servicio = ServicioControlado(
      (_) async => throw const ErrorConexion(),
    );
    await preparar(tester, servicio);
    await consultar(tester, 'PRUEBA-014');
    expect(
      find.textContaining('No se pudo conectar con el servidor.'),
      findsOneWidget,
    );
    expect(find.text('Resultado de la consulta'), findsNothing);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      'PRUEBA-014',
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('mientras consulta no permite un segundo envío ni editar', (
    tester,
  ) async {
    final respuesta = Completer<EnvioConsulta?>();
    final servicio = ServicioControlado((_) => respuesta.future);
    await preparar(tester, servicio);
    await tester.enterText(find.byType(TextFormField), 'PRUEBA-014');
    await tester.tap(find.text('Consultar'));
    await tester.pump();
    expect(find.text('Consultando...'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
      isFalse,
    );
    expect(servicio.llamadas, 1);
    respuesta.complete(envio);
    await tester.pumpAndSettle();
    expect(find.text('Estado de prueba'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('navegación Inicio y Consultar envío conserva la guía', (
    tester,
  ) async {
    await preparar(tester, ServicioControlado((_) async => null));
    await tester.enterText(find.byType(TextFormField), 'PRUEBA-014');
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(
      find.text('Consulte el estado de su envío con el número de guía.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Consultar envío'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      'PRUEBA-014',
    );
  });

  testWidgets(
    'una respuesta después de cerrar la pantalla no provoca errores',
    (tester) async {
      final respuesta = Completer<EnvioConsulta?>();
      await preparar(tester, ServicioControlado((_) => respuesta.future));
      await tester.enterText(find.byType(TextFormField), 'PRUEBA-014');
      await tester.tap(find.text('Consultar'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      respuesta.complete(envio);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
