import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/funciones/iniciar_sesion/sesion_controller.dart';
import 'package:t4_movil/funciones/notas_internas/detalle_nota_page.dart';
import 'package:t4_movil/funciones/notas_internas/notas_api.dart';

const _recuperar = bool.fromEnvironment('ENSAYO_RECUPERAR');
const _password = String.fromEnvironment('ENSAYO_PASSWORD');
const _cases = [
  (
    id: String.fromEnvironment('ENSAYO_VIAS'),
    email: String.fromEnvironment('ENSAYO_VIA1'),
    accion: AccionNota.conformidad,
  ),
  (
    id: String.fromEnvironment('ENSAYO_DIRECTO'),
    email: String.fromEnvironment('ENSAYO_RECEPTOR'),
    accion: AccionNota.primeraRecepcion,
  ),
];

class _SesionEnsayo implements AlmacenSesion {
  static const _storage = FlutterSecureStorage();
  static const _key = 'ensayo52.recuperacion.sesion';
  @override
  Future<String?> leer() => _storage.read(key: _key);
  @override
  Future<void> guardar(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> eliminar() => _storage.delete(key: _key);
}

// Se envía a Laravel/Camunda reales y se consume la respuesta antes de provocar
// una pérdida controlada en transporte. No simula resultados del servidor.
class _TransporteEnsayo extends http.BaseClient {
  final _client = http.Client();
  final posts = <Map<String, String>>[];
  bool perdida = false;
  int? estadoDescartado;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final action =
        request.method == 'POST' &&
        (request.url.path.endsWith('/conformidades') ||
            request.url.path.endsWith('/recepciones'));
    if (action) {
      posts.add({
        'clave': request.headers['Idempotency-Key'] ?? '',
        'cuerpo': request is http.Request ? request.body : '',
      });
    }
    final response = await _client.send(request);
    if (!_recuperar &&
        action &&
        !perdida &&
        {200, 202}.contains(response.statusCode)) {
      await response.stream.drain<void>();
      perdida = true;
      estadoDescartado = response.statusCode;
      throw http.ClientException(
        'Respuesta perdida de forma controlada',
        request.url,
      );
    }
    return response;
  }

  @override
  void close() => _client.close();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'recuperación real tras cierre del proceso: $_recuperar',
    (tester) async {
      final results = <String, Object?>{};
      Future<void> until(bool Function() condition, String reason) async {
        final end = DateTime.now().add(const Duration(seconds: 40));
        while (!condition() && DateTime.now().isBefore(end)) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(condition(), isTrue, reason: reason);
      }

      for (final item in _cases) {
        final transport = _TransporteEnsayo();
        final api = ApiLaravel(client: transport);
        final storage = _SesionEnsayo();
        await storage.eliminar();
        final session = SesionController(api: api, almacen: storage);
        try {
          await session.ingresar(item.email, _password);
          expect(session.autenticada, isTrue);
          final service = NotasApi(api);
          final previous = await service.pendientePara(item.id);
          expect(
            previous != null,
            _recuperar,
            reason: 'El intento debe sobrevivir al cierre real de la ejecución anterior',
          );
          await tester.pumpWidget(
            MaterialApp(
              home: DetalleNotaPage(api: api, id: item.id),
            ),
          );
          await until(
            () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
            'Detalle consultado con sesión nueva',
          );
          if (!_recuperar) {
            await until(
              () => find
                  .widgetWithText(FilledButton, item.accion.titulo)
                  .evaluate()
                  .isNotEmpty,
              'Acción autorizada',
            );
            await tester.tap(
              find.widgetWithText(FilledButton, item.accion.titulo),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
            await until(
              () => find.text('Comprobar mismo intento').evaluate().isNotEmpty,
              'La pérdida no se presenta como éxito',
            );
            expect(transport.perdida, isTrue);
            final pending = await service.pendientePara(item.id);
            expect(pending, isNotNull);
            expect(transport.posts.length, 1);
            results[item.accion.name] = {
              'note_id': item.id,
              'clave': pending!.clave,
              'version': pending.version,
              'estado_descartado': transport.estadoDescartado,
              'posts': transport.posts.length,
            };
          } else {
            for (var retry = 0; retry < 10; retry++) {
              await until(
                () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
                'Comprobación del intento anterior',
              );
              if (await service.pendientePara(item.id) == null) break;
              await tester.pump(const Duration(seconds: 1));
              await tester.tap(
                find.widgetWithText(FilledButton, 'Comprobar mismo intento'),
              );
              await tester.pump(const Duration(milliseconds: 500));
            }
            expect(await service.pendientePara(item.id), isNull);
            for (final post in transport.posts) {
              expect(post['clave'], previous!.clave);
              expect(post['cuerpo'], contains('"version":${previous.version}'));
            }
            final current = await service.detalle(item.id);
            if (item.accion == AccionNota.conformidad) {
              expect(
                current.estado,
                'pendiente_revision',
              ); // Segunda VÍA pendiente.
              final events = current.datos['movimientos_nota'] as List;
              expect(
                events.where((e) => e['accion'] == 'conformidad').length,
                1,
              );
            } else {
              expect(current.estado, 'recibida');
              expect(current.documentoId, isNotNull);
              final doc = await api.enviar('GET', 'hojas/${current.hojaId}');
              expect(
                (doc['movimientos'] as List)
                    .where((e) => e['action'] == 'RECEPCION')
                    .length,
                1,
              );
            }
            results[item.accion.name] = {
              'note_id': item.id,
              'clave': previous!.clave,
              'version': previous.version,
              'posts': transport.posts.length,
              'resultado': 'PASS',
              'sin_duplicados': true,
            };
          }
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          if (session.autenticada) await session.salir();
          session.dispose();
          api.close();
        }
      }
      binding.reportData = {
        'pid_android': pid,
        'recuperacion': _recuperar,
        'casos': results,
      };
    },
    skip: _password.isEmpty || _cases.any((e) => e.id.isEmpty),
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
