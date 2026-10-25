import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:t4_movil/main.dart';
import 'package:t4_movil/models/envio_consulta.dart';
import 'package:t4_movil/services/consulta_envio_service.dart';

// Solo evita el HTTP simulado por el harness de widgets: usa sockets reales.
class _HttpReal extends HttpOverrides {}

class _Observador implements ConsultaEnvioService {
  _Observador(this.api);
  final ConsultaEnvioApi api;
  int llamadas = 0;
  Future<EnvioConsulta?>? pendiente;
  @override
  Future<EnvioConsulta?> consultar(String guia) {
    llamadas++;
    return pendiente = api.consultar(guia);
  }
}

void main() {
  testWidgets(
    'Flutter consulta Node real y muestra el registro persistido; inexistencia y servidor apagado',
    (tester) async {
      const capturar = bool.fromEnvironment('CAPTURAR_EVIDENCIA');
      await tester.binding.setSurfaceSize(const Size(390, 844));
      Directory? datos;
      Process? servidor;
      IOClient? cliente;
      late ConsultaEnvioApi api;
      late Map<String, dynamic> guardado;
      addTearDown(() async {
        await tester.runAsync(() async {
          cliente?.close();
          if (servidor != null) {
            servidor!.kill();
            await servidor!.exitCode;
          }
          if (datos != null && await datos!.exists()) {
            await datos!.delete(recursive: true);
          }
        });
        await tester.binding.setSurfaceSize(null);
      });

      await tester.runAsync(() async {
        datos = await Directory.systemTemp.createTemp('t4-flutter-real-');
        final listo = Completer<String>();
        servidor = await Process.start(
          'node',
          [File('../prototipo/node/server.js').absolute.path],
          environment: {'PORT': '0', 'DATA_DIR': datos!.path},
        );
        servidor!.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
              final match = RegExp(r'localhost:(\d+)').firstMatch(line);
              if (match != null && !listo.isCompleted) {
                listo.complete('http://127.0.0.1:${match[1]}');
              }
            });
        servidor!.stderr.transform(utf8.decoder).listen((line) {
          if (!listo.isCompleted) listo.completeError(StateError(line));
        });
        servidor!.exitCode.then((code) {
          if (!listo.isCompleted) {
            listo.completeError(StateError('Node terminó con $code'));
          }
        });
        final base = await listo.future.timeout(const Duration(seconds: 15));
        cliente = IOClient(_HttpReal().createHttpClient(null));
        final registro = await cliente!.post(
          Uri.parse('$base/api/correspondencia'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'remitente': 'Remitente de prueba aislada',
            'destinatario': 'Destinatario de prueba aislada',
            'fecha': '2026-10-15',
          }),
        );
        expect(registro.statusCode, 201);
        guardado =
            (jsonDecode(
                  await File('${datos!.path}/correspondencia.json')
                      .readAsString(),
                ) as List).single
                as Map<String, dynamic>;
        expect(jsonDecode(registro.body), guardado);
        api = ConsultaEnvioApi(baseUrl: base, client: cliente);
        final directo = await api.consultar(guardado['guia'] as String);
        expect(directo!.estado, guardado['estado']);
        expect(
          directo.fechaUltimoMovimiento,
          DateTime.parse(guardado['fechaUltimoMovimiento'] as String),
        );
      });

      if (capturar) {
        final font = FontLoader('Roboto');
        font.addFont(
          Future.value(
            ByteData.sublistView(
              File('C:/Windows/Fonts/segoeui.ttf').readAsBytesSync(),
            ),
          ),
        );
        await font.load();
        final icons = FontLoader('MaterialIcons');
        icons.addFont(
          Future.value(
            ByteData.sublistView(
              File('build/unit_test_assets/fonts/MaterialIcons-Regular.otf')
                  .readAsBytesSync(),
            ),
          ),
        );
        await icons.load();
      }
      final observador = _Observador(api);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: CorrespondenciaApp(servicio: observador),
        ),
      );
      await tester.tap(find.text('Consultar envío'));
      await tester.pumpAndSettle();

      Future<void> foto(String nombre) async {
        if (!capturar) return;
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        boundary.markNeedsPaint();
        await tester.pump();
        await tester.runAsync(() async {
          final imagen = await boundary.toImage(pixelRatio: 2);
          final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
          Directory('build/revision').createSync(recursive: true);
          File('build/revision/$nombre.png')
              .writeAsBytesSync(png!.buffer.asUint8List());
          imagen.dispose();
        });
      }

      // Campo vacío: ni siquiera se invoca el servicio.
      await tester.tap(find.text('Consultar'));
      await tester.pumpAndSettle();
      expect(find.text('Ingrese el número de guía.'), findsOneWidget);
      expect(observador.llamadas, 0);

      final guia = guardado['guia'] as String;
      await tester.enterText(find.byType(TextFormField), guia);
      await tester.runAsync(() async {
        await tester.tap(find.text('Consultar'));
        tester.widget<TextField>(find.byType(TextField)).onSubmitted!(guia);
        expect(observador.llamadas, 1);
        await observador.pendiente;
      });
      await tester.pumpAndSettle();
      expect(find.text(guia), findsNWidgets(2));
      expect(find.text(guardado['estado'] as String), findsOneWidget);
      final fecha = DateTime.parse(guardado['fechaUltimoMovimiento'] as String)
          .toLocal();
      final fechaPantalla =
          '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
      expect(find.text(fechaPantalla), findsOneWidget);
      await foto('consulta-real');

      await tester.enterText(find.byType(TextFormField), 'COR-9999-999999');
      await tester.runAsync(() async {
        await tester.tap(find.text('Consultar'));
        await observador.pendiente;
      });
      await tester.pumpAndSettle();
      expect(
        find.text('No se encontró un envío con ese número de guía.'),
        findsOneWidget,
      );
      expect(find.text('Resultado de la consulta'), findsNothing);
      await foto('guia-inexistente');

      await tester.runAsync(() async {
        servidor!.kill();
        await servidor!.exitCode;
        servidor = null;
      });
      await tester.enterText(find.byType(TextFormField), guia);
      await tester.runAsync(() async {
        await tester.tap(find.text('Consultar'));
        try {
          await observador.pendiente;
        } on ErrorConexion {
          /* Error esperado del socket real. */
        }
      });
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No se pudo conectar con el servidor.'),
        findsOneWidget,
      );
      expect(find.text('Resultado de la consulta'), findsNothing);
      await foto('servidor-apagado');
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        guia,
      );
      expect(tester.takeException(), isNull);
      if (capturar) {
        File('build/revision/evidencia-consulta-real.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            'tipo': 'Widgets Flutter + servicio de producción + HTTP real + Node + datos aislados',
            'registroPersistido': guardado,
            'fechaMostrada': fechaPantalla,
            'verificado': [
              'campo vacío sin solicitud',
              'guía válida',
              'estado y fecha del JSON',
              'doble consulta bloqueada',
              'guía inexistente 404',
              'servidor apagado',
            ],
            'androidFisico': false,
          }),
        );
      }
    },
  );
}
