import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:t4_movil/funciones/mi_bandeja/detalle_laravel_page.dart';
import 'package:t4_movil/funciones/notas_internas/detalle_nota_page.dart';
import 'package:t4_movil/funciones/notas_internas/vista_previa_nota.dart';
import 'package:t4_movil/funciones/recorrido/recorrido_api.dart';
import 'package:t4_movil/funciones/recorrido/recorrido_documento.dart';

import 'notas_internas_test.dart' as fixture;
import 'recorrido_test.dart' as recorrido;

Map<String, dynamic> documento(
  OperacionRecorrido operacion,
  bool actualizado,
) => {
  'id': recorrido.docId,
  'asunto': 'Documento de prueba',
  'estado': actualizado
      ? (recorrido.confirmado(operacion, 1)['hoja'] as Map)['estado']
      : operacion == OperacionRecorrido.recibir
      ? 'PENDIENTE_RECEPCION'
      : 'RECIBIDA',
  'hoja': {'id': recorrido.hojaId, 'version': actualizado ? 2 : 1},
  'acciones_permitidas': actualizado ? <String>[] : [operacion.name],
};

Future<void> montar(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1100, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

Future<void> operar(WidgetTester tester, OperacionRecorrido operacion) async {
  await tester.tap(find.text(operacion.titulo));
  await tester.pumpAndSettle();
  if (operacion == OperacionRecorrido.derivar) {
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Destino nuevo').last);
    await tester.pumpAndSettle();
  }
  if (operacion != OperacionRecorrido.recibir) {
    await tester.enterText(
      find.byType(TextFormField),
      'Acción confirmada de prueba',
    );
  }
  final label = operacion == OperacionRecorrido.atender
      ? 'Guardar atención'
      : operacion.titulo;
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pumpAndSettle();
  if (operacion == OperacionRecorrido.recibir) {
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Confirmar recepción'),
      ),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final estadoAnterior in [200, 403, 503]) {
    testWidgets(
      'respuesta antigua $estadoAnterior no limpia ni desbloquea la recarga nueva',
      (tester) async {
        final antigua = Completer<http.Response>();
        final recarga = Completer<http.Response>();
        const operacion = OperacionRecorrido.atender;
        var gets = 0;
        final api = fixture.conectar((r) async {
          if (r.method == 'POST') {
            return fixture.respuesta(recorrido.confirmado(operacion, 1), 201);
          }
          if (r.url.path.endsWith('/historial')) {
            return fixture.respuesta({'data': []});
          }
          if (r.url.path.endsWith('/adjuntos')) {
            return fixture.respuesta({
              'data': [],
              'current_page': 1,
              'last_page': 1,
            });
          }
          gets++;
          if (gets == 2) return antigua.future;
          if (gets == 3) return recarga.future;
          return fixture.respuesta(documento(operacion, false));
        });
        try {
          await montar(
            tester,
            DetalleLaravelPage(api: api, id: recorrido.docId),
          );
          await tester.pump(const Duration(seconds: 3));
          await tester.pump();
          await tester.tap(find.text('Registrar atención'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byType(TextFormField),
            'Atención comprobada',
          );
          await tester.tap(find.text('Guardar atención'));
          await tester.pump();
          expect(gets, 3);
          antigua.complete(
            fixture.respuesta(
              estadoAnterior == 200 ? documento(operacion, false) : {},
              estadoAnterior,
            ),
          );
          await tester.pump();
          expect(
            find.byType(LinearProgressIndicator),
            findsNWidgets(2),
            reason: 'La carga nueva y el envío siguen protegidos.',
          );
          expect(find.text('EN ATENCION'), findsOneWidget);
          expect(find.textContaining('Sin actualización'), findsNothing);
          final confirmado = tester
              .widget<RecorridoDocumento>(find.byType(RecorridoDocumento))
              .documento;
          expect((confirmado['hoja'] as Map)['version'], 2);
          expect(confirmado['acciones_permitidas'], isEmpty);
          recarga.complete(fixture.respuesta(documento(operacion, true)));
          await tester.pumpAndSettle();
          expect(find.byType(LinearProgressIndicator), findsNothing);
          expect(find.text('EN ATENCION'), findsOneWidget);
        } finally {
          if (!antigua.isCompleted) {
            antigua.complete(fixture.respuesta(documento(operacion, false)));
          }
          if (!recarga.isCompleted) {
            recarga.complete(fixture.respuesta(documento(operacion, true)));
          }
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      },
    );
  }
  for (final operacion in OperacionRecorrido.values) {
    for (final estadoPost in [201, 409]) {
      testWidgets(
        'documento: GET anterior no restaura ${operacion.name} tras POST $estadoPost',
        (tester) async {
          final antigua = Completer<http.Response>();
          var actualizado = false, gets = 0, posts = 0;
          final snapshot = fixture.respuesta(documento(operacion, false));
          final api = fixture.conectar((r) async {
            if (r.method == 'POST') {
              posts++;
              actualizado = true;
              return estadoPost == 409
                  ? fixture.respuesta({}, 409)
                  : fixture.respuesta(recorrido.confirmado(operacion, 1), 201);
            }
            if (r.url.path.endsWith('/destinos')) {
              return fixture.respuesta({
                'data': [
                  {'id': 3, 'nombre': 'Destino nuevo'},
                ],
              });
            }
            if (r.url.path.endsWith('/historial')) {
              return fixture.respuesta({'data': []});
            }
            if (r.url.path.endsWith('/adjuntos')) {
              return fixture.respuesta({
                'data': [],
                'current_page': 1,
                'last_page': 1,
              });
            }
            gets++;
            if (gets == 2) return antigua.future;
            return fixture.respuesta(documento(operacion, actualizado));
          });
          try {
            await montar(
              tester,
              DetalleLaravelPage(api: api, id: recorrido.docId),
            );
            await tester.pump(const Duration(seconds: 3));
            await tester.pump();
            expect(gets, 2);
            await operar(tester, operacion);
            expect(posts, 1);
            antigua.complete(snapshot);
            await tester.pumpAndSettle();
            expect(
              gets,
              3,
              reason: 'La acción exige una consulta nueva sin esperar el próximo temporizador.',
            );
            final mostrado = tester
                .widget<RecorridoDocumento>(find.byType(RecorridoDocumento))
                .documento;
            expect((mostrado['hoja'] as Map)['version'], 2);
            expect(mostrado['estado'], documento(operacion, true)['estado']);
            expect(mostrado['acciones_permitidas'], isEmpty);
            expect(find.text(operacion.titulo), findsNothing);
          } finally {
            if (!antigua.isCompleted) antigua.complete(snapshot);
            await tester.pumpAndSettle();
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
          }
        },
      );
    }
  }
  for (final estadoPost in [200, 409]) {
    testWidgets(
      'nota: recepción recarga tras POST $estadoPost aunque haya un GET anterior',
      (tester) async {
        final antigua = Completer<http.Response>();
        var actualizado = false, gets = 0;
        Map<String, dynamic> nota() => fixture.nota(
          version: actualizado ? 4 : 3,
          vinculada: actualizado,
          estado: actualizado ? 'recibida' : 'pendiente_recepcion',
          acciones: actualizado ? [] : ['confirmar_primera_recepcion'],
        );
        final snapshot = fixture.respuesta(nota());
        final api = fixture.conectar((r) async {
          if (r.method == 'POST') {
            actualizado = true;
            return fixture.respuesta(
              estadoPost == 409 ? {} : nota(),
              estadoPost,
            );
          }
          if (r.url.path.endsWith('/hojas/hoja-1')) {
            return fixture.respuesta({
              'id': 'doc-1',
              'hoja': {'id': 'hoja-1', 'version': 1},
              'acciones_permitidas': [],
            });
          }
          gets++;
          if (gets == 2) return antigua.future;
          return fixture.respuesta(nota());
        });
        try {
          await montar(tester, DetalleNotaPage(api: api, id: 'nota-1'));
          await tester.pump(const Duration(seconds: 3));
          await tester.pump();
          expect(gets, 2);
          await fixture.pulsar(tester, 'Confirmar recepción');
          await fixture.pulsar(tester, 'Confirmar');
          antigua.complete(snapshot);
          await tester.pumpAndSettle();
          expect(gets, 3);
          final mostrado = tester
              .widget<DocumentoNota>(find.byType(DocumentoNota))
              .nota;
          expect(mostrado.estado, 'recibida');
          expect(mostrado.version, 4);
          expect(
            find.widgetWithText(FilledButton, 'Confirmar recepción'),
            findsNothing,
          );
        } finally {
          if (!antigua.isCompleted) antigua.complete(snapshot);
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      },
    );
    testWidgets(
      'nota: hoja atrasada no revierte atención tras POST $estadoPost con igual versión de nota',
      (tester) async {
        final antigua = Completer<http.Response>();
        var actualizado = false, hojas = 0, gets = 0;
        Map<String, dynamic> nota() => fixture.nota(
          version: 4,
          vinculada: true,
          estado: actualizado ? 'en_atencion' : 'recibida',
          acciones: actualizado ? [] : ['registrar_atencion'],
        );
        final snapshot = fixture.respuesta({
          'id': 'doc-1',
          'hoja': {'id': 'hoja-1', 'version': 8},
          'acciones_permitidas': ['atender'],
        });
        final api = fixture.conectar((r) async {
          if (r.method == 'POST') {
            actualizado = true;
            return estadoPost == 409
                ? fixture.respuesta({}, 409)
                : fixture.respuesta({
                    'documento_id': 'doc-1',
                    'hoja': {
                      'id': 'hoja-1',
                      'version': 9,
                      'estado': 'EN_ATENCION',
                      'responsable_id': 1,
                      'unidad_vigente_id': 1,
                    },
                    'movimiento': {
                      'id': 'atencion-confirmada',
                      'accion': 'ATENCION',
                    },
                  }, 201);
          }
          if (r.url.path.endsWith('/hojas/hoja-1')) {
            hojas++;
            if (hojas == 2) return antigua.future;
            return fixture.respuesta({
              'id': 'doc-1',
              'hoja': {'id': 'hoja-1', 'version': actualizado ? 9 : 8},
              'acciones_permitidas': actualizado ? [] : ['atender'],
            });
          }
          gets++;
          return fixture.respuesta(nota());
        });
        try {
          await montar(tester, DetalleNotaPage(api: api, id: 'nota-1'));
          await tester.pump(const Duration(seconds: 3));
          await tester.pump();
          expect(hojas, 2);
          await operar(tester, OperacionRecorrido.atender);
          antigua.complete(snapshot);
          await tester.pumpAndSettle();
          expect(gets, 3);
          final mostrado = tester
              .widget<DocumentoNota>(find.byType(DocumentoNota))
              .nota;
          expect(mostrado.estado, 'en_atencion');
          expect(mostrado.version, 4);
          final recorrido = tester
              .widget<RecorridoDocumento>(find.byType(RecorridoDocumento))
              .documento;
          expect((recorrido['hoja'] as Map)['version'], 9);
          expect(recorrido['acciones_permitidas'], isEmpty);
        } finally {
          if (!antigua.isCompleted) antigua.complete(snapshot);
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      },
    );
  }
}
