// Opt-in: cuentas ficticias, teléfono físico y Laravel/Camunda reales.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:t4_movil/compartido/api/api_config.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/funciones/iniciar_sesion/sesion_controller.dart';
import 'package:t4_movil/main.dart';

const _password = String.fromEnvironment('FIRMA22_PASSWORD');
const _nota = String.fromEnvironment('FIRMA22_NOTA');
const _destino = int.fromEnvironment('FIRMA22_DESTINO');
const _via1 = int.fromEnvironment('FIRMA22_VIA1_ID');
const _via2 = int.fromEnvironment('FIRMA22_VIA2_ID');
const _emails = {
  'autor': String.fromEnvironment('FIRMA22_AUTOR'),
  'via1': String.fromEnvironment('FIRMA22_VIA1'),
  'via2': String.fromEnvironment('FIRMA22_VIA2'),
  'receptor': String.fromEnvironment('FIRMA22_RECEPTOR'),
};

class _AlmacenFirmaEnsayo implements AlmacenSesion {
  static const _seguro = FlutterSecureStorage();
  static const _clave = 'ensayo.firma61-62.sesion';
  @override
  Future<String?> leer() => _seguro.read(key: _clave);
  @override
  Future<void> guardar(String valor) =>
      _seguro.write(key: _clave, value: valor);
  @override
  Future<void> eliminar() => _seguro.delete(key: _clave);
}

class _WebFirma {
  final _cliente = HttpClient();
  final _cookies = <String, Cookie>{};

