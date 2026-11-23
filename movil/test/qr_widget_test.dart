import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/funciones/qr/consulta_qr_page.dart';
import 'package:t4_movil/funciones/notas_internas/detalle_nota_page.dart';

import 'notas_internas_test.dart' as fixture;

class _CamaraQr extends MobileScannerPlatform {
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets(
    'el QR de hoja abre la nota vinculada y vuelve a comprobar su permiso',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final anterior = MobileScannerPlatform.instance;
      MobileScannerPlatform.instance = _CamaraQr();
      addTearDown(() => MobileScannerPlatform.instance = anterior);
      const hoja = '11111111-1111-4111-8111-111111111111';
      final rutas = <String>[];
      final api = fixture.conectar((r) async {
        rutas.add('${r.method} ${r.url.path}');
        if (r.url.path == '/api/hojas/$hoja') {
          return fixture.respuesta({
            'id': 'documento-1',
            'hoja': {'id': hoja},
            'nota_id': 'nota-1',
          });
        }
        return fixture.respuesta(fixture.nota(acciones: []));
      });
      await tester.pumpWidget(MaterialApp(home: ConsultaQrPage(api: api)));
      await tester.enterText(find.byType(TextField), hoja);
      await tester.ensureVisible(find.text('Abrir hoja'));
      await tester.tap(find.text('Abrir hoja'));
      await tester.pumpAndSettle();
      expect(find.byType(DetalleNotaPage), findsOneWidget);
      expect(rutas, ['GET /api/hojas/$hoja', 'GET /api/notas-internas/nota-1']);
      expect(find.text('CM/TI/001'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('permiso QR denegado ofrece pegar enlace sin llamar a la API', (
    tester,
  ) async {
    final anterior = MobileScannerPlatform.instance;
    MobileScannerPlatform.instance = _CamaraQr();
    addTearDown(() {
      MobileScannerPlatform.instance = anterior;
    });
    const canal = MethodChannel('flutter.baseflow.com/permissions/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (call) async {
          if (call.method == 'checkPermissionStatus') return 0;
          if (call.method == 'requestPermissions') return {1: 0};
          return false;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(canal, null),
    );
    var solicitudes = 0;
    final api = ApiLaravel(
      client: MockClient((_) async {
        solicitudes++;
        return http.Response(jsonEncode({}), 200);
      }),
    )..token = 'sesion';
    addTearDown(api.close);
    await tester.pumpWidget(MaterialApp(home: ConsultaQrPage(api: api)));
    await tester.tap(find.text('Abrir cámara para escanear'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Permite usar la cámara'), findsOneWidget);
    expect(find.text('Abrir hoja'), findsOneWidget);
    expect(solicitudes, 0);
    await tester.enterText(find.byType(TextField), 'QR incorrecto');
    await tester.ensureVisible(find.text('Abrir hoja'));
    await tester.tap(find.text('Abrir hoja'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Este QR no corresponde'), findsOneWidget);
    expect(solicitudes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
