import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:t4_movil/funciones/camara/captura_documento_page.dart';
import 'package:t4_movil/funciones/mi_bandeja/bandeja_laravel_page.dart';
import 'package:t4_movil/funciones/camara/camara_documento.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/compartido/diseno/sakai_theme.dart';

import 'soporte/camara_falsa.dart';

void main() {
  late Directory dir;
  late CamaraPrueba camara;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('camara-widget-');
    camara = CamaraPrueba();
    for (final name in ['primera', 'segunda']) {
      final file = File('${dir.path}/$name.png');
      await file.writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aDZkAAAAASUVORK5CYII=',
        ),
      );
      camara.fotos.add(
        FotoDocumento(file.path, bytes: await file.readAsBytes()),
      );
    }
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<void> tocar(WidgetTester t, String texto) async {
    if (find.text(texto).evaluate().isEmpty) {
      await t.scrollUntilVisible(
        find.text(texto),
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.ensureVisible(find.text(texto));
    await t.pumpAndSettle();
    await t.tap(find.text(texto));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await t.pumpAndSettle();
  }

  Future<void> abrir(WidgetTester t) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpWidget(
      MaterialApp(
        theme: Sakai.theme,
        home: CapturaDocumentoPage(codigo: 'DOC-001', camara: camara),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('pide permiso al abrir, no al entrar; negar no insiste', (
    t,
  ) async {
    camara.error = const ErrorCamara('Permiso denegado');
    await abrir(t);
    expect(camara.solicitudes, isEmpty);
    expect(find.textContaining('Incluye la hoja completa'), findsOneWidget);
    await tocar(t, 'Abrir cámara');
    expect(find.text('Permiso denegado'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    expect(camara.solicitudes, [true]);
    expect(find.text('Tomar foto'), findsNothing);
  });

  testWidgets('permiso bloqueado ofrece ajustes y vuelve sin pedir permiso', (
    t,
  ) async {
    camara.error = const ErrorCamara('Cámara bloqueada', abrirAjustes: true);
    await abrir(t);
    await tocar(t, 'Abrir cámara');
    expect(find.text('Abrir cámara'), findsNothing);
    await tocar(t, 'Abrir ajustes');
    expect(camara.ajustes, 1);
    camara.error = null;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(camara.solicitudes, [true, false]);
    await t.scrollUntilVisible(
      find.text('Tomar foto'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tomar foto'), findsOneWidget);
  });

  testWidgets('repetir elimina la captura anterior; captura no confirma sola', (
    t,
  ) async {
    await abrir(t);
    await tocar(t, 'Abrir cámara');
    await tocar(t, 'Tomar foto');
    await t.scrollUntilVisible(
      find.text('Usar foto'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Usar foto'), findsOneWidget);
    expect(find.textContaining('Pulsa Usar foto'), findsOneWidget);
    await tocar(t, 'Volver a tomar');
    expect(File('${dir.path}/primera.png').existsSync(), isFalse);
    expect(find.text('Usar foto'), findsNothing);
    await t.scrollUntilVisible(
      find.text('Tomar foto'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tomar foto'), findsOneWidget);
  });

  testWidgets('al volver del segundo plano se reabre sin solicitar permiso', (
    t,
  ) async {
    await abrir(t);
    await tocar(t, 'Abrir cámara');
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pump();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(camara.solicitudes, [true, false]);
  });

  testWidgets(
    'usar foto la vincula al documento sin POST; Atrás pide descartar',
    (t) async {
      final peticiones = <String>[];
      final api = ApiLaravel(
        client: MockClient((r) async {
          peticiones.add(r.method);
          if (r.url.path.endsWith('/adjuntos')) {
            return http.Response(
              jsonEncode({'data': [], 'current_page': 1, 'last_page': 1}),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'id': 'id-001',
              'codigo': 'DOC-001',
              'asunto': 'Carta de prueba',
            }),
            200,
          );
        }),
      )..token = 'solo-test';
      addTearDown(api.close);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpWidget(
        MaterialApp(
          theme: Sakai.theme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DetalleLaravelPage(
                      api: api,
                      id: 'id-001',
                      crearCamara: () => camara,
                    ),
                  ),
                ),
                child: const Text('Abrir documento'),
              ),
            ),
          ),
        ),
      );
      await tocar(t, 'Abrir documento');
      await tocar(t, 'Adjuntar foto');
      await tocar(t, 'Abrir cámara');
      await tocar(t, 'Tomar foto');
      await tocar(t, 'Usar foto');
      expect(find.text('Subir foto'), findsOneWidget);
      expect(peticiones, everyElement('GET'));
      await t.drag(find.byType(ListView).first, const Offset(0, 1800));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Subir foto'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Subir foto'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('¿Descartar la foto pendiente?'), findsOneWidget);
      await tocar(t, 'Seguir aquí');
      expect(find.text('Subir foto'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await tocar(t, 'Descartar y salir');
      expect(find.text('Abrir documento'), findsOneWidget);
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      expect(File('${dir.path}/primera.png').existsSync(), isFalse);
    },
  );

  testWidgets(
    'con texto grande los consejos se pueden recorrer sin desbordar',
    (t) async {
      await t.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => t.binding.setSurfaceSize(null));
      t.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await abrir(t);
      await tocar(t, 'Abrir cámara');
      await tocar(t, 'Tomar foto');
      await t.scrollUntilVisible(
        find.text('Volver a tomar'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
}
