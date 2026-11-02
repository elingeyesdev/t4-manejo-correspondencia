import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:t4_movil/pages/registro_laravel_page.dart';
import 'package:t4_movil/services/camara_documento.dart';
import 'package:t4_movil/services/laravel_api.dart';
import 'package:t4_movil/theme/sakai_theme.dart';

import 'soporte/camara_falsa.dart';

void main() {
  late Directory carpeta;
  late File archivo;
  late Uint8List bytes;
  late CamaraPrueba camara;
  late ApiLaravel api;
  var registros = 0, subidas = 0, fallo = 0;
  var guardado = false;
  var nombre = '';
  final catalogos = {
    'tipos': [
      {'id': 1, 'name': 'Oficio'},
    ],
    'prioridades': [
      {'id': 2, 'name': 'Normal'},
    ],
    'unidades': [
      {'id': 3, 'name': 'Recepción'},
    ],
  };
  http.Response json(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );
  Map<String, dynamic> adjunto() => {
    'id': 'foto-1',
    'document_id': 'doc-1',
    'nombre': nombre,
    'mime': 'image/png',
    'tamano_bytes': bytes.length,
    'creado_en': '2026-11-02T12:00:00Z',
  };
  setUp(() async {
    carpeta = await Directory.systemTemp.createTemp('registro-foto-');
    bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aDZkAAAAASUVORK5CYII=',
    );
    archivo = File('${carpeta.path}/foto.png');
    await archivo.writeAsBytes(bytes);
    camara = CamaraPrueba()
      ..fotos.add(FotoDocumento(archivo.path, bytes: bytes));
    registros = 0;
    subidas = 0;
    fallo = 0;
    guardado = false;
    nombre = '';
    api = ApiLaravel(
      baseUrl: 'http://api.test',
      client: MockClient((r) async {
        if (r.url.path.endsWith('/configuracion-registro')) {
          return json(catalogos);
        }
        if (r.url.path.endsWith('/documentos') && r.method == 'POST') {
          registros++;
          return json({
            'id': 'doc-1',
            'guia': 'COR-001',
            'codigo': 'DOC-001',
          }, 201);
        }
        if (r.url.path.endsWith('/adjuntos') && r.method == 'POST') {
          subidas++;
          nombre = RegExp('filename="([^"]+)"')
              .firstMatch(latin1.decode(r.bodyBytes))!
              .group(1)!;
          expect(r.url.path, '/api/documentos/doc-1/adjuntos');
          if (fallo == 422) {
            return json({
              'message': 'Foto no válida',
              'errors': {
                'archivo': ['Foto no válida'],
              },
            }, 422);
          }
          guardado = true;
          if (fallo == 503) return json({'message': 'Respuesta perdida'}, 503);
          return json(adjunto(), 201);
        }
        if (r.url.path.endsWith('/descarga')) {
          return http.Response.bytes(
            bytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        return json({
          'data': guardado ? [adjunto()] : [],
          'current_page': 1,
          'last_page': 1,
        });
      }),
    )..token = 'sesion';
  });
  tearDown(() async {
    api.close();
    await carpeta.delete(recursive: true);
  });

  Future<void> tocar(WidgetTester t, String texto) async {
    if (find.text(texto).evaluate().isEmpty) {
      await t.scrollUntilVisible(
        find.text(texto),
        220,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.ensureVisible(find.text(texto));
    await t.pumpAndSettle();
    await t.tap(find.text(texto));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pumpAndSettle();
  }

  Future<void> abrir(WidgetTester t) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpWidget(
      MaterialApp(
        theme: Sakai.theme,
        home: Scaffold(
          body: RegistroLaravelPage(api: api, crearCamara: () => camara),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), 'Dirección');
    await t.enterText(find.byType(TextFormField).at(1), 'Solicitud');
    for (final opcion in ['Oficio', 'Normal']) {
      final selector = find
          .byType(DropdownButtonFormField<int>)
          .at(opcion == 'Oficio' ? 0 : 1);
      await t.ensureVisible(selector);
      await t.tap(selector);
      await t.pumpAndSettle();
      await t.tap(find.text(opcion).last);
      await t.pumpAndSettle();
    }
  }

  Future<void> foto(WidgetTester t) async {
    await tocar(t, 'Adjuntar foto');
    await tocar(t, 'Abrir cámara');
    await tocar(t, 'Tomar foto');
    await tocar(t, 'Usar foto');
    expect(registros, 0);
    expect(subidas, 0);
    expect(find.text('Remitente'), findsOneWidget);
  }

  testWidgets('registro con foto sube al documento creado sin otro registro', (
    t,
  ) async {
    await abrir(t);
    await foto(t);
    await tocar(t, 'Registrar correspondencia');
    expect(registros, 1);
    expect(subidas, 1);
    expect(find.text('Foto guardada correctamente.'), findsOneWidget);
    expect(archivo.existsSync(), false);
    await tocar(t, 'Registrar otra correspondencia');
    expect(find.text('Foto del documento (opcional)'), findsOneWidget);
  });
  testWidgets('rechazo de foto conserva registro y reintenta solo el adjunto', (
    t,
  ) async {
    fallo = 422;
    await abrir(t);
    await foto(t);
    await tocar(t, 'Registrar correspondencia');
    expect(registros, 1);
    expect(subidas, 1);
    expect(archivo.existsSync(), true);
    expect(find.text('Correspondencia registrada'), findsOneWidget);
    expect(
      t
          .widget<OutlinedButton>(
            find.widgetWithText(
              OutlinedButton,
              'Registrar otra correspondencia',
            ),
          )
          .onPressed,
      isNull,
    );
    fallo = 0;
    await tocar(t, 'Subir foto');
    expect(registros, 1);
    expect(subidas, 2);
    expect(find.text('Foto guardada correctamente.'), findsOneWidget);
  });
  testWidgets(
    'respuesta perdida comprueba bytes sin reenviar documento ni foto',
    (t) async {
      fallo = 503;
      await abrir(t);
      await foto(t);
      await tocar(t, 'Registrar correspondencia');
      await tocar(t, 'Comprobar subida');
      expect(registros, 1);
      expect(subidas, 1);
      expect(find.text('Foto guardada correctamente.'), findsOneWidget);
    },
  );
  testWidgets('quitar foto permite registrar sin subir un archivo', (t) async {
    await abrir(t);
    await foto(t);
    await tocar(t, 'Quitar foto');
    expect(archivo.existsSync(), false);
    await tocar(t, 'Registrar correspondencia');
    expect(registros, 1);
    expect(subidas, 0);
    expect(camara.solicitudes, [true]);
    expect(find.text('Correspondencia registrada'), findsOneWidget);
  });
}
