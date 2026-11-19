import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:integration_test/integration_test.dart';
import 'package:t4_movil/compartido/api/api_config.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/funciones/iniciar_sesion/sesion_controller.dart';
import 'package:t4_movil/funciones/adjuntos/adjuntos_api.dart';
import 'package:t4_movil/funciones/camara/camara_documento.dart';
import 'package:t4_movil/main.dart';
import 'package:t4_movil/funciones/notas_internas/detalle_nota_page.dart';
import 'package:t4_movil/funciones/recorrido/recorrido_documento.dart';

// Opt-in: requiere cuentas y dos notas ficticias emitidas desde la web, un
// backend Laravel real y el BPMN desplegado en Camunda. No hay mocks ni seeds.
const _password = String.fromEnvironment('ENSAYO_PASSWORD');
const _directa = String.fromEnvironment('ENSAYO_DIRECTO');
const _vias = String.fromEnvironment('ENSAYO_VIAS');
const _citeDirecta = String.fromEnvironment('ENSAYO_CITE_DIRECTO');
const _citeVias = String.fromEnvironment('ENSAYO_CITE_VIAS');
const _terceraUnidad = int.fromEnvironment('ENSAYO_UNIDAD_TERCERA');
const _emails = {
  'via1': String.fromEnvironment('ENSAYO_VIA1'),
  'via2': String.fromEnvironment('ENSAYO_VIA2'),
  'receptor': String.fromEnvironment('ENSAYO_RECEPTOR'),
  'copia': String.fromEnvironment('ENSAYO_COPIA'),
  'tercero': String.fromEnvironment('ENSAYO_TERCERO'),
};

DateTime? _ultimoAcceso;
Future<void> _espaciarAccesos() async {
  final previous = _ultimoAcceso;
  if (previous != null) {
    final remaining =
        const Duration(seconds: 14) - DateTime.now().difference(previous);
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
  }
  _ultimoAcceso = DateTime.now();
}

// Usa el plugin real con una clave separada: no borra ni reemplaza la sesión
// habitual del propietario del teléfono durante el ensayo.
class _AlmacenEnsayo implements AlmacenSesion {
  static const _storage = FlutterSecureStorage();
  static const _key = 'ensayo52.sesion.laravel';
  @override
  Future<String?> leer() => _storage.read(key: _key);
  @override
  Future<void> guardar(String valor) => _storage.write(key: _key, value: valor);
  @override
  Future<void> eliminar() => _storage.delete(key: _key);
}

class _Web {
  final _client = HttpClient();
  final _cookies = <String, Cookie>{};

