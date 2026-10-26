import 'dart:async';
import 'dart:convert';

import 'package:t4_movil/main.dart';
import 'package:t4_movil/pages/registro_correspondencia_page.dart';
import 'package:t4_movil/services/correspondencia_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<void> preparar(WidgetTester tester, CorrespondenciaApi api) async {
  await tester.binding.setSurfaceSize(const Size(430, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(api.close);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: RegistroCorrespondenciaPage(api: api)),
    ),
  );
}

Future<void> completar(WidgetTester tester) async {
  final campos = find.byType(TextFormField);
  await tester.enterText(campos.at(0), 'Junta Vecinal Los Pinos');
  await tester.enterText(campos.at(1), 'Solicitud de alumbrado público');
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Carta').last);
  await tester.pumpAndSettle();
  await tester.tap(campos.at(2));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Aceptar').last);
  await tester.pumpAndSettle();
}

CorrespondenciaApi apiConfigurada({required http.Client client}) =>
    CorrespondenciaApi(
      client: client,
      endpoint: Uri.parse('https://registro.example.test/api/correspondencias'),
    );

void main() {
  testWidgets(
    'formulario válido sin conexión configurada conserva datos y no simula guardado',
    (tester) async {
      var llamadas = 0;
      await preparar(
        tester,
        CorrespondenciaApi(
          client: MockClient((_) async {
            llamadas++;
            return http.Response('{}', 201);
          }),
        ),
      );
      await completar(tester);
      await tester.ensureVisible(find.text('Validar formulario'));
      await tester.tap(find.text('Validar formulario'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Los campos son válidos.'), findsOneWidget);
      expect(
        find.text('Correspondencia registrada correctamente'),
        findsNothing,
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Junta Vecinal Los Pinos',
      );
      expect(llamadas, 0);
    },
  );
  testWidgets(
    'Inicio abre el formulario y el menú solo tiene destinos reales',
    (tester) async {
      await tester.pumpWidget(
        CorrespondenciaApp(apiRegistro: CorrespondenciaApi()),
      );
      expect(
        find.text('Consulte el estado de su envío con el número de guía.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Nueva correspondencia').first);
      await tester.pumpAndSettle();
      expect(find.text('Validar formulario'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Correspondencias'), findsNothing);
    },
  );
  testWidgets('campos vacíos y asunto largo no envían solicitudes', (
    tester,
  ) async {
    var llamadas = 0;
    await preparar(
      tester,
      apiConfigurada(
        client: MockClient((_) async {
          llamadas++;
          return http.Response('{}', 500);
        }),
      ),
    );
    await tester.tap(find.text('Guardar correspondencia'));
    await tester.pumpAndSettle();
    for (final mensaje in [
      'Ingrese el remitente.',
      'Ingrese el asunto.',
      'Seleccione un tipo de documento.',
      'Seleccione la fecha de recepción.',
    ]) {
      expect(find.text(mensaje), findsOneWidget);
    }
    await tester.enterText(find.byType(TextFormField).at(1), 'a' * 151);
    await tester.pumpAndSettle();
    expect(
      find.text('El asunto no puede superar los 150 caracteres.'),
      findsOneWidget,
    );
    expect(llamadas, 0);
  });
  testWidgets(
    'bloquea doble envío, muestra correlativo real y limpia el formulario',
    (tester) async {
      final respuesta = Completer<http.Response>();
      var llamadas = 0;
      await preparar(
        tester,
        apiConfigurada(
          client: MockClient((request) {
            llamadas++;
            return respuesta.future;
          }),
        ),
      );
      await completar(tester);
      await tester.tap(find.text('Guardar correspondencia'));
      await tester.pump();
      expect(find.text('Guardando...'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        find.text('Correspondencia registrada correctamente'),
        findsNothing,
      );
      respuesta.complete(
        http.Response(
          jsonEncode({
            'id': 7,
            'correlativo': 'CORR-0007',
            'mensaje': 'Guardado',
          }),
          201,
        ),
      );
      await tester.pumpAndSettle();
      expect(llamadas, 1);
      expect(find.text('CORR-0007'), findsOneWidget);
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      for (final campo in tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      )) {
        expect(campo.controller!.text, isEmpty);
      }
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .initialValue,
        isNull,
      );
      await tester.tap(find.text('Guardar correspondencia'));
      await tester.pumpAndSettle();
      expect(find.text('Seleccione un tipo de documento.'), findsOneWidget);
      expect(find.text('Seleccione la fecha de recepción.'), findsOneWidget);
      expect(llamadas, 1);
    },
  );
  testWidgets('muestra el error 400 junto al campo y conserva los datos', (
    tester,
  ) async {
    await preparar(
      tester,
      apiConfigurada(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'errores': [
                {
                  'campo': 'remitente',
                  'mensaje': 'Remitente rechazado por el servidor.',
                },
              ],
            }),
            400,
          ),
        ),
      ),
    );
    await completar(tester);
    await tester.tap(find.text('Guardar correspondencia'));
    await tester.pumpAndSettle();
    expect(find.text('Remitente rechazado por el servidor.'), findsOneWidget);
    expect(find.text('Correspondencia registrada correctamente'), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'Junta Vecinal Los Pinos',
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'Remitente corregido',
    );
    await tester.pumpAndSettle();
    expect(find.text('Remitente rechazado por el servidor.'), findsNothing);
  });
  testWidgets('servidor inaccesible conserva formulario y permite reintentar', (
    tester,
  ) async {
    await preparar(
      tester,
      apiConfigurada(
        client: MockClient(
          (_) async => throw http.ClientException('Connection refused'),
        ),
      ),
    );
    await completar(tester);
    await tester.tap(find.text('Guardar correspondencia'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No se pudo conectar con el servidor.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'Junta Vecinal Los Pinos',
    );
    expect(find.text('Correspondencia registrada correctamente'), findsNothing);
  });
}
