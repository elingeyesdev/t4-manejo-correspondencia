import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/funciones/notas_internas/detalle_nota_page.dart';
import 'package:t4_movil/funciones/notas_internas/nota_interna.dart';
import 'package:t4_movil/funciones/notas_internas/seguimiento_nota.dart';
import 'package:t4_movil/funciones/notas_internas/vista_previa_nota.dart';

import 'notas_internas_test.dart' as fixture;

Map<String, dynamic> seguimiento(int actual) => {
  'etapa': SeguimientoNota.etapas.keys.elementAt(actual),
  'etiqueta': SeguimientoNota.etapas.values.elementAt(actual),
  'unidad': {'id': actual + 1, 'nombre': 'Unidad ficticia $actual'},
};

Map<String, dynamic> detalle(int actual) => {
  ...fixture.nota(
    version: actual + 3,
    acciones: [],
    estado: actual == 4 ? 'cerrada' : 'recibida',
  ),
  'seguimiento': seguimiento(actual),
  'constancias': [
    {
      'tipo': 'firma',
      'accion': 'firma_remitente',
      'version': 1,
      'actor': {'nombre': 'Autor ficticio'},
      'unidad': {'nombre': 'Origen ficticio'},
      'fecha': '2026-11-22T19:00:00Z',
    },
  ],
  'sello_recepcion': {
    'id': 'constancia-opaca-no-visible',
    'cite': 'CM/TI/001',
    'unidad': 'Destino ficticio',
    'funcionario': 'Receptor ficticio',
    'fecha_hora': '2026-11-22T20:00:00Z',
  },
};

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('no inventa etapas o sellos cuando la API todavía no los publica', () {
    final nota = NotaInterna.desdeJson(fixture.nota());
    expect(nota.seguimiento, isNull);
    expect(nota.constancias, isEmpty);
  });
  test(
    'consume el sello real de #58 y conserva una sola constancia al reintentar',
    () {
      final datos = detalle(2);
      for (var intento = 0; intento < 2; intento++) {
        final nota = NotaInterna.desdeJson(datos);
        expect(nota.constancias.where((c) => c.tipo == 'recepcion').length, 1);
        final sello = nota.constancias.last;
        expect(sello.actor, 'Receptor ficticio');
        expect(sello.unidad, 'Destino ficticio');
        expect(sello.fecha.toUtc(), DateTime.utc(2026, 11, 22, 20));
        expect(nota.constancias.first.accion, 'firma_remitente');
      }
      expect(
        NotaInterna.desdeJson({...datos, 'sello_recepcion': null})
            .constancias
            .length,
        1,
      );
      expect(
        () => NotaInterna.desdeJson({
          ...datos,
          'sello_recepcion': {'fecha_hora': 'sin-fecha'},
        }),
        throwsA(isA<ErrorLaravel>()),
      );
    },
  );
  test(
    'rechaza etapas desconocidas o un destino sin identificación válida',
    () {
      expect(
        () => SeguimientoNota.desdeJson({
          ...seguimiento(1),
          'etapa': 'no_confirmada',
        }),
        throwsA(isA<ErrorLaravel>()),
      );
      expect(
        () => SeguimientoNota.desdeJson({
          ...seguimiento(1),
          'unidad': {'nombre': 'Sin ID'},
        }),
        throwsA(isA<ErrorLaravel>()),
      );
    },
  );
  testWidgets(
    'recepción, derivación y cierre se reflejan sin reabrir en tres segundos',
    (tester) async {
      var actual = detalle(0), gets = 0;
      final api = fixture.conectar((r) async {
        gets++;
        return fixture.respuesta(actual);
      });
      await fixture.abrir(tester, DetalleNotaPage(api: api, id: 'nota-1'));
      expect(find.text('Trámite finalizado'), findsNothing);
      expect(find.text('Volver al inicio'), findsNothing);
      final derivada = {
        ...detalle(2),
        'seguimiento': {
          ...seguimiento(2),
          'etiqueta': 'Recepción por derivación pendiente',
          'unidad': {'id': 20, 'nombre': 'Unidad derivada'},
        },
      };
      for (final nueva in [detalle(2), derivada, detalle(4)]) {
        actual = nueva;
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        final barra = tester.widget<BarraSeguimientoNota>(
          find.byType(BarraSeguimientoNota),
        );
        final seguimiento = nueva['seguimiento'] as Map;
        expect(
          barra.seguimiento.pasos.singleWhere((p) => p.estado == 'actual').id,
          seguimiento['etapa'],
        );
        expect(barra.seguimiento.unidad, seguimiento['unidad']['nombre']);
        expect(
          find.byKey(const ValueKey('sobre-etapa-actual')),
          findsOneWidget,
        );
        expect(find.byType(LinearProgressIndicator), findsNothing);
      }
      expect(gets, 4);
      expect(find.text('Trámite finalizado'), findsOneWidget);
      expect(find.text('Volver al inicio').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
      expect(gets, 4, reason: 'El detalle cerrado no continúa consultando.');
    },
  );
  testWidgets(
    'se pausa en segundo plano y al perder permiso retira el documento',
    (tester) async {
      var gets = 0, denegado = false;
      final api = fixture.conectar((r) async {
        gets++;
        return fixture.respuesta(
          denegado ? {} : detalle(1),
          denegado ? 403 : 200,
        );
      });
      await fixture.abrir(tester, DetalleNotaPage(api: api, id: 'nota-1'));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 6));
      expect(gets, 1);
      denegado = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(gets, 2);
      expect(find.byType(DocumentoNota), findsNothing);
      expect(find.byType(BarraSeguimientoNota), findsNothing);
    },
  );
  testWidgets(
    'una desconexión conserva el estado confirmado y avisa sin avanzar',
    (tester) async {
      var offline = false;
      final api = fixture.conectar(
        (r) async =>
            fixture.respuesta(offline ? {} : detalle(1), offline ? 503 : 200),
      );
      await fixture.abrir(tester, DetalleNotaPage(api: api, id: 'nota-1'));
      offline = true;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      final barra = tester.widget<BarraSeguimientoNota>(
        find.byType(BarraSeguimientoNota),
      );
      expect(barra.seguimiento.pasos[1].estado, 'actual');
      expect(find.textContaining('último estado confirmado'), findsOneWidget);
    },
  );
  testWidgets(
    'la vista previa conserva firmas y sello y no expone IDs técnicos',
    (tester) async {
      final nota = NotaInterna.desdeJson({
        ...detalle(1),
        'id': 'uuid-tecnico',
        'documento_id': 'DOC-oculto',
      });
      await fixture.abrir(tester, VistaPreviaNota(nota: nota));
      await tester.scrollUntilVisible(
        find.text('RECIBIDO · DEMOSTRACIÓN'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('RECIBIDO · DEMOSTRACIÓN'), findsOneWidget);
      expect(find.text('uuid-tecnico'), findsNothing);
      expect(find.text('DOC-oculto'), findsNothing);
      expect(find.textContaining('constancia-opaca-no-visible'), findsNothing);
      expect(find.text('Receptor ficticio'), findsOneWidget);
      expect(find.text('Destino ficticio'), findsOneWidget);
      expect(find.text('22/11/2026 16:00:00 · Bolivia'), findsOneWidget);
      expect(find.textContaining('Versión firmada'), findsNothing);
      expect(find.text('CM/TI/001'), findsOneWidget);
      expect(find.text('Confirmar recepción'), findsNothing);
    },
  );
  testWidgets(
    'la etapa actual queda visible en teléfono angosto con letra grande',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final datos = SeguimientoNota.desdeJson(seguimiento(4));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(body: BarraSeguimientoNota(seguimiento: datos)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final sobre = find.byKey(const ValueKey('sobre-etapa-actual'));
      expect(sobre.hitTestable(), findsOneWidget);
      expect(find.text('Cierre').hitTestable(), findsOneWidget);
    },
  );
}
