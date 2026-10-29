import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:t4_movil/main.dart';
import 'package:t4_movil/services/laravel_api.dart';
import 'package:t4_movil/services/consulta_envio_service.dart';
import 'package:t4_movil/services/sesion_controller.dart';

class _HttpReal extends HttpOverrides {}

class _ObservadorApi extends ApiLaravel {
  _ObservadorApi({required super.baseUrl, required super.client});
  Future<Map<String, dynamic>>? pendiente;
  @override
  Future<Map<String, dynamic>> enviar(
    String metodo,
    String ruta, {
    Map<String, dynamic>? datos,
    Map<String, String> cabeceras = const {},
    bool autenticado = true,
  }) => pendiente = super.enviar(
    metodo,
    ruta,
    datos: datos,
    cabeceras: cabeceras,
    autenticado: autenticado,
  );
}

class _Almacen implements AlmacenSesion {
  String? valor;
  @override
  Future<String?> leer() async => valor;
  @override
  Future<void> guardar(String s) async {
    valor = s;
  }

  @override
  Future<void> eliminar() async {
    valor = null;
  }
}

void main() {
  // Opt-in: requiere PHP, vendor/ y PostgreSQL de pruebas; nunca usa JSON ni datos simulados.
  final php = Platform.environment['LARAVEL_TEST_PHP'];
  testWidgets(
    'Laravel real: sesión, registro idempotente, consulta, bandeja y PostgreSQL',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1000));
      final email =
          'f${DateTime.now().microsecondsSinceEpoch}@flutter.example.test';
      final env = <String, String>{
        'APP_ENV': 'testing',
        'DB_CONNECTION': 'pgsql',
        'DB_DATABASE': 'correspondencia_test',
        'CACHE_STORE': 'array',
        'SESSION_DRIVER': 'array',
        'FLUTTER_TEST_EMAIL': email,
        'FLUTTER_TEST_PASSWORD': nuevaClaveSolicitud(),
      };
      Process? servidor;
      ApiLaravel? api;
      SesionController? sesion;
      Future<Map<String, dynamic>> fixture(String op) async {
        final r = await Process.run(php!, [
          'test/soporte/laravel_fixture.php',
          op,
        ], environment: env);
        if (r.exitCode != 0) {
          throw StateError('Fixture $op: ${r.stderr} ${r.stdout}');
        }
        return jsonDecode(r.stdout as String) as Map<String, dynamic>;
      }

      addTearDown(() async {
        await tester.runAsync(() async {
          api?.close();
          sesion?.dispose();
          if (servidor != null) {
            servidor!.kill();
            await servidor!.exitCode;
          }
          await fixture('limpiar');
        });
        await tester.binding.setSurfaceSize(null);
      });
      late String guia;
      late Map<String, dynamic> guardado;
      await tester.runAsync(() async {
        await fixture('crear');
        final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = socket.port;
        await socket.close();
        servidor = await Process.start(
          php!,
          ['-S', '127.0.0.1:$port', '-t', 'public'],
          workingDirectory: '../web',
          environment: env,
        );
        servidor!.stdout.drain<void>();
        servidor!.stderr.drain<void>();
        var listo = false;
        for (var i = 0; i < 100; i++) {
          try {
            final s = await Socket.connect('127.0.0.1', port);
            s.destroy();
            listo = true;
            break;
          } catch (_) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        }
        expect(listo, true, reason: 'El servidor PHP no inició.');
        api = _ObservadorApi(
          baseUrl: 'http://127.0.0.1:$port',
          client: IOClient(
            _HttpReal().createHttpClient(null)..idleTimeout = Duration.zero,
          ),
        );
        sesion = SesionController(api: api!, almacen: _Almacen());
        await sesion!.restaurar();
        await sesion!.ingresar(email, env['FLUTTER_TEST_PASSWORD']!);
        expect(sesion!.autenticada, true, reason: sesion!.mensaje);
        final config = await api!.enviar('GET', 'configuracion-registro');
        final datos = <String, dynamic>{
          'remitente': 'Dirección académica',
          'asunto': 'Consulta móvil contra Laravel',
          'fecha': '2026-10-24',
          'tipo_id': (config['tipos'] as List).first['id'],
          'prioridad_id': (config['prioridades'] as List).first['id'],
          'unidad_id': (config['unidades'] as List).single['id'],
        };
        final clave = nuevaClaveSolicitud();
        guardado = await api!.enviar(
          'POST',
          'documentos',
          datos: datos,
          cabeceras: {'Idempotency-Key': clave},
        );
        final repetido = await api!.enviar(
          'POST',
          'documentos',
          datos: datos,
          cabeceras: {'Idempotency-Key': clave},
        );
        expect(repetido['id'], guardado['id']);
        guia = guardado['guia'] as String;
        final bd = await fixture('verificar');
        expect(bd['documentos'], 1);
        expect(bd['movimientos'], 1);
        expect(bd['solicitudes'], 1);
        expect(bd['documento'], guardado);
        final consulta = await ConsultaEnvioApi(api: api!).consultar(guia);
        expect(consulta!.numeroGuia, guia);
        expect(consulta.estado, guardado['estado']);
        expect(
          consulta.fechaUltimoMovimiento,
          DateTime.parse(guardado['fechaUltimoMovimiento'] as String),
        );
        expect(
          await ConsultaEnvioApi(api: api!).consultar('COR-INEXISTENTE'),
          null,
        );
        final lista = await api!.enviar('GET', 'documentos');
        expect((lista['data'] as List).single['id'], guardado['id']);
        final detalle = await api!.enviar(
          'GET',
          'documentos/${guardado['id']}',
        );
        expect(detalle, guardado);
      });
      await tester.pumpWidget(CorrespondenciaApp(sesion: sesion));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Consultar envío'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), guia);
      await tester.runAsync(() async {
        await tester.tap(find.text('Consultar'));
        await (api as _ObservadorApi).pendiente;
      });
      await tester.pumpAndSettle();
      expect(find.text('REGISTRADA'), findsOneWidget);
      expect(find.text(guia), findsWidgets);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Mi bandeja'));
        await tester.pump();
        await (api as _ObservadorApi).pendiente;
      });
      await tester.pumpAndSettle();
      expect(find.text('Consulta móvil contra Laravel'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Consulta móvil contra Laravel'));
        await tester.pump();
        await (api as _ObservadorApi).pendiente;
      });
      await tester.pumpAndSettle();
      expect(find.text('Detalle de correspondencia'), findsOneWidget);
      expect(find.text(guia), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await sesion!.salir();
        expect(sesion!.autenticada, false);
        await expectLater(
          api!.enviar('GET', 'documentos'),
          throwsA(isA<ErrorLaravel>()),
        );
      });
    },
    skip: php == null,
  );
}
