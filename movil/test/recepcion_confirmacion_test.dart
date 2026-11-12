import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/funciones/mi_bandeja/detalle_laravel_page.dart';

void main() {
  testWidgets('recibir y atender confirman antes de elegir otra acción', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const id = 'documento-1';
    const hoja = '49b5aed8-6fc3-4bd3-9bac-cc6ead26a1a1';
    var recibida = false;
    var atendida = false;
    var atenciones = 0;
    http.Response json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
    final api = ApiLaravel(
      client: MockClient((r) async {
        if (r.method == 'POST') {
          if (r.url.path.endsWith('/atenciones')) {
            atenciones++;
            atendida = true;
            return json({
              'documento_id': id,
              'hoja': {
                'id': hoja,
                'version': 4,
                'estado': 'EN_ATENCION',
                'responsable_id': 2,
                'unidad_vigente_id': 2,
              },
              'movimiento': {'id': 'atencion-1', 'accion': 'ATENCION'},
            }, 201);
          }
          expect(r.url.path.endsWith('/recepciones'), isTrue);
          recibida = true;
          return json({
            'documento_id': id,
            'hoja': {
              'id': hoja,
              'version': 3,
              'estado': 'RECIBIDA',
              'responsable_id': 2,
              'unidad_vigente_id': 2,
            },
            'movimiento': {'id': 'recepcion-1', 'accion': 'RECEPCION'},
          }, 201);
        }
        if (r.url.path.endsWith('/adjuntos')) {
          return json({'data': [], 'current_page': 1, 'last_page': 1});
        }
        if (r.url.path.endsWith('/historial')) {
          return json({
            'data': recibida
                ? [
                    {
                      'accion': 'RECEPCION',
                      'actor': {'nombre': 'Funcionario Jurídica'},
                    },
                  ]
                : [],
          });
        }
        return json({
          'id': id,
          'codigo': 'DOC-001',
          'asunto': 'Solicitud',
          'estado': atendida
              ? 'EN_ATENCION'
              : recibida
              ? 'RECIBIDA'
              : 'PENDIENTE_RECEPCION',
          'hoja': {
            'id': hoja,
            'version': atendida
                ? 4
                : recibida
                ? 3
                : 2,
            'responsable': {
              'nombre': recibida ? 'Funcionario Jurídica' : 'Recepción',
            },
          },
          'acciones_permitidas': recibida
              ? ['derivar', 'atender']
              : ['recibir'],
        });
      }),
    )..token = 'sesion-de-prueba';
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: DetalleLaravelPage(api: api, id: id),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PENDIENTE RECEPCION'), findsOneWidget);
    await tester.tap(find.text('Confirmar recepción'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar recepción').last);
    await tester.pumpAndSettle();
    expect(recibida, isFalse);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Confirmar recepción'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DetalleLaravelPage), findsOneWidget);
    expect(find.text('RECIBIDA'), findsOneWidget);
    expect(find.text('PENDIENTE RECEPCION'), findsNothing);
    expect(find.text('Derivar hoja'), findsNothing);
    expect(find.text('Registrar atención'), findsNothing);
    expect(find.text('Realizar otra acción'), findsOneWidget);
    expect(find.text('Confirmar recepción'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(
          'Recepción confirmada. Ya eres responsable de la hoja.',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Realizar otra acción'));
    await tester.pumpAndSettle();
    expect(find.text('Derivar hoja'), findsOneWidget);
    expect(find.text('Registrar atención'), findsOneWidget);
    expect(atenciones, 0);
    await tester.tap(find.text('Registrar atención'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'Documentación revisada',
    );
    await tester.tap(find.text('Guardar atención'));
    await tester.pumpAndSettle();
    expect(atenciones, 1);
    expect(find.text('EN ATENCION'), findsOneWidget);
    expect(find.text('Derivar hoja'), findsNothing);
    expect(find.text('Agregar otra atención'), findsNothing);
    expect(find.text('Guardar atención'), findsNothing);
    expect(find.text('Realizar otra acción'), findsOneWidget);
    await tester.tap(find.text('Realizar otra acción'));
    await tester.pumpAndSettle();
    expect(find.text('Agregar otra atención'), findsOneWidget);
    expect(atenciones, 1);
    expect(tester.takeException(), isNull);
  });
}
