// Ensayo optativo: teléfono físico, formularios web y Camunda reales.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:t4_movil/compartido/api/api_config.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/compartido/diseno/institucional.dart';
import 'package:t4_movil/funciones/notas_internas/detalle_nota_page.dart';
import 'package:t4_movil/funciones/notas_internas/seguimiento_nota.dart';

const _nota = String.fromEnvironment('SEG63_NOTA');
const _cite = String.fromEnvironment('SEG63_CITE');
const _email = String.fromEnvironment('SEG63_TELEFONO_EMAIL');
const _password = String.fromEnvironment('SEG63_TELEFONO_PASSWORD');
const _destinoEmail = String.fromEnvironment('SEG63_DESTINO_EMAIL');
const _destinoPassword = String.fromEnvironment('SEG63_DESTINO_PASSWORD');
const _destinoUnidad = int.fromEnvironment('SEG63_DESTINO_UNIDAD');

class _WebSeguimiento {
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  final _cookies = <String, Cookie>{};

  Future<String> pedir(String ruta, [Map<String, String>? datos]) async {
    var uri = Uri.parse('${ApiConfig.baseUrl}$ruta');
    for (var intentos = 0; intentos < 10; intentos++) {
      final request = await _client.openUrl(
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
      for (final cookie in response.cookies) {
        _cookies[cookie.name] = cookie;
      }
      final html = await utf8.decoder.bind(response).join();
      if (response.statusCode == 429) {
        final seconds =
            int.tryParse(response.headers.value('retry-after') ?? '') ?? 60;
        await Future<void>.delayed(Duration(seconds: seconds + 1));
        continue;
      }
      if ({301, 302, 303}.contains(response.statusCode)) {
        uri = uri.resolve(response.headers.value('location')!);
        datos = null;
        continue;
      }
      expect(response.statusCode, 200, reason: 'Formulario web $ruta');
      return html;
    }
    throw StateError('La web no terminó la solicitud.');
  }

  String csrf(String html) {
    final match =
        RegExp('name="_token" value="([^"]+)"').firstMatch(html) ??
        RegExp('name="csrf-token" content="([^"]+)"').firstMatch(html);
    if (match == null) throw StateError('Falta CSRF en el formulario.');
    return match.group(1)!;
  }

  Future<void> entrar(String email, String password) async {
    final html = await pedir('/acceso');
    final resultado = await pedir('/acceso', {
      '_token': csrf(html),
      'email': email,
      'password': password,
    });
    expect(resultado, contains('Correspondencia institucional'));
  }

  Future<void> accion(
    String ruta,
    String pagina,
    Map<String, Object> datos,
  ) async {
    final html = await pedir(pagina);
    await pedir(ruta, {
      '_token': csrf(html),
      for (final entry in datos.entries) entry.key: '${entry.value}',
    });
  }

  void close() => _client.close(force: true);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('seguimiento real, sello y QR en teléfono sin recargar', (
    tester,
  ) async {
    expect(_nota, isNotEmpty);
    expect(_email, isNotEmpty);
    expect(_password, isNotEmpty);
    expect(_destinoUnidad, greaterThan(0));
    final api = ApiLaravel();
    final origenWeb = _WebSeguimiento();
    final destinoWeb = _WebSeguimiento();
    final mediciones = <Map<String, Object?>>[];
    final resultado = <String, Object?>{
      'nota': _nota,
      'cite': _cite,
      'transiciones': mediciones,
      'conexion':
          'Wi-Fi sin adb reverse; USB solo instalación y control del ensayo',
    };
    var capturaPreparada = false;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      try {
        if (api.token != null) await api.enviar('DELETE', 'sesiones/actual');
      } catch (_) {
        /* La app normal conserva su propia sesión. */
      }
      api.close();
      origenWeb.close();
      destinoWeb.close();
    });

    Future<void> esperar(
      bool Function() condicion,
      String motivo, {
      Duration limite = const Duration(seconds: 15),
    }) async {
      final fin = DateTime.now().add(limite);
      while (!condicion() && DateTime.now().isBefore(fin)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(condicion(), isTrue, reason: motivo);
    }

    Future<void> captura(String nombre) async {
      if (!capturaPreparada) {
        await binding.convertFlutterSurfaceToImage();
        capturaPreparada = true;
      }
      await tester.pumpAndSettle();
      await binding.takeScreenshot(nombre);
    }

    final acceso = await api.enviar(
      'POST',
      'sesiones',
      autenticado: false,
      datos: {
        'email': _email,
        'password': _password,
        'device_name': 'Ensayo físico seguimiento63',
      },
    );
    api.token = acceso['token'] as String;
    api.cuentaId = (acceso['user'] as Map)['id'].toString();
    await origenWeb.entrar(_email, _password);
    await destinoWeb.entrar(_destinoEmail, _destinoPassword);
    var actual = await api.enviar('GET', 'notas-internas/$_nota');
    expect(actual['estado'], 'pendiente_recepcion');
    expect(actual['sello_recepcion'], isNull);
    await tester.pumpWidget(
      MaterialApp(
        theme: Institucional.tema,
        home: DetalleNotaPage(api: api, id: _nota),
      ),
    );
    await esperar(
      () => find.byType(BarraSeguimientoNota).evaluate().isNotEmpty,
      'Detalle cargado',
    );
    final detalleInicial = tester.element(find.byType(DetalleNotaPage));

    Future<void> medir(
      String nombre,
      _WebSeguimiento web,
      String ruta,
      String pagina,
      Map<String, Object> datos,
      String etapa,
      String etiqueta,
    ) async {
      await web.accion(ruta, pagina, {
        ...datos,
        'request_key': nuevaClaveSolicitud(),
      });
      final reloj = Stopwatch()..start();
      actual = await api.enviar('GET', 'notas-internas/$_nota');
      expect(
        (actual['seguimiento'] as Map)['etiqueta'],
        etiqueta,
        reason: 'Confirmación del servidor: $nombre',
      );
      final unidad =
          ((actual['seguimiento'] as Map)['unidad'] as Map)['nombre'];
      await esperar(() {
        final barra = find.byType(BarraSeguimientoNota);
        if (barra.evaluate().isEmpty) return false;
        final datos = tester.widget<BarraSeguimientoNota>(barra).seguimiento;
        return datos.etiqueta == etiqueta &&
            datos.unidad == unidad &&
            datos.pasos.singleWhere((p) => p.estado == 'actual').id == etapa;
      }, 'Cambio automático de $nombre');
      reloj.stop();
      expect(
        identical(detalleInicial, tester.element(find.byType(DetalleNotaPage))),
        isTrue,
        reason: 'El detalle permanece abierto',
      );
      mediciones.add({
        'accion': nombre,
        'etapa': etapa,
        'etiqueta': etiqueta,
        'unidad': unidad,
        'latencia_desde_confirmacion_http_ms': reloj.elapsedMilliseconds,
        'sin_recargar': true,
      });
    }

    await medir(
      'recepcion',
      origenWeb,
      '/notas-internas/$_nota/recepciones',
      '/notas-internas/$_nota',
      {'version': actual['version'] as int},
      'recepcion',
      'Recibida',
    );
    final sello = actual['sello_recepcion'] as Map;
    expect(sello['funcionario'], isNotNull);
    await tester.scrollUntilVisible(
      find.text('RECIBIDO · DEMOSTRACIÓN'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text(sello['funcionario'] as String), findsWidgets);
    expect(find.text(sello['unidad'] as String), findsWidgets);
    expect(find.text(sello['id'] as String), findsNothing);
    await captura('sello_recepcion_android_real');
    await tester.scrollUntilVisible(
      find.byType(BarraSeguimientoNota),
      -240,
      scrollable: find.byType(Scrollable).first,
    );
    final hoja = actual['hoja_id'] as String,
        documento = actual['documento_id'] as String;
    var sheet = await api.enviar('GET', 'hojas/$hoja');
    expect(sheet['nota_id'], _nota);
    resultado['qr_resuelve_misma_nota'] = true;
    await medir(
      'derivacion',
      origenWeb,
      '/hojas/$hoja/derivaciones',
      '/documentos/$documento',
      {
        'version': (sheet['hoja'] as Map)['version'] as int,
        'destino_unidad_id': _destinoUnidad,
        'motivo': 'Ensayo físico de seguimiento',
      },
      'recepcion',
      'Recepción por derivación pendiente',
    );
    sheet = await api.enviar('GET', 'hojas/$hoja');
    await medir(
      'recepcion_derivada',
      destinoWeb,
      '/hojas/$hoja/recepciones',
      '/documentos/$documento',
      {'version': (sheet['hoja'] as Map)['version'] as int},
      'recepcion',
      'Recibida',
    );
    sheet = await api.enviar('GET', 'hojas/$hoja');
    await medir(
      'atencion',
      destinoWeb,
      '/hojas/$hoja/atenciones',
      '/documentos/$documento',
      {
        'version': (sheet['hoja'] as Map)['version'] as int,
        'observacion': 'Documento revisado en prueba física',
      },
      'atencion',
      'En atención',
    );
    sheet = await api.enviar('GET', 'hojas/$hoja');
    await medir(
      'cierre',
      destinoWeb,
      '/hojas/$hoja/cierre',
      '/documentos/$documento',
      {
        'version': (sheet['hoja'] as Map)['version'] as int,
        'motivo': 'Ensayo físico finalizado',
        'confirmar': '1',
      },
      'cierre',
      'Cerrada',
    );
    expect(actual['sello_recepcion'], sello);
    expect(find.text('Trámite finalizado'), findsOneWidget);
    await captura('seguimiento_cerrado_android_real');
    resultado['sello'] = sello;
    resultado['sello_estable'] = true;
    resultado['estado_final'] = actual['estado'];
    resultado['detalle_sin_reabrir'] = true;
    binding.reportData = {...?binding.reportData, ...resultado};
    for (final medida in mediciones) {
      expect(
        medida['latencia_desde_confirmacion_http_ms'] as int,
        lessThanOrEqualTo(5000),
        reason: 'Objetivo de cinco segundos: ${medida['accion']}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 6)));
}
