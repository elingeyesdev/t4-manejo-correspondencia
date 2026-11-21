// Opt-in local: requiere datos privados mediante --dart-define-from-file.
// Por defecto sólo consulta. ACCESO_COMPLETAR_NOTA permite recibir y atender
// una nota ficticia, incluida una interrupción controlada de su respuesta.
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/funciones/iniciar_sesion/sesion_controller.dart';
import 'package:t4_movil/main.dart';
import 'package:t4_movil/compartido/diseno/institucional.dart';
import 'package:t4_movil/funciones/notas_internas/detalle_nota_page.dart';
import 'package:t4_movil/funciones/notas_internas/notas_api.dart';

class _RespuestaInterrumpida extends http.BaseClient {
  final _real = http.Client();
  bool interrumpida = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _real.send(request);
    if (const bool.fromEnvironment('ACCESO_COMPLETAR_NOTA') &&
        !interrumpida &&
        request.method == 'POST' &&
        request.url.path.contains('/notas-internas/') &&
        request.url.path.endsWith('/recepciones') &&
        response.statusCode == 200) {
      await response.stream.drain<void>();
      interrumpida = true;
      throw http.ClientException(
        'Interrupción controlada de una respuesta ya recibida.',
      );
    }
    return response;
  }

  @override
  void close() => _real.close();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('acceso solicitado y nota pendiente de recepción', (
    tester,
  ) async {
    const email = String.fromEnvironment('ACCESO_EMAIL');
    const password = String.fromEnvironment('ACCESO_PASSWORD');
    const noteId = String.fromEnvironment('ACCESO_NOTA_ID');
    if (email.isEmpty || password.isEmpty || noteId.isEmpty) {
      throw StateError(
        'Este ensayo requiere el archivo privado de acceso local.',
      );
    }
    final transporte = _RespuestaInterrumpida();
    final session = SesionController(api: ApiLaravel(client: transporte));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      session.dispose();
      session.api.close();
    });
    await session.restaurar();
    if (session.autenticada) await session.salir();
    await tester.pumpWidget(CorrespondenciaApp(sesion: session));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    final button = find.widgetWithText(FilledButton, 'Iniciar sesión');
    await tester.ensureVisible(button);
    await tester.tap(button);

    Future<void> esperar(bool Function() condition, String reason) async {
      final limit = DateTime.now().add(const Duration(seconds: 45));
      while (!condition() && DateTime.now().isBefore(limit)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(condition(), isTrue, reason: reason);
    }

    await esperar(
      () => !session.ocupada,
      'La solicitud de acceso debe terminar.',
    );
    expect(session.autenticada, isTrue, reason: session.mensaje);
    expect(session.usuario?['email'], email);
    expect(session.rol, 'funcionario');
    await tester.pumpAndSettle();
    final notes = find.text('Notas internas');
    await tester.ensureVisible(notes);
    await tester.tap(notes);
    await tester.pumpAndSettle();
    final receive = find.text('Por recibir');
    await tester.ensureVisible(receive);
    await tester.tap(receive);
    await esperar(
      () => find.byKey(const ValueKey(noteId)).evaluate().isNotEmpty,
      'La nota autorizada debe aparecer en Por recibir.',
    );
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('recepcion_xd_telefono');
    var recepcionConfirmada = false;
    String? estadoFinal;
    if (const bool.fromEnvironment('ACCESO_COMPLETAR_NOTA')) {
      Future<void> pulsar(Finder target) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        if (target.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            target,
            250,
            scrollable: find
                .byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                )
                .last,
          );
        }
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await pulsar(find.byKey(const ValueKey(noteId)));
      await pulsar(find.widgetWithText(FilledButton, 'Confirmar recepción'));
      await pulsar(find.widgetWithText(FilledButton, 'Confirmar'));
      for (var i = 0; i < 8; i++) {
        if (transporte.interrumpida) break;
        if (find.text('Recepción confirmada.').evaluate().isNotEmpty) break;
        final pending = find.widgetWithText(
          FilledButton,
          'Comprobar mismo intento',
        );
        if (pending.evaluate().isEmpty) break;
        await tester.pump(const Duration(seconds: 2));
        await pulsar(pending);
      }
      final received = await session.api.enviar(
        'GET',
        'notas-internas/$noteId',
      );
      expect(received['estado'], 'recibida');
      expect(received['documento_id'], isNotNull);
      expect(transporte.interrumpida, isTrue);
      final pendiente = await NotasApi(session.api).pendientePara(noteId);
      expect(
        pendiente,
        isNotNull,
        reason: 'La pérdida de respuesta debe conservar el intento en el almacenamiento seguro.',
      );
      // Recrea pantalla y servicio; Laravel y Camunda siguen siendo reales.
      await tester.pumpWidget(
        MaterialApp(
          theme: Institucional.tema,
          home: DetalleNotaPage(api: session.api, id: noteId),
        ),
      );
      await esperar(
        () => find
            .text('La recepción ya está registrada. Estado actualizado.')
            .evaluate()
            .isNotEmpty,
        'La pantalla reabierta debe conciliar el intento sin repetir la recepción.',
      );
      expect(await NotasApi(session.api).pendientePara(noteId), isNull);
      recepcionConfirmada = true;
      await pulsar(find.widgetWithText(OutlinedButton, 'Registrar atención'));
      await tester.enterText(
        find.byType(TextFormField).last,
        'Prueba ficticia de recepción y atención desde el teléfono.',
      );
      await pulsar(find.widgetWithText(FilledButton, 'Guardar atención'));
      final attended = await session.api.enviar(
        'GET',
        'notas-internas/$noteId',
      );
      expect(attended['estado'], 'en_atencion');
      estadoFinal = attended['estado'] as String;
      await binding.takeScreenshot('xd_atendida_telefono');
    }
    binding.reportData = {
      ...?binding.reportData,
      'acceso': 'PASS',
      'rol': 'funcionario',
      'bandeja': 'Por recibir',
      'nota_visible': noteId,
      'recepcion_confirmada_por_ensayo': recepcionConfirmada,
      'estado_final': ?estadoFinal,
      if (recepcionConfirmada) 'recuperacion': 'Respuesta interrumpida controlada; intento persistido en almacenamiento seguro y conciliado al recrear la pantalla, sin reenviar la recepción.',
    };
    // Se conserva la sesión protegida para volver al APK normal de la app.
  }, timeout: const Timeout(Duration(minutes: 3)));
}
