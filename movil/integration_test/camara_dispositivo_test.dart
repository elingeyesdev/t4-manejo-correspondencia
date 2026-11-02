import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:t4_movil/services/camara_documento.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // La cámara se autoriza previamente en el dispositivo dedicado de pruebas.
  // No concede permisos, no usa la API y no guarda documentos en el backend.
  testWidgets('cámara Android: captura real, reanudación y descarte', (
    tester,
  ) async {
    expect(
      await Permission.camera.isGranted,
      isTrue,
      reason: 'Autoriza Cámara en el dispositivo de pruebas antes de ejecutar.',
    );
    final camara = CamaraAndroid();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Prueba de cámara'))),
    );
    try {
      await camara.iniciar(solicitarPermiso: false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: camara.vista())),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      final foto = await camara.tomar();
      final bytes = await File(foto.ruta).readAsBytes();
      expect(bytes.length, greaterThan(100));
      expect(bytes.take(2), [0xff, 0xd8]);
      await foto.descartar();
      expect(await File(foto.ruta).exists(), isFalse);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await camara.cerrar();
      await camara.iniciar(solicitarPermiso: false);
      final segunda = await camara.tomar();
      expect(await File(segunda.ruta).length(), greaterThan(100));
      await segunda.descartar();
    } finally {
      await camara.cerrar();
    }
  });
}
