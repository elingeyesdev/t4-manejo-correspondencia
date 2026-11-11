import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:t4_movil/funciones/adjuntos/adjuntos_api.dart';
import 'package:t4_movil/funciones/camara/camara_documento.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';

class _HttpReal extends HttpOverrides {}

void main() {
  final php = Platform.environment['LARAVEL_TEST_PHP'];
  final root = Platform.environment['LARAVEL_ADJUNTOS_BACKEND'];
  test(
    'Flutter → Laravel real → PostgreSQL: subir JPEG, listar, comparar descarga y permisos',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final carpeta = await Directory.systemTemp.createTemp(
          'flutter-adjuntos-real-',
        );
        final env = <String, String>{
          'APP_ENV': 'testing',
          'DB_CONNECTION': 'pgsql',
          'DB_HOST': '127.0.0.1',
          'DB_PORT': '50928',
          'DB_DATABASE': 'correspondencia_test',
          'DB_USERNAME': 'correspondencia_local',
          'DB_PASSWORD': '',
          'DB_URL': '',
          'CACHE_STORE': 'array',
          'SESSION_DRIVER': 'array',
          'LARAVEL_ADJUNTOS_BACKEND': root!,
          'ADJUNTOS_FIXTURE_STATE': '${carpeta.path}/estado.json',
          'LARAVEL_STORAGE_PATH': '${carpeta.path}/storage',
          'ATTACHMENTS_KEY_V1':
              'base64:${base64Encode(List<int>.generate(32, (_) => Random.secure().nextInt(256)))}',
        };
        final fixture = File('test/soporte/adjuntos_fixture.php').absolute.path;
        Future<Map<String, dynamic>> ejecutar(String op) async {
          final p = await Process.run(php!, [fixture, op], environment: env);
          if (p.exitCode != 0) {
            throw StateError('Fixture $op: ${p.stderr} ${p.stdout}');
          }
          return jsonDecode(p.stdout as String) as Map<String, dynamic>;
        }

        Process? servidor;
        ApiLaravel? api, lector;
        try {
          final f = await ejecutar('crear');
          final sock = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
          final port = sock.port;
          await sock.close();
          servidor = await Process.start(
            php!,
            [
              '-d',
              'upload_max_filesize=10M',
              '-d',
              'post_max_size=12M',
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
          api = ApiLaravel(
            baseUrl: 'http://127.0.0.1:$port',
            client: IOClient(HttpClient()),
          )..token = (f['tokens'] as Map)['recepcion'] as String;
          final servicio = AdjuntosApi(api);
          final bytes = await File('$root/tests/Fixtures/adjunto.jpg')
              .readAsBytes();
          final foto = FotoDocumento('${carpeta.path}/foto.jpg', bytes: bytes);
          final nombre = 'foto-${nuevaClaveSolicitud()}.jpg';
          final id = f['documento'] as String;
          expect((await servicio.listar(id)).archivos, isEmpty);
          final guardado = await servicio.subir(id, foto, nombre);
          expect(guardado.documentoId, id);
          expect(guardado.nombre, nombre);
          final lista = await servicio.listar(id);
          expect(lista.archivos.single.id, guardado.id);
          expect((await servicio.descargar(guardado)).bytes, bytes);
          expect((await servicio.comprobar(id, foto, nombre))?.id, guardado.id);
          final persistencia = await ejecutar('verificar');
          expect(persistencia, {
            'cantidad': 1,
            'cifrado': true,
            'contenido_identico': true,
          });
          lector = ApiLaravel(
            baseUrl: api.baseUrl,
            client: IOClient(HttpClient()),
          )..token = (f['tokens'] as Map)['funcionario'] as String;
          expect((await AdjuntosApi(lector).descargar(guardado)).bytes, bytes);
          await expectLater(
            AdjuntosApi(lector).subir(id, foto, nombre),
            throwsA(isA<ErrorLaravel>().having((e) => e.estado, 'estado', 403)),
          );
          expect((await servicio.listar(id)).archivos.length, 1);
        } finally {
          api?.close();
          lector?.close();
          servidor?.kill();
          if (servidor != null) await servidor.exitCode;
          await ejecutar('limpiar');
          if (await carpeta.exists()) await carpeta.delete(recursive: true);
        }
      }, _HttpReal());
    },
    skip: php == null || root == null
        ? 'Requiere PHP y LARAVEL_ADJUNTOS_BACKEND con el PR #23; usa solo correspondencia_test.'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
