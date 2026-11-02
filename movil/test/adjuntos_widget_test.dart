import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:t4_movil/pages/bandeja_laravel_page.dart';
import 'package:t4_movil/services/camara_documento.dart';
import 'package:t4_movil/services/laravel_api.dart';
import 'package:t4_movil/theme/sakai_theme.dart';

import 'soporte/camara_falsa.dart';

void main() {
  late Directory carpeta;
  late CamaraPrueba camara;
  late Uint8List bytes;
  late ApiLaravel api;
  late List<Map<String, dynamic>> archivos;
  late Completer<http.Response> subida;
  String nombre = 'foto.png';
  var posts = 0;
  setUp(() async {
    carpeta = await Directory.systemTemp.createTemp('adjuntos-ui-');
    bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aDZkAAAAASUVORK5CYII=',
    );
    final file = File('${carpeta.path}/foto.png');
    await file.writeAsBytes(bytes);
    camara = CamaraPrueba()..fotos.add(FotoDocumento(file.path, bytes: bytes));
    archivos = [];
    posts = 0;
    subida = Completer<http.Response>();
    api = ApiLaravel(
      baseUrl: 'http://api.test',
      client: MockClient((r) async {
        if (r.method == 'POST') {
          posts++;
          nombre = RegExp('filename="([^"]+)"')
              .firstMatch(latin1.decode(r.bodyBytes))!
              .group(1)!;
          return subida.future;
        }
        if (r.url.path.endsWith('/descarga')) {
          return http.Response.bytes(
            bytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        if (r.url.path.endsWith('/adjuntos')) {
          return http.Response(
            jsonEncode({'data': archivos, 'current_page': 1, 'last_page': 1}),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'id': 'doc-1',
            'codigo': 'DOC-001',
            'asunto': 'Carta de prueba',
          }),
          200,
        );
      }),
    )..token = 'test';
  });
  tearDown(() async {
    api.close();
    if (await carpeta.exists()) await carpeta.delete(recursive: true);
  });
  Map<String, dynamic> adjunto() => {
    'id': 'adjunto-1',
    'document_id': 'doc-1',
    'nombre': nombre,
    'mime': 'image/png',
    'tamano_bytes': bytes.length,
    'creado_en': '2026-11-02T12:00:00Z',
  };

  Future<void> tocar(WidgetTester t, String text) async {
    if (find.text(text).evaluate().isEmpty) {
      await t.scrollUntilVisible(
        find.text(text),
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.ensureVisible(find.text(text));
    await t.pumpAndSettle();
    await t.tap(find.text(text));
    await t.pumpAndSettle();
  }

  Future<void> abrir(WidgetTester t, {bool puedeAdjuntar = true}) async {
    subida = Completer<http.Response>();
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
                    id: 'doc-1',
                    crearCamara: () => camara,
                    puedeAdjuntar: puedeAdjuntar,
                  ),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tocar(t, 'Abrir');
  }

  Future<void> foto(WidgetTester t) async {
    await tocar(t, 'Adjuntar foto');
    await tocar(t, 'Abrir cámara');
    await tocar(t, 'Tomar foto');
    await tocar(t, 'Usar foto');
    await t.scrollUntilVisible(
      find.text('Subir foto'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'no duplica al pulsar dos veces ni permite salir durante la subida; abre el adjunto guardado',
    (t) async {
      await abrir(t);
      await foto(t);
      await t.tap(find.text('Subir foto'));
      await t.pump();
      await t.tap(find.text('Subir foto'));
      await t.pump();
      expect(posts, 1);
      await t.pageBack();
      await t.pump();
      expect(find.text('Espera a que termine la subida.'), findsOneWidget);
      archivos.add(adjunto());
      subida.complete(http.Response(jsonEncode(adjunto()), 201));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pumpAndSettle();
      expect(find.text('Foto guardada correctamente.'), findsOneWidget);
      expect(find.text('Subir foto'), findsNothing);
      await tocar(t, nombre);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(posts, 1);
    },
  );

  testWidgets(
    'rechazo del servidor conserva la foto para corregir o volver a intentar',
    (t) async {
      await abrir(t);
      await foto(t);
      await t.tap(find.text('Subir foto'));
      await t.pump();
      subida.complete(
        http.Response(
          '{"errors":{"archivo":["Archivo rechazado por formato."]}}',
          422,
        ),
      );
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pumpAndSettle();
      expect(find.text('Archivo rechazado por formato.'), findsOneWidget);
      expect(find.text('Subir foto'), findsOneWidget);
      expect(find.text('Foto guardada correctamente.'), findsNothing);
    },
  );

  testWidgets(
    'funcionario consulta los adjuntos pero no recibe el botón de captura',
    (t) async {
      archivos.add(adjunto());
      await abrir(t, puedeAdjuntar: false);
      await t.scrollUntilVisible(
        find.text('Archivos guardados'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(nombre), findsOneWidget);
      expect(find.text('Adjuntar foto'), findsNothing);
      expect(posts, 0);
    },
  );
}
