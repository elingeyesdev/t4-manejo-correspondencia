import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/funciones/recorrido/recorrido_api.dart';
import 'package:t4_movil/funciones/recorrido/recorrido_documento.dart';

const hojaId = 'b1e2b746-45b7-4b21-bf78-28d80db3ed6a';
const docId = '60702041-a32c-4237-a67c-d251eeb1ed31';

http.Response respuesta(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> confirmado(OperacionRecorrido operacion, int version) => {
  'documento_id': docId,
  'hoja': {
    'id': hojaId,
    'version': version + 1,
    'estado': operacion == OperacionRecorrido.derivar
        ? 'PENDIENTE_RECEPCION'
        : operacion == OperacionRecorrido.recibir
        ? 'RECIBIDA'
        : 'EN_ATENCION',
    'responsable_id': 2,
    'unidad_vigente_id': 2,
    'destino_pendiente_id': null,
  },
  'movimiento': {'id': 'movimiento-1', 'accion': operacion.movimiento},
};

void main() {
  test(
    'QR se consulta en el servidor configurado y rechaza enlaces ajenos',
    () {
      expect(
        referenciaQr(
          'http://127.0.0.1:8000/hojas/$hojaId',
          'http://192.168.1.8:8000',
        ),
        hojaId,
      );
      expect(referenciaQr(hojaId, 'http://localhost:8000'), hojaId);
      for (final valor in [
        'http://ajeno.test:8000/hojas/$hojaId',
        'http://localhost:8000/documentos/$hojaId',
        'http://usuario:clave@localhost:8000/hojas/$hojaId',
        'http://localhost:8000/hojas/$hojaId?token=123',
        'texto sin QR',
        'javascript:alert(1)',
      ]) {
        expect(
          () => referenciaQr(valor, 'http://localhost:8000'),
          throwsA(isA<ErrorLaravel>()),
        );
      }
    },
  );

  test('normalización conserva los caracteres Unicode acordados', () {
    expect(textoRecorrido(' \tObservación\r\n'), 'Observación');
    expect(textoRecorrido('\u00a0📄'), '\u00a0📄');
    expect(textoRecorrido(' \n\t'), '');
  });

  for (final operacion in OperacionRecorrido.values) {
    test('reintento de ${operacion.name} conserva cuerpo y clave', () async {
      final peticiones = <http.Request>[];
      final api = ApiLaravel(
        baseUrl: 'http://api.test',
        client: MockClient((r) async {
          peticiones.add(r);
          return respuesta(
            confirmado(operacion, 3),
            peticiones.length == 1 ? 201 : 200,
          );
        }),
      )..token = 'sesion';
      addTearDown(api.close);
      final solicitud = SolicitudRecorrido(
        hoja: hojaId,
        documento: docId,
        operacion: operacion,
        datos: {'version': 3},
        token: api.token,
      );
      final servicio = RecorridoApi(api);
      expect(
        await servicio.enviar(solicitud),
        await servicio.enviar(solicitud),
      );
      expect(peticiones[0].url.path, '/api/hojas/$hojaId/${operacion.ruta}');
      expect(
        peticiones[0].headers['Idempotency-Key'],
        peticiones[1].headers['Idempotency-Key'],
      );
      expect(peticiones[0].body, peticiones[1].body);
      expect(peticiones[0].followRedirects, isFalse);
    });
  }

  test(
    'sesión cambiada evita reenviar una solicitud de otro usuario',
    () async {
      var solicitudes = 0;
      final api = ApiLaravel(
        client: MockClient((_) async {
          solicitudes++;
          return respuesta({});
        }),
      )..token = 'nueva';
      addTearDown(api.close);
      final solicitud = SolicitudRecorrido(
        hoja: hojaId,
        documento: docId,
        operacion: OperacionRecorrido.recibir,
        datos: {'version': 2},
        token: 'anterior',
      );
      await expectLater(
        RecorridoApi(api).enviar(solicitud),
        throwsA(isA<ErrorLaravel>()),
      );
      expect(solicitudes, 0);
    },
  );

  test(
    'respuesta de otro expediente conserva el resultado como incierto',
    () async {
      final api = ApiLaravel(
        client: MockClient(
          (_) async => respuesta({
            ...confirmado(OperacionRecorrido.atender, 3),
            'documento_id': 'otro',
          }, 201),
        ),
      )..token = 'sesion';
      addTearDown(api.close);
      await expectLater(
        RecorridoApi(api).enviar(
          SolicitudRecorrido(
            hoja: hojaId,
            documento: docId,
            operacion: OperacionRecorrido.atender,
            datos: {'version': 3},
            token: api.token,
          ),
        ),
        throwsA(
          isA<ErrorLaravel>().having(
            (e) => e.codigo,
            'codigo',
            'RESPUESTA_INCIERTA',
          ),
        ),
      );
    },
  );

  Future<void> montar(
    WidgetTester tester,
    ApiLaravel api,
    Future<void> Function(Map<String, dynamic>?) confirmar, {
    List<String> acciones = const ['derivar', 'atender'],
  }) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              RecorridoDocumento(
                api: api,
                documento: {
                  'id': docId,
                  'hoja': {'id': hojaId, 'version': 3},
                  'acciones_permitidas': acciones,
                },
                alConfirmar: confirmar,
                alOcuparse: (_) {},
                alPendiente: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'atención incierta bloquea edición y reintenta la misma intención',
    (tester) async {
      final peticiones = <http.Request>[];
      Map<String, dynamic>? resultado;
      final api = ApiLaravel(
        client: MockClient((r) async {
          peticiones.add(r);
          if (peticiones.length == 1) return respuesta({}, 503);
          return respuesta(confirmado(OperacionRecorrido.atender, 3));
        }),
      )..token = 'sesion';
      addTearDown(api.close);
      await montar(tester, api, (r) async {
        resultado = r;
      });
      await tester.tap(find.text('Registrar atención'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Solicitud revisada');
      await tester.tap(find.text('Guardar atención'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar confirmación'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      await tester.tap(find.text('Reintentar confirmación'));
      await tester.pumpAndSettle();
      expect(peticiones.length, 2);
      expect(peticiones[0].body, peticiones[1].body);
      expect(
        peticiones[0].headers['Idempotency-Key'],
        peticiones[1].headers['Idempotency-Key'],
      );
      expect(resultado?['hoja']['estado'], 'EN_ATENCION');
      expect(find.textContaining('Atención guardada'), findsOneWidget);
    },
  );

  testWidgets('conflicto actualiza el documento sin repetir el POST', (
    tester,
  ) async {
    var posts = 0, actualizaciones = 0;
    final api = ApiLaravel(
      client: MockClient((r) async {
        posts++;
        return respuesta({'codigo': 'VERSION_DESACTUALIZADA'}, 409);
      }),
    )..token = 'sesion';
    addTearDown(api.close);
    await montar(tester, api, (r) async {
      expect(r, isNull);
      actualizaciones++;
    });
    await tester.tap(find.text('Registrar atención'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Atención');
    await tester.tap(find.text('Guardar atención'));
    await tester.pumpAndSettle();
    expect(posts, 1);
    expect(actualizaciones, 1);
    expect(find.textContaining('La hoja cambió'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
  });

  testWidgets(
    'observación vacía o de 2001 puntos de código no llega al servidor',
    (tester) async {
      var posts = 0;
      final api = ApiLaravel(
        client: MockClient((_) async {
          posts++;
          return respuesta({});
        }),
      )..token = 'sesion';
      addTearDown(api.close);
      await montar(tester, api, (_) async {});
      await tester.tap(find.text('Registrar atención'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar atención'));
      await tester.pumpAndSettle();
      expect(posts, 0);
      await tester.enterText(
        find.byType(TextFormField),
        List.filled(2001, '📄').join(),
      );
      await tester.tap(find.text('Guardar atención'));
      await tester.pumpAndSettle();
      expect(posts, 0);
    },
  );

  testWidgets('recepción exige confirmación explícita', (tester) async {
    var posts = 0;
    final api = ApiLaravel(
      client: MockClient((_) async {
        posts++;
        return respuesta(confirmado(OperacionRecorrido.recibir, 3), 201);
      }),
    )..token = 'sesion';
    addTearDown(api.close);
    await montar(tester, api, (_) async {}, acciones: ['recibir']);
    await tester.tap(find.text('Confirmar recepción'));
    await tester.pumpAndSettle();
    expect(posts, 0);
    await tester.tap(find.text('Confirmar recepción').last);
    await tester.pumpAndSettle();
    expect(find.text('¿Confirmar recepción?'), findsOneWidget);
    expect(posts, 0);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancelar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(posts, 0);
    await tester.tap(find.text('Confirmar recepción').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar recepción').last);
    await tester.pumpAndSettle();
    expect(posts, 1);
  });

  testWidgets(
    'consulta sin permiso de acción no muestra botones de escritura',
    (tester) async {
      final api = ApiLaravel(client: MockClient((_) async => respuesta({})))
        ..token = 'sesion';
      addTearDown(api.close);
      await montar(tester, api, (_) async {}, acciones: []);
      expect(find.text('Derivar hoja'), findsNothing);
      expect(find.text('Confirmar recepción'), findsNothing);
      expect(find.text('Registrar atención'), findsNothing);
    },
  );
}
