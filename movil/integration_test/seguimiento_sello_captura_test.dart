// Lectura y capturas de una nota ficticia ya cerrada por el ensayo físico.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/compartido/diseno/institucional.dart';
import 'package:t4_movil/funciones/notas_internas/detalle_nota_page.dart';
import 'package:t4_movil/funciones/notas_internas/seguimiento_nota.dart';
import 'package:t4_movil/funciones/notas_internas/vista_previa_nota.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capturas reales del cierre y del sello en vista previa', (
    tester,
  ) async {
    const id = String.fromEnvironment('SEG63_NOTA');
    const email = String.fromEnvironment('SEG63_TELEFONO_EMAIL');
    const password = String.fromEnvironment('SEG63_TELEFONO_PASSWORD');
    expect(id, isNotEmpty);
    final api = ApiLaravel();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      try {
        if (api.token != null) await api.enviar('DELETE', 'sesiones/actual');
      } catch (_) {
        /* Credencial exclusiva del ensayo. */
      }
      api.close();
    });
    final login = await api.enviar(
      'POST',
      'sesiones',
      autenticado: false,
      datos: {
        'email': email,
        'password': password,
        'device_name': 'Capturas ficticias seguimiento63',
      },
    );
    api.token = login['token'] as String;
    api.cuentaId = (login['user'] as Map)['id'].toString();
    final data = await api.enviar('GET', 'notas-internas/$id');
    expect(data['estado'], 'cerrada');
    final sello = data['sello_recepcion'] as Map;
    await tester.pumpWidget(
      MaterialApp(
        theme: Institucional.tema,
        home: DetalleNotaPage(api: api, id: id),
      ),
    );
    final limit = DateTime.now().add(const Duration(seconds: 20));
    while (find.byType(BarraSeguimientoNota).evaluate().isEmpty &&
        DateTime.now().isBefore(limit)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Trámite finalizado'), findsOneWidget);
    expect(
      tester
          .widget<BarraSeguimientoNota>(find.byType(BarraSeguimientoNota))
          .seguimiento
          .pasos
          .last
          .estado,
      'actual',
    );
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('cierre_seguimiento_android_real');
    final boton = find.text('Abrir vista previa');
    if (boton.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        boton,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(find.byType(VistaPreviaNota), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('RECIBIDO · DEMOSTRACIÓN'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text(sello['funcionario'] as String), findsOneWidget);
    expect(find.text(sello['id'] as String), findsNothing);
    await binding.takeScreenshot('sello_vista_previa_android_real');
    binding.reportData = {
      ...?binding.reportData,
      'nota': id,
      'cite': data['cite'],
      'estado': data['estado'],
      'sello_vista_previa_comprobado': true,
    };
  }, timeout: const Timeout(Duration(minutes: 2)));
}
