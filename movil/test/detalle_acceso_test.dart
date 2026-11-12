import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/funciones/adjuntos/adjuntos_documento.dart';
import 'package:t4_movil/funciones/mi_bandeja/detalle_laravel_page.dart';
import 'package:t4_movil/funciones/recorrido/recorrido_documento.dart';

void main() {
  for (final estado in [403, 404]) {
    for (final recurso in ['documento', 'historial']) {
      testWidgets('limpia el detalle abierto si $recurso devuelve $estado', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1100, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var denegado = false;
        var consultas = 0;
        var consultasHistorial = 0;
        http.Response json(Object body, [int status = 200]) => http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
        );
        final api = ApiLaravel(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/adjuntos')) {
              return json({'data': [], 'current_page': 1, 'last_page': 1});
            }
            if (request.url.path.endsWith('/historial')) {
              consultasHistorial++;
              if (denegado && recurso == 'historial') {
                return json({'message': 'Acceso retirado'}, estado);
              }
              return json({
                'data': [
                  {
                    'accion': 'ATENCION',
                    'motivo': 'Observación reservada',
                    'actor': {'nombre': 'Responsable reservado'},
                  },
                ],
              });
            }
            consultas++;
            if (denegado && recurso == 'documento') {
              return json({'message': 'Acceso retirado'}, estado);
            }
            return json({
              'id': 'documento-1',
              'codigo': 'DOC-RESERVADO',
              'asunto': 'Asunto reservado',
              'estado': 'EN_ATENCION',
              'hoja': {
                'id': '49b5aed8-6fc3-4bd3-9bac-cc6ead26a1a1',
                'version': 3,
                'responsable': {'nombre': 'Responsable reservado'},
              },
              'acciones_permitidas': ['atender'],
            });
          }),
        )..token = 'sesion-de-prueba';
        addTearDown(api.close);
        await tester.pumpWidget(
          MaterialApp(
            home: DetalleLaravelPage(api: api, id: 'documento-1'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Asunto reservado'), findsOneWidget);
        expect(find.text('DOC-RESERVADO'), findsOneWidget);
        expect(find.text('Observación reservada'), findsOneWidget);
        expect(find.byType(RecorridoDocumento), findsOneWidget);
        expect(find.byType(AdjuntosDocumento), findsOneWidget);

        denegado = true;
        await tester.tap(find.byTooltip('Actualizar documento'));
        await tester.pumpAndSettle();
        expect(consultas, 2);
        expect(consultasHistorial, recurso == 'historial' ? 2 : 1);
        expect(find.text('Asunto reservado'), findsNothing);
        expect(find.text('DOC-RESERVADO'), findsNothing);
        expect(find.text('Responsable reservado'), findsNothing);
        expect(find.text('Observación reservada'), findsNothing);
        expect(find.byType(RecorridoDocumento), findsNothing);
        expect(find.byType(AdjuntosDocumento), findsNothing);
        expect(find.text('Reintentar'), findsOneWidget);
        expect(
          find.text(
            estado == 403
                ? 'No tienes permiso para realizar esta operación o tu cuenta fue deshabilitada.'
                : 'El documento no está disponible.',
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(find.text('Asunto reservado'), findsNothing);
        expect(find.byType(AdjuntosDocumento), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
