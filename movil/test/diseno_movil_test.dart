import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:t4_movil/main.dart';
import 'package:t4_movil/pages/diseno_movil_page.dart';
import 'package:t4_movil/services/consulta_envio_service.dart';
import 'package:t4_movil/models/envio_consulta.dart';

class _SinConsultas implements ConsultaEnvioService {
  int llamadas = 0;
  @override
  Future<EnvioConsulta?> consultar(String numeroGuia) async {
    llamadas++;
    return null;
  }
}

Future<void> _pulsar(WidgetTester tester, String texto) async {
  final objetivo = find.text(texto).last;
  await tester.ensureVisible(objetivo);
  await tester.tap(objetivo);
  await tester.pumpAndSettle();
}

Future<void> _abrir(WidgetTester tester, _SinConsultas servicio) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(CorrespondenciaApp(servicio: servicio));
  await _pulsar(tester, 'Gestión documental');
}

Future<void> _pantalla(WidgetTester tester, PantallaDiseno pantalla) async {
  await tester.tap(find.byTooltip('Revisar pantallas'));
  await tester.pumpAndSettle();
  final selector = find.byType(DropdownButtonFormField<PantallaDiseno>);
  await tester.ensureVisible(selector);
  await tester.tap(selector);
  await tester.pumpAndSettle();
  await _pulsar(tester, pantalla.titulo);
}

Future<void> _caso(WidgetTester tester, CasoDiseno caso) async {
  await tester.tap(find.byTooltip('Revisar pantallas'));
  await tester.pumpAndSettle();
  final selector = find.byType(DropdownButtonFormField<CasoDiseno>);
  await tester.ensureVisible(selector);
  await tester.tap(selector);
  await tester.pumpAndSettle();
  await _pulsar(tester, caso.titulo);
}

void main() {
  testWidgets(
    'pantallas legibles a 320 px con texto ampliado y controles de revisión separados',
    (tester) async {
      final servicio = _SinConsultas();
      await _abrir(tester, servicio);
      await tester.binding.setSurfaceSize(const Size(320, 740));
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<CasoDiseno>), findsNothing);
      for (final pantalla in PantallaDiseno.values) {
        await _pantalla(tester, pantalla);
        expect(tester.takeException(), isNull, reason: pantalla.titulo);
      }
      await _caso(tester, CasoDiseno.credenciales);
      expect(find.text('No pudimos iniciar sesión'), findsOneWidget);
      expect(servicio.llamadas, 0);
    },
  );
  testWidgets('recorre recepción, atención y derivación sin consultar la API', (
    tester,
  ) async {
    final servicio = _SinConsultas();
    await _abrir(tester, servicio);
    expect(find.text('Conexión pendiente · cambios locales'), findsOneWidget);
    await _pulsar(tester, 'Abrir bandeja');
    await _pulsar(tester, 'Ver documento');
    await _pulsar(tester, 'Confirmar recepción');
    await _pulsar(tester, 'Revisar recepción');
    expect(
      find.textContaining('no envía cambios al servidor.'),
      findsOneWidget,
    );
    await _pulsar(tester, 'Continuar recorrido');
    expect(find.text('Recepción confirmada'), findsOneWidget);
    await _pulsar(tester, 'Registrar atención');
    await _pulsar(tester, 'Revisar atención');
    expect(find.text('Escribe una observación.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Revisión de ejemplo');
    await _pulsar(tester, 'Revisar atención');
    await _pulsar(tester, 'Continuar recorrido');
    expect(find.text('Atención registrada'), findsOneWidget);
    await _pulsar(tester, 'Derivar hoja');
    await tester.enterText(find.byType(TextFormField), 'Motivo de ejemplo');
    await _pulsar(tester, 'Revisar derivación');
    await _pulsar(tester, 'Continuar recorrido');
    expect(find.text('Derivación enviada'), findsOneWidget);
    expect(find.text('Registrar atención'), findsNothing);
    expect(servicio.llamadas, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'QR localiza sin recibir y captura exige previsualizar y confirmar',
    (tester) async {
      final servicio = _SinConsultas();
      await _abrir(tester, servicio);
      await _pantalla(tester, PantallaDiseno.qr);
      await _pulsar(tester, 'Abrir hoja de ruta');
      expect(find.text('Recepción confirmada'), findsNothing);
      await _pulsar(tester, 'Confirmar recepción');
      await _pulsar(tester, 'Revisar recepción');
      await _pulsar(tester, 'Continuar recorrido');
      await _pulsar(tester, 'Capturar documento');
      await _pulsar(tester, 'Ver previsualización');
      await _pulsar(tester, 'Repetir');
      expect(find.text('Revisar envío'), findsNothing);
      await _pulsar(tester, 'Ver previsualización');
      await _pulsar(tester, 'Revisar envío');
      await _pulsar(tester, 'Cancelar');
      expect(find.text('captura-documento.jpg'), findsNothing);
      await _pulsar(tester, 'Revisar envío');
      await _pulsar(tester, 'Continuar recorrido');
      expect(find.text('captura-documento.jpg'), findsOneWidget);
      expect(servicio.llamadas, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'muestra fallos sin autenticar ni llamar a la API y conserva el motivo',
    (tester) async {
      final servicio = _SinConsultas();
      await _abrir(tester, servicio);
      await _pantalla(tester, PantallaDiseno.derivacion);
      await tester.enterText(
        find.byType(TextFormField),
        'Conservar este texto',
      );
      await _caso(tester, CasoDiseno.conexion);
      expect(find.text('No pudimos conectarnos'), findsOneWidget);
      await _pulsar(tester, 'Reintentar');
      expect(find.text('Conservar este texto'), findsOneWidget);
      await _caso(tester, CasoDiseno.sesion);
      expect(find.text('Tu sesión venció'), findsOneWidget);
      await _pulsar(tester, 'Volver al acceso');
      await _pantalla(tester, PantallaDiseno.camara);
      await _caso(tester, CasoDiseno.permisoCamara);
      expect(find.text('Permiso de cámara necesario'), findsOneWidget);
      await _pulsar(tester, 'Ver cámara habilitada');
      await _caso(tester, CasoDiseno.sinAcceso);
      expect(find.text('No tienes acceso'), findsOneWidget);
      await _pulsar(tester, 'Volver a mi bandeja');
      await _caso(tester, CasoDiseno.bandejaVacia);
      expect(
        find.textContaining('No tienes documentos asignados.'),
        findsOneWidget,
      );
      expect(servicio.llamadas, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