  Future<String> pedir(String ruta, [Map<String, String>? datos]) async {
    var uri = Uri.parse('${ApiConfig.baseUrl}$ruta');
    for (var n = 0; n < 6; n++) {
      final request = await _cliente.openUrl(
        datos == null ? 'GET' : 'POST',
        uri,
      );
      request.followRedirects = false;
      request.cookies.addAll(_cookies.values);
      if (datos != null) {
        request.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
          charset: 'utf-8',
        );
        request.write(Uri(queryParameters: datos).query);
      }
      final response = await request.close();
      for (final c in response.cookies) {
        _cookies[c.name] = c;
      }
      final html = await utf8.decoder.bind(response).join();
      if ({301, 302, 303}.contains(response.statusCode)) {
        uri = uri.resolve(response.headers.value('location')!);
        datos = null;
        continue;
      }
      expect(response.statusCode, 200, reason: 'Formulario web $ruta');
      return html;
    }
    throw StateError('Demasiadas redirecciones');
  }

  String csrf(String html) {
    final m =
        RegExp('name="_token" value="([^"]+)"').firstMatch(html) ??
        RegExp('name="csrf-token" content="([^"]+)"').firstMatch(html);
    if (m == null) throw StateError('Falta CSRF');
    return m.group(1)!;
  }

  Future<void> entrar() async {
    final html = await pedir('/acceso');
    final destino = await pedir('/acceso', {
      '_token': csrf(html),
      'email': _emails['autor']!,
      'password': _password,
    });
    expect(destino, contains('Correspondencia institucional'));
  }

  Future<String> accion(String accion, Map<String, String> datos) async {
    final html = await pedir('/notas-internas/$_nota');
    return pedir('/notas-internas/$_nota/$accion', {
      '_token': csrf(html),
      ...datos,
    });
  }

  void close() => _cliente.close(force: true);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android real firma, edición y dos VÍAs en orden con Camunda',
    (tester) async {
      ApiLaravel? api;
      SesionController? sesion;
      final web = _WebFirma();
      final evidencia = <String, Object?>{
        'nota': _nota,
        'conexion': 'WiFi',
        'autoridades': [_via1, _via2],
      };
      var capturaPreparada = false;

      Future<void> esperar(bool Function() condicion, String razon) async {
        final hasta = DateTime.now().add(const Duration(seconds: 50));
        while (!condicion() && DateTime.now().isBefore(hasta)) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(condicion(), isTrue, reason: razon);
      }

      Future<void> pulsar(Finder target) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        if (target.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            target,
            200,
            scrollable: find
                .byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                )
                .last,
          );
        }
        await tester.ensureVisible(target.first);
        await tester.pumpAndSettle();
        await tester.tap(target.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<void> captura(String nombre) async {
        if (!capturaPreparada) {
          await binding.convertFlutterSurfaceToImage();
          capturaPreparada = true;
        }
        await tester.pumpAndSettle();
        await binding.takeScreenshot(nombre);
      }

      Future<void> entrar(String rol) async {
        if (sesion != null) {
          await sesion!.salir();
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          sesion!.dispose();
          api!.close();
        }
        final almacen = _AlmacenFirmaEnsayo();
        await almacen.eliminar();
        api = ApiLaravel();
        sesion = SesionController(api: api!, almacen: almacen);
        await tester.pumpWidget(CorrespondenciaApp(sesion: sesion));
        await esperar(
          () => find.byType(TextFormField).evaluate().length == 2,
          'Acceso de $rol',
        );
        await tester.enterText(find.byType(TextFormField).at(0), _emails[rol]!);
        await tester.enterText(find.byType(TextFormField).at(1), _password);
        await pulsar(find.widgetWithText(FilledButton, 'Iniciar sesión'));
        await esperar(() => !sesion!.ocupada, 'Respuesta del acceso de $rol');
        expect(sesion!.autenticada, isTrue, reason: sesion!.mensaje);
        expect(sesion!.usuario?['email'], _emails[rol]);
        await pulsar(find.text('Notas internas'));
        await esperar(
          () => find.text('Bandeja de notas').evaluate().isNotEmpty,
          'Bandeja de notas',
        );
        await esperar(
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
          'Carga de bandeja',
        );
      }

      Future<void> bandeja(String titulo) async {
        await pulsar(find.widgetWithText(Tab, titulo));
        await esperar(
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
          'Carga de $titulo',
        );
      }

      Future<void> abrir() async {
        await esperar(
          () => find.byKey(const ValueKey(_nota)).evaluate().isNotEmpty,
          'Nota autorizada en bandeja',
        );
        await pulsar(find.byKey(const ValueKey(_nota)));
        await esperar(
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
          'Detalle de nota',
        );
      }

      Future<Map<String, dynamic>> nota() =>
          api!.enviar('GET', 'notas-internas/$_nota');

      Future<void> firmar(String titulo, String mensaje) async {
        await pulsar(find.widgetWithText(FilledButton, titulo));
        final area = find.byKey(const ValueKey('area-firma'));
        await esperar(() => area.evaluate().isNotEmpty, 'Captura de firma');
        await tester.ensureVisible(area);
        await tester.pumpAndSettle();
        final inicio = tester.getCenter(area) - const Offset(30, 35);
        final gesto = await tester.startGesture(inicio);
        for (var n = 0; n < 8; n++) {
          await gesto.moveBy(const Offset(0, 6));
          await tester.pump(const Duration(milliseconds: 20));
        }
        await gesto.moveBy(const Offset(60, -25));
        await gesto.up();
        await tester.pumpAndSettle();
        await pulsar(find.widgetWithText(FilledButton, 'Confirmar firma'));
        for (var n = 0; n < 12; n++) {
          await esperar(
            () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
            'Confirmación de firma',
          );
          if (find.text(mensaje).evaluate().isNotEmpty) return;
          final reintentar = find.widgetWithText(
            FilledButton,
            'Comprobar mismo intento',
          );
          if (reintentar.evaluate().isEmpty) break;
          await tester.pump(const Duration(seconds: 1));
          await pulsar(reintentar);
        }
        expect(find.text(mensaje), findsOneWidget);
      }

      Future<void> estadoWeb(String cite, String estado) async {
        final html = await web.pedir('/notas-internas/$_nota');
        expect(html, contains(cite));
        expect(html, contains('data-state="$estado"'));
      }

      try {
        expect(_via1, isNot(_via2));
        await web.entrar();
        await entrar('autor');
        await bandeja('Por firmar');
        await abrir();
        final inicial = await nota();
        await firmar(
          'Firmar borrador',
          'Firma registrada. Vuelve a web para emitir la nota.',
        );
        final firmada = await nota();
        expect(firmada['estado_firma'], 'firmada');
        expect(firmada['version'], inicial['version']);
        expect(
          await web.pedir('/notas-internas/$_nota'),
          contains('Emitir Nota Interna'),
        );
        await captura('remitente_firmado_android');

        final edit = await web.pedir('/notas-internas/$_nota/editar');
        await web.pedir('/notas-internas/$_nota', {
          '_token': web.csrf(edit),
          '_method': 'PATCH',
          'version': '${firmada['version']}',
          'asunto': '${firmada['asunto']}',
          'referencia': 'Datos ficticios de validación',
          'cuerpo': 'Documento corregido: esta nueva versión exige otra firma del remitente.',
          'destinatario_unidad_id': '$_destino',
          'vias_usuario_ids[0]': '$_via1',
          'vias_usuario_ids[1]': '$_via2',
        });
        final editada = await nota();
        expect(editada['estado_firma'], 'sin_solicitar');
        expect(editada['version'], greaterThan(firmada['version'] as int));
        await expectLater(
          api!.enviar(
            'POST',
            'notas-internas/$_nota/emision',
            datos: {'version': editada['version']},
            cabeceras: {'Idempotency-Key': nuevaClaveSolicitud()},
          ),
          throwsA(
            isA<ErrorLaravel>().having(
              (e) => e.estado,
              'emisión sin firma vigente',
              422,
            ),
          ),
        );
        await web.accion('solicitud-firma', {
          'version': '${editada['version']}',
        });
        await pulsar(find.byTooltip('Actualizar nota'));
        await esperar(
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
          'Nueva versión',
        );
        expect(
          find.text(
            'Documento corregido: esta nueva versión exige otra firma del remitente.',
          ),
          findsOneWidget,
        );
        await firmar(
          'Firmar borrador',
          'Firma registrada. Vuelve a web para emitir la nota.',
        );
        final nueva = await nota();
        expect(nueva['estado_firma'], 'firmada');
        evidencia['versiones_firmadas_remitente'] = [
          inicial['version'],
          nueva['version'],
        ];

        final emissionKey = nuevaClaveSolicitud();
        await web.accion('emision', {
          'version': '${nueva['version']}',
          'request_key': emissionKey,
        });
        var emitida = await nota();
        for (
          var n = 0;
          emitida['estado'] == 'emision_pendiente' && n < 12;
          n++
        ) {
          await tester.pump(const Duration(seconds: 1));
          await api!.enviarConEstado(
            'POST',
            'notas-internas/$_nota/emision',
            datos: {'version': nueva['version']},
            cabeceras: {'Idempotency-Key': emissionKey},
          );
          emitida = await nota();
        }
        expect(emitida['estado'], 'pendiente_revision');
        final cite = emitida['cite'] as String;
        evidencia['cite'] = cite;
        await estadoWeb(cite, 'pendiente_revision');

        await entrar('via2');
        expect(find.byKey(const ValueKey(_nota)), findsNothing);
        await expectLater(
          api!.enviar(
            'POST',
            'notas-internas/$_nota/conformidades',
            datos: {
              'version': emitida['version'],
              'firma': [
                [
                  [100, 200],
                  [300, 400],
                ],
              ],
            },
            cabeceras: {'Idempotency-Key': nuevaClaveSolicitud()},
          ),
          throwsA(
            isA<ErrorLaravel>().having(
              (e) => e.estado,
              'segunda VÍA sin turno',
              404,
            ),
          ),
        );
        evidencia['segunda_via_anticipada'] = 404;

        await entrar('via1');
        await abrir();
        await captura('primera_via_pendiente_android');
        await firmar('Firmar y dar conformidad', 'Conformidad registrada.');
        var actual = await nota();
        expect(actual['estado'], 'pendiente_revision');
        expect(
          (actual['movimientos_nota'] as List)
              .where((m) => m['accion'] == 'conformidad')
              .length,
          1,
        );
        await estadoWeb(cite, 'pendiente_revision');
        evidencia['primera_via_confirmada'] = true;
        await captura('primera_via_confirmada_android');

        await entrar('via2');
        await abrir();
        await firmar('Firmar y dar conformidad', 'Conformidad registrada.');
        actual = await nota();
        expect(actual['estado'], 'pendiente_recepcion');
        final aprobaciones = (actual['movimientos_nota'] as List)
            .where((m) => m['accion'] == 'conformidad')
            .toList();
        expect(aprobaciones.map((m) => m['actor']['id']).toList(), [
          _via1,
          _via2,
        ]);
        await estadoWeb(cite, 'pendiente_recepcion');
        evidencia['conformidades_en_orden'] = [_via1, _via2];
        evidencia['estado_tras_vias'] = actual['estado'];
        await captura('segunda_via_confirmada_android');
        binding.reportData = {
          ...?binding.reportData,
          'firma_dos_vias': evidencia,
        };
      } finally {
        web.close();
        if (sesion != null) await sesion!.salir();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        sesion?.dispose();
        api?.close();
      }
    },
    skip: _password.isEmpty || _nota.isEmpty,
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
