// Opt-in: captura el mismo caso ficticio ya cerrado en su bandeja de Copias.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/funciones/iniciar_sesion/sesion_controller.dart';
import 'package:t4_movil/main.dart';

class _Memoria implements AlmacenSesion {
  String? valor;
  @override
  Future<String?> leer() async => valor;
  @override
  Future<void> guardar(String value) async {
    valor = value;
  }

  @override
  Future<void> eliminar() async {
    valor = null;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('mismo CITE cerrado y template compartido con web', (
    tester,
  ) async {
    const email = String.fromEnvironment('ENSAYO_COPIA');
    const password = String.fromEnvironment('ENSAYO_PASSWORD');
    const id = String.fromEnvironment('ENSAYO_VIAS');
    const cite = String.fromEnvironment('ENSAYO_CITE_VIAS');
    if ([email, password, id, cite].any((v) => v.isEmpty)) {
      throw StateError('Se necesitan los datos privados del caso ficticio.');
    }
    final session = SesionController(api: ApiLaravel(), almacen: _Memoria());
    try {
      await tester.pumpWidget(CorrespondenciaApp(sesion: session));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), email);
      await tester.enterText(find.byType(TextFormField).at(1), password);
      Future<void> pulsar(Finder finder) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      Future<void> esperar(bool Function() condition) async {
        final deadline = DateTime.now().add(const Duration(seconds: 40));
        while (!condition() && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(condition(), isTrue);
      }

      await pulsar(find.widgetWithText(FilledButton, 'Iniciar sesión'));
      await esperar(() => !session.ocupada);
      expect(session.autenticada, isTrue, reason: session.mensaje);
      await pulsar(find.text('Notas internas'));
      await pulsar(find.widgetWithText(Tab, 'Copias'));
      final row = find.byKey(const ValueKey(id));
      await esperar(() => row.evaluate().isNotEmpty);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('comparacion_bandeja_android');
      await pulsar(row);
      await esperar(
        () =>
            find.text(cite).evaluate().isNotEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      expect(find.text('Cerrada'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Firmar y dar conformidad'),
        findsNothing,
      );
      expect(
        find.widgetWithText(FilledButton, 'Confirmar recepción'),
        findsNothing,
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('comparacion_detalle_android');
      binding.reportData ??= {};
      binding.reportData!['comparacion'] = {
        'nota': id,
        'cite': cite,
        'estado': 'cerrada',
        'rol': 'CC ficticia',
        'resultado': 'PASS',
      };
    } finally {
      if (session.autenticada) await session.salir();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      session.dispose();
      session.api.close();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