  Future<String> request(String path, [Map<String, String>? form]) async {
    var uri = Uri.parse('${ApiConfig.baseUrl}$path');
    for (var redirects = 0; redirects < 6; redirects++) {
      final r = await _client.openUrl(form == null ? 'GET' : 'POST', uri);
      r.followRedirects = false;
      r.cookies.addAll(_cookies.values);
      if (form != null) {
        r.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
          charset: 'utf-8',
        );
        r.write(Uri(queryParameters: form).query);
      }
      final response = await r.close();
      for (final cookie in response.cookies) {
        _cookies[cookie.name] = cookie;
      }
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode == 429) {
        // Se respeta el límite del servidor; el ensayo no lo desactiva.
        final seconds =
            int.tryParse(response.headers.value('retry-after') ?? '') ?? 60;
        await Future<void>.delayed(Duration(seconds: seconds + 1));
        continue;
      }
      if ({301, 302, 303}.contains(response.statusCode)) {
        uri = uri.resolve(response.headers.value('location')!);
        form = null;
        continue;
      }
      expect(response.statusCode, 200, reason: 'Ruta web $path');
      return body;
    }
    throw StateError('Demasiadas redirecciones web');
  }

  String csrf(String html) {
    final match =
        RegExp('name="csrf-token" content="([^"]+)"').firstMatch(html) ??
        RegExp('name="_token" value="([^"]+)"').firstMatch(html);
    if (match == null) throw StateError('Falta CSRF en formulario web');
    return match.group(1)!;
  }

  Future<void> login(String email) async {
    final page = await request('/acceso');
    await _espaciarAccesos();
    await request('/acceso', {
      '_token': csrf(page),
      'email': email,
      'password': _password,
    });
  }

  Future<void> comprobar(String id, String cite, String estado) async {
    final page = await request('/notas-internas/$id');
    expect(page, contains(cite));
    expect(page, contains('<dd>$estado</dd>'));
  }

  Future<void> hoja(
    Map<String, dynamic> note,
    Map<String, dynamic> doc,
    String action,
    Map<String, String> data,
  ) async {
    final page = await request('/documentos/${note['documento_id']}');
    await request('/hojas/${note['hoja_id']}/$action', {
      ...data,
      '_token': csrf(page),
      'version': '${(doc['hoja'] as Map)['version']}',
      'request_key': nuevaClaveSolicitud(),
    });
  }

  void close() => _client.close(force: true);

  Future<Uint8List> descargar(String path) async {
    final r = await _client.getUrl(Uri.parse('${ApiConfig.baseUrl}$path'));
    r.cookies.addAll(_cookies.values);
    final response = await r.close();
    expect(response.statusCode, 200);
    final bytes = BytesBuilder();
    await for (final part in response) {
      bytes.add(part);
    }
    return bytes.takeBytes();
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android real + Laravel + Camunda: directo y dos VIAS',
    (tester) async {
      final evidence = <String, Object?>{};
      ApiLaravel? api;
      SesionController? sesion;
      var converted = false;

      Future<void> until(bool Function() condition, String message) async {
        final deadline = DateTime.now().add(const Duration(seconds: 45));
        while (!condition() && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        if (!condition()) {
          for (final element in find.byType(DetalleNotaPage).evaluate()) {
            if (element is StatefulElement) {
              debugPrint(element.state.toDiagnosticsNode().toStringDeep());
            }
          }
          for (final element in find.byType(RecorridoDocumento).evaluate()) {
            if (element is StatefulElement) {
              debugPrint(element.state.toDiagnosticsNode().toStringDeep());
            }
          }
        }
        expect(condition(), isTrue, reason: message);
      }

      Future<void> tap(Finder target) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        if (target.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            target,
            260,
            scrollable: find
                .byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                )
                .last,
            maxScrolls: 30,
          );
        }
        await tester.ensureVisible(target.first);
        await tester.pumpAndSettle();
        await tester.tap(target.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<void> screenshot(String name) async {
        if (name.contains('cerrada')) {
          await tester.pump(const Duration(seconds: 7));
        }
        if (!converted) {
          await binding.convertFlutterSurfaceToImage();
          converted = true;
        }
        await tester.pumpAndSettle();
        await binding.takeScreenshot(name);
      }

      Future<void> login(String role) async {
        if (sesion != null) {
          await sesion!.salir();
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          sesion!.dispose();
          api!.close();
        }
        api = ApiLaravel();
        final almacen = _AlmacenEnsayo();
        await almacen.eliminar();
        sesion = SesionController(api: api!, almacen: almacen);
        await tester.pumpWidget(CorrespondenciaApp(sesion: sesion));
        await until(
          () => find.byType(TextFormField).evaluate().length == 2,
          'Pantalla real de inicio de sesión',
        );
        for (var attempt = 0; attempt < 3; attempt++) {
          await _espaciarAccesos();
          await tester.enterText(
            find.byType(TextFormField).at(0),
            _emails[role]!,
          );
          await tester.enterText(find.byType(TextFormField).at(1), _password);
          await tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
          await until(() => !sesion!.ocupada, 'Respuesta del inicio de sesión');
          debugPrint(
            'ENSAYO acceso $role: ${sesion!.autenticada ? 'OK' : sesion!.mensaje}',
          );
          if (sesion!.autenticada) break;
          if (!(sesion!.mensaje ?? '').startsWith('Demasiados intentos')) break;
          for (var wait = 0; wait < 7; wait++) {
            await tester.pump(const Duration(seconds: 9));
          }
        }
        expect(
          sesion!.autenticada,
          isTrue,
          reason: 'Inicio de sesión de $role: ${sesion!.mensaje}',
        );
        await until(
          () => find.byType(NavigationBar).evaluate().isNotEmpty,
          'Navegación autenticada',
        );
        await tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Bandeja'),
          ),
        );
        await until(
          () => find
              .byKey(const ValueKey('abrir-notas-internas'))
              .evaluate()
              .isNotEmpty,
          'Acceso a Notas internas',
        );
        await tap(find.byKey(const ValueKey('abrir-notas-internas')));
        await until(
          () => find.text('Bandeja de notas').evaluate().isNotEmpty,
          'Bandeja de notas',
        );
        await until(
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
          'Carga de la bandeja',
        );
      }

      Future<void> tray(String label) async {
        await tap(find.widgetWithText(Tab, label));
        await until(
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
          'Carga de $label',
        );
      }

      Future<void> open(String id, String cite) async {
        await until(
          () => find.byKey(ValueKey(id)).evaluate().isNotEmpty,
          'La nota está en la bandeja correcta',
        );
        await tap(find.byKey(ValueKey(id)));
        await until(
          () => find.text(cite).evaluate().isNotEmpty,
          'Detalle real con el mismo CITE',
        );
        await until(
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
          'Detalle actualizado',
        );
      }

      Future<void> action(String title, String message) async {
        await tap(find.widgetWithText(FilledButton, title));
        await until(
          () => find.text('Confirmar').evaluate().isNotEmpty,
          'Confirmación explícita de $title',
        );
        await tap(find.widgetWithText(FilledButton, 'Confirmar'));
        // La indexación real del motor puede devolver 202. Se usa el botón
        // público de reintento, que conserva la clave y la versión originales.
        for (var retry = 0; retry < 8; retry++) {
          await until(
            () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
            'Respuesta del motor',
          );
          if (find.text(message).evaluate().isNotEmpty) break;
          final pending = find.widgetWithText(
            FilledButton,
            'Comprobar mismo intento',
          );
          if (pending.evaluate().isEmpty) break;
          await tester.pump(const Duration(seconds: 2));
          await tap(pending);
        }
        await until(
          () => find.text(message).evaluate().isNotEmpty,
          'Confirmación de Laravel/Camunda para $title',
        );
        await until(
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
          'Refresco posterior a $title',
        );
      }

      Future<Map<String, dynamic>> note(String id) =>
          api!.enviar('GET', 'notas-internas/$id');

      Future<void> attend(String id) async {
        await tap(find.widgetWithText(OutlinedButton, 'Registrar atención'));
        await until(
          () => find.byType(TextFormField).evaluate().isNotEmpty,
          'Formulario de atención',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'Inspección ficticia verificada desde Android con Camunda real.',
        );
        await tap(find.widgetWithText(FilledButton, 'Guardar atención'));
        await until(
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
          'Refresco automático después de guardar atención',
        );
        final updated = await note(id);
        expect(updated['estado'], 'en_atencion');
        await tester.scrollUntilVisible(
          find.text(updated['cite'] as String),
          -260,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .last,
          maxScrolls: 30,
        );
        await tester.pumpAndSettle();
        await until(
          () => find.text('En atención').evaluate().isNotEmpty,
          'Atención confirmada por el servidor',
        );
        expect((await note(id))['estado'], 'en_atencion');
      }

      Future<void> receiveAndAttend(String id, String cite, String name) async {
        await tray('Por recibir');
        await open(id, cite);
        await action('Confirmar recepción', 'Recepción confirmada.');
        final received = await note(id);
        expect(received['estado'], 'recibida');
        expect(received['documento_id'], isNotNull);
        expect(received['hoja_id'], isNotNull);
        evidence[name] = {
          'note_id': id,
          'cite': cite,
          'documento_id': received['documento_id'],
          'hoja_id': received['hoja_id'],
        };
        var web = _Web();
        try {
          await web.login(_emails['receptor']!);
          await web.comprobar(id, cite, 'Recibida');
          await attend(id);
          await web.comprobar(id, cite, 'En atención');
          await screenshot('${name}_atencion_android');
          var current = await note(id);
          var document = await api!.enviar(
            'GET',
            'hojas/${current['hoja_id']}',
          );
          if (name == 'dos_vias') {
            await web.hoja(current, document, 'derivaciones', {
              'destino_unidad_id': '$_terceraUnidad',
              'motivo':
                  'Derivación ficticia a Secretaría para completar el ensayo.',
            });
            await web.comprobar(id, cite, 'Pendiente de recepción');
            final derived = await note(id);
            expect(derived['hoja_id'], received['hoja_id']);
            final pendingSheet = await api!.enviar(
              'GET',
              'hojas/${current['hoja_id']}',
            );
            expect(
              (pendingSheet['hoja'] as Map)['responsable_id'],
              (document['hoja'] as Map)['responsable_id'],
            );
            await login('tercero');
            await tray('Por recibir');
            await open(id, cite);
            await tap(
              find.widgetWithText(OutlinedButton, 'Confirmar recepción'),
            );
            await tap(find.widgetWithText(FilledButton, 'Confirmar recepción'));
            await until(
              () => find.text('¿Confirmar recepción?').evaluate().isNotEmpty,
              'Confirmación de recepción de derivación',
            );
            await tap(
              find.widgetWithText(FilledButton, 'Confirmar recepción').last,
            );
            await until(
              () => find.text('Recibida').evaluate().isNotEmpty,
              'Recepción de la derivación confirmada',
            );
            await attend(id);
            web.close();
            web = _Web();
            await web.login(_emails['tercero']!);
            await web.comprobar(id, cite, 'En atención');
            current = await note(id);
            document = await api!.enviar('GET', 'hojas/${current['hoja_id']}');
            expect(current['hoja_id'], received['hoja_id']);
            expect(
              (document['hoja'] as Map)['responsable_id'],
              int.parse(api!.cuentaId!),
            );

            // Imagen íntegramente ficticia; no fotografía datos del propietario.
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder)
              ..drawColor(Colors.white, BlendMode.src);
            final text = TextPainter(
              text: const TextSpan(
                text: 'ENSAYO FICTICIO\nNOTA INTERNA PR52\nNo es un documento real',
                style: TextStyle(color: Colors.black, fontSize: 30),
              ),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: 600);
            text.paint(canvas, const Offset(20, 50));
            final image = await recorder.endRecording().toImage(640, 300);
            final pixels = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List();
            image.dispose();
            final attachment = await AdjuntosApi(api!).subir(
              current['documento_id'] as String,
              FotoDocumento('ensayo-ficticio.png', bytes: pixels),
              'ensayo-ficticio-pr52.png',
            );
            expect(
              (await AdjuntosApi(api!).descargar(attachment)).bytes,
              orderedEquals(pixels),
            );
            expect(
              await web.descargar(
                '/documentos/${current['documento_id']}/adjuntos/${attachment.id}/ver',
              ),
              orderedEquals(pixels),
            );
            final page = await web.request(
              '/documentos/${current['documento_id']}',
            );
            await web.request(
              '/documentos/${current['documento_id']}/respuestas',
              {
                '_token': web.csrf(page),
                'version': '${(document['hoja'] as Map)['version']}',
                'request_key': nuevaClaveSolicitud(),
                'remitente': 'Secretaría ficticia',
                'asunto': 'Respuesta ficticia al ensayo conjunto',
                'fecha': DateTime.now().toIso8601String().substring(0, 10),
                'tipo_id': '${(document['tipo'] as Map)['id']}',
                'prioridad_id': '${(document['prioridad'] as Map)['id']}',
              },
            );
            document = await api!.enviar('GET', 'hojas/${current['hoja_id']}');
            expect((document['respuestas'] as List).length, 1);
            await tap(
              find.widgetWithText(OutlinedButton, 'Ver expediente y adjuntos'),
            );
            await until(
              () =>
                  find
                      .text('Detalle de correspondencia')
                      .evaluate()
                      .isNotEmpty &&
                  find.byType(CircularProgressIndicator).evaluate().isEmpty,
              'Expediente y adjuntos descargados antes de abrir la imagen',
            );
            await tap(find.text('ensayo-ficticio-pr52.png'));
            await until(
              () => find.byType(Image).evaluate().isNotEmpty,
              'Imagen real descargada y abierta en Android',
            );
            await screenshot('imagen_ficticia_android');
            await tap(find.byType(BackButton));
            await tester.pumpAndSettle();
            await tap(find.byType(BackButton));
            await tester.pumpAndSettle();
            final qr = await web.descargar(
              '/hojas/${current['hoja_id']}/qr.svg',
            );
            expect(utf8.decode(qr), contains('<svg'));
            expect((evidence[name] as Map)['hoja_id'], current['hoja_id']);
            (evidence[name] as Map)['derivacion_respuesta_adjuntos_qr'] =
                'PASS';
            (evidence[name] as Map)['adjunto_id'] = attachment.id;
            (evidence[name] as Map)['respuesta_id'] =
                (document['respuestas'] as List).single['id'];
          }
          await web.hoja(current, document, 'cierre', {
            'motivo': 'Ensayo ficticio completo verificado en web y Android.',
            'confirmar': '1',
          });
          await web.comprobar(id, cite, 'Cerrada');
          await tap(find.byTooltip('Actualizar nota'));
          await tester.scrollUntilVisible(
            find.text(cite),
            -260,
            scrollable: find
                .byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                )
                .last,
            maxScrolls: 30,
          );
          await until(
            () => find.text('Cerrada').evaluate().isNotEmpty,
            'Cierre web reflejado en Android',
          );
          await screenshot('${name}_cerrada_android');
          expect((await note(id))['hoja_id'], received['hoja_id']);
          expect((await note(id))['documento_id'], received['documento_id']);
        } finally {
          web.close();
        }
      }

      try {
        await login('via2');
        expect(
          find.byKey(const ValueKey(_vias)),
          findsNothing,
          reason: 'La segunda VÍA no puede actuar antes que la primera',
        );
        await login('receptor');
        await tray('Por recibir');
        expect(
          find.byKey(const ValueKey(_vias)),
          findsNothing,
          reason: 'No se recibe antes de las conformidades',
        );
        await receiveAndAttend(_directa, _citeDirecta, 'directa');

        await login('via1');
        await open(_vias, _citeVias);
        await action('Dar conformidad', 'Conformidad registrada.');
        expect((await note(_vias))['estado'], 'pendiente_revision');
        expect(
          find.widgetWithText(FilledButton, 'Dar conformidad'),
          findsNothing,
        );
        await screenshot('primera_via_confirmada_android');

        await login('via2');
        await open(_vias, _citeVias);
        await action('Dar conformidad', 'Conformidad registrada.');
        expect((await note(_vias))['estado'], 'pendiente_recepcion');
        await screenshot('segunda_via_confirmada_android');

        await login('receptor');
        await receiveAndAttend(_vias, _citeVias, 'dos_vias');

        await login('copia');
        await tray('Copias');
        await open(_vias, _citeVias);
        await tester.scrollUntilVisible(
          find.text('Copia para conocimiento.'),
          260,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .last,
          maxScrolls: 30,
        );
        expect(find.text('Copia para conocimiento.'), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, 'Dar conformidad'),
          findsNothing,
        );
        expect(
          find.widgetWithText(FilledButton, 'Confirmar recepción'),
          findsNothing,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Registrar atención'),
          findsNothing,
        );
        expect((await note(_vias))['estado'], 'cerrada');
        await screenshot('copia_solo_lectura_android');
        binding.reportData ??= {};
        binding.reportData!['ensayo_real'] = evidence;
      } finally {
        if (sesion != null) await sesion!.salir();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        sesion?.dispose();
        api?.close();
      }
    },
    skip: _password.isEmpty || _directa.isEmpty || _vias.isEmpty,
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
