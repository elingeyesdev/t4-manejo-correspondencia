import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/funciones/recorrido/recorrido_api.dart';
import 'package:t4_movil/funciones/adjuntos/adjuntos_api.dart';
import 'package:t4_movil/funciones/camara/camara_documento.dart';

class _Real extends HttpOverrides {}

class _PerderRecepcion extends http.BaseClient {
  final http.Client cliente = IOClient(HttpClient());
  bool perdida = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final respuesta = await cliente.send(request);
    if (!perdida &&
        request.method == 'POST' &&
        request.url.path.endsWith('/recepciones')) {
      perdida = true;
      await respuesta.stream.drain<void>();
      throw http.ClientException(
        'Respuesta perdida después de guardar',
        request.url,
      );
    }
    return respuesta;
  }

  @override
  void close() => cliente.close();
}

void main() {
  final php = Platform.environment['LARAVEL_TEST_PHP'];
  final root = Platform.environment['LARAVEL_ADJUNTOS_BACKEND'];
  test(
    'Flutter y Laravel real: derivación, QR, recepción incierta, atención y foto',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final carpeta = await Directory.systemTemp.createTemp(
          'recorrido-real-',
        );
        final env = {
          'APP_ENV': 'testing',
          'DB_CONNECTION': 'pgsql',
          'DB_HOST': Platform.environment['DB_HOST'] ?? '127.0.0.1',
          'DB_PORT': Platform.environment['DB_PORT'] ?? '50928',
          'DB_DATABASE': 'correspondencia_test',
          'DB_USERNAME':
              Platform.environment['DB_USERNAME'] ?? 'correspondencia_local',
          'DB_PASSWORD': Platform.environment['DB_PASSWORD'] ?? '',
          'DB_URL': '',
          'CACHE_STORE': 'array',
          'SESSION_DRIVER': 'array',
          'LARAVEL_ADJUNTOS_BACKEND': root!,
          'RECORRIDO_FIXTURE_STATE': '${carpeta.path}/estado.json',
          'LARAVEL_STORAGE_PATH': '${carpeta.path}/storage',
          'ATTACHMENTS_KEY_V1':
              'base64:${base64Encode(List.generate(32, (_) => Random.secure().nextInt(256)))}',
        };
        Future<Map<String, dynamic>> fixture(String op) async {
          final result = await Process.run(php!, [
            File('test/soporte/recorrido_fixture.php').absolute.path,
            op,
          ], environment: env);
          if (result.exitCode != 0) {
            throw StateError('Fixture $op: ${result.stderr}');
          }
          return jsonDecode(result.stdout as String) as Map<String, dynamic>;
        }

        Process? servidor;
        final clientes = <ApiLaravel>[];
        try {
          final f = await fixture('crear');
          final socket = await ServerSocket.bind(
            InternetAddress.loopbackIPv4,
            0,
          );
          final port = socket.port;
          await socket.close();
          final base = 'http://127.0.0.1:$port';
          servidor = await Process.start(
            php!,
            [
              '-S',
              '127.0.0.1:$port',
              '-t',
              '.',
              '$root/vendor/laravel/framework/src/Illuminate/Foundation/resources/server.php',
            ],
            workingDirectory: '$root/public',
            environment: env,
          );
          servidor.stdout.drain<void>();
          servidor.stderr.drain<void>();
          var listo = false;
          for (var i = 0; i < 80; i++) {
            try {
              final s = await Socket.connect('127.0.0.1', port);
              s.destroy();
              listo = true;
              break;
            } catch (_) {
              await Future<void>.delayed(const Duration(milliseconds: 100));
            }
          }
          expect(listo, isTrue);
          ApiLaravel cliente(String cuenta, {http.Client? transporte}) {
            final api = ApiLaravel(
              baseUrl: base,
              client: transporte ?? IOClient(HttpClient()),
            )..token = (f['tokens'] as Map)[cuenta] as String;
            clientes.add(api);
            return api;
          }

          final origen = cliente('origen');
          final destino = cliente('destino', transporte: _PerderRecepcion());
          final ajena = cliente('ajena');
          final documento = f['documento'] as String;
          final hoja = f['hoja'] as String;
          final destinos = await RecorridoApi(origen).destinos(hoja);
          expect(destinos.any((d) => d.id == f['unidades']['destino']), isTrue);
          final derivacion = SolicitudRecorrido(
            hoja: hoja,
            documento: documento,
            operacion: OperacionRecorrido.derivar,
            token: origen.token,
            datos: {
              'version': 1,
              'motivo': 'Revisar solicitud',
              'destino_unidad_id': f['unidades']['destino'],
            },
          );
          final derivada = await RecorridoApi(origen).enviar(derivacion);
          expect(derivada, await RecorridoApi(origen).enviar(derivacion));
          expect(derivada['hoja']['responsable_id'], f['usuarios']['origen']);
          final qr = referenciaQr('$base/hojas/$hoja', base);
          final consulta = await destino.enviar('GET', 'hojas/$qr');
          expect(consulta['estado'], 'PENDIENTE_RECEPCION');
          expect((await fixture('verificar'))['movimientos'], [
            'REGISTRO',
            'DERIVACION',
          ]);
          await expectLater(
            ajena.enviar('GET', 'hojas/$hoja'),
            throwsA(isA<ErrorLaravel>().having((e) => e.estado, 'estado', 404)),
          );
          final recepcion = SolicitudRecorrido(
            hoja: hoja,
            documento: documento,
            operacion: OperacionRecorrido.recibir,
            token: destino.token,
            datos: {'version': 2},
          );
          await expectLater(
            RecorridoApi(destino).enviar(recepcion),
            throwsA(isA<ErrorLaravel>()),
          );
          final recibida = await RecorridoApi(destino).enviar(recepcion);
          expect(recibida['hoja']['version'], 3);
          expect(recibida['hoja']['responsable_id'], f['usuarios']['destino']);
          final atencion = SolicitudRecorrido(
            hoja: hoja,
            documento: documento,
            operacion: OperacionRecorrido.atender,
            token: destino.token,
            datos: {
              'version': 3,
              'observacion': 'Solicitud revisada desde Flutter',
            },
          );
          final atendida = await RecorridoApi(destino).enviar(atencion);
          expect(atendida, await RecorridoApi(destino).enviar(atencion));
          final foto = FotoDocumento(
            '${carpeta.path}/foto.jpg',
            bytes: await File('$root/tests/Fixtures/adjunto.jpg').readAsBytes(),
          );
          final adjuntos = AdjuntosApi(destino);
          final adjunto = await adjuntos.subir(
            documento,
            foto,
            'foto-recorrido.jpg',
          );
          expect(
            (await adjuntos.comprobar(
              documento,
              foto,
              'foto-recorrido.jpg',
            ))?.id,
            adjunto.id,
          );
          expect((await adjuntos.descargar(adjunto)).bytes, foto.bytes);
          final historial = await origen.enviar(
            'GET',
            'documentos/$documento/historial',
          );
          expect(historial['total'], 4);
          expect(
            historial['data'][3]['motivo'],
            'Solicitud revisada desde Flutter',
          );
          final guardado = await fixture('verificar');
          expect(guardado['estado'], 'EN_ATENCION');
          expect(guardado['version'], 4);
          expect(guardado['movimientos'], [
            'REGISTRO',
            'DERIVACION',
            'RECEPCION',
            'ATENCION',
          ]);
          expect(guardado['adjuntos'], 1);
        } finally {
          for (final cliente in clientes) {
            cliente.close();
          }
          servidor?.kill();
          if (servidor != null) await servidor.exitCode;
          await fixture('limpiar');
          if (await carpeta.exists()) await carpeta.delete(recursive: true);
        }
      }, _Real());
    },
    skip: php == null || root == null
        ? 'Requiere PHP y Laravel local; solo correspondencia_test.'
        : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
