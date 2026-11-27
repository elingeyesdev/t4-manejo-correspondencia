import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/compartido/diseno/visor_pdf_institucional.dart';
import 'package:t4_movil/funciones/notas_internas/documento_nota_pdf.dart';
import 'package:t4_movil/funciones/notas_internas/hoja_nota.dart';
import 'package:t4_movil/funciones/notas_internas/nota_interna.dart';
import 'package:t4_movil/funciones/notas_internas/vista_previa_nota.dart';

import 'notas_internas_test.dart' as fixture;
import 'soporte/pdf_falso.dart';

Uint8List _bytes(int version) => Uint8List.fromList([
  ...File('test/fixtures/nota-dos-paginas.pdf').readAsBytesSync(),
  ...'\n%version-$version'.codeUnits,
]);
http.Response _pdf(int version) => http.Response.bytes(
  _bytes(version),
  200,
  headers: {'content-type': 'application/pdf', 'x-note-version': '$version'},
);

void main() {
  const canal = MethodChannel('correspondencia/documentos');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null),
  );

  testWidgets(
    'descarga el PDF completo y permite cancelar sin anunciar un guardado',
    (tester) async {
      final llamadas = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(canal, (call) async {
            llamadas.add(call);
            return llamadas.length > 1;
          });
      final api = fixture.conectar(
        (_) async => fixture.respuesta(fixture.nota()),
      );
      await fixture.abrir(
        tester,
        VistaPreviaNota(api: api, nota: NotaInterna.desdeJson(fixture.nota())),
      );
      await tester.tap(find.text('Descargar PDF'));
      await tester.pumpAndSettle();
      expect(llamadas.single.method, 'guardarPdf');
      expect(
        llamadas.single.arguments['bytes'],
        File('test/fixtures/nota-dos-paginas.pdf').readAsBytesSync(),
      );
      expect(llamadas.single.arguments['nombre'], 'CM_TI_001_v3.pdf');
      expect(
        find.text('PDF guardado en la ubicación que elegiste.'),
        findsNothing,
      );
      await tester.tap(find.text('Descargar PDF'));
      await tester.pumpAndSettle();
      expect(
        find.text('PDF guardado en la ubicación que elegiste.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('no guarda el archivo si la sesión cambia durante la descarga', (
    tester,
  ) async {
    final pendiente = Completer<http.Response>();
    var peticiones = 0, guardados = 0;
    final api = ApiLaravel(
      baseUrl: 'http://api.test',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/documento.pdf')) {
          return ++peticiones == 1 ? _pdf(3) : pendiente.future;
        }
        return fixture.respuesta(fixture.nota());
      }),
    )..token = 'primera';
    addTearDown(api.close);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (_) async {
          guardados++;
          return true;
        });
    await fixture.abrir(
      tester,
      VistaPreviaNota(api: api, nota: NotaInterna.desdeJson(fixture.nota())),
    );
    await tester.tap(find.text('Descargar PDF'));
    await tester.pump();
    api.token = 'otra';
    pendiente.complete(_pdf(3));
    await tester.pumpAndSettle();
    expect(guardados, 0);
    expect(find.textContaining('Tu sesión cambió.'), findsOneWidget);
  });

  testWidgets(
    'permite leer la segunda página y ampliar sin ejecutar acciones',
    (tester) async {
      var posts = 0;
      final api = fixture.conectar((request) async {
        if (request.method == 'POST') posts++;
        return fixture.respuesta(fixture.nota());
      });
      await fixture.abrir(
        tester,
        VistaPreviaNota(api: api, nota: NotaInterna.desdeJson(fixture.nota())),
      );
      expect(find.text('Página 1 de 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Página 2 de 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Ampliar documento'));
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(1),
      );
      expect(posts, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('una descarga anterior no reemplaza el PDF de la versión nueva', (
    tester,
  ) async {
    final antigua = Completer<http.Response>();
    final api = ApiLaravel(
      baseUrl: 'http://api.test',
      client: MockClient(
        (request) async => request.url.queryParameters['version'] == '3'
            ? antigua.future
            : _pdf(4),
      ),
    )..token = 'prueba';
    addTearDown(api.close);
    usarPdfFalso();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HojaNota(api: api, nota: NotaInterna.desdeJson(fixture.nota())),
        ),
      ),
    );
    await tester.pump();
    // La primera descarga sigue en curso. Sustituimos la versión antes de que responda.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HojaNota(
            api: api,
            nota: NotaInterna.desdeJson(fixture.nota(version: 4)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<VisorPdfInstitucional>(find.byType(VisorPdfInstitucional))
          .bytes,
      _bytes(4),
    );
    antigua.complete(_pdf(3));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<VisorPdfInstitucional>(find.byType(VisorPdfInstitucional))
          .bytes,
      _bytes(4),
    );
  });

  testWidgets(
    'una nota que avanza invalida las marcas provisionales antes de confirmar',
    (tester) async {
      var version = 3;
      final api = fixture.conectar(
        (request) async => fixture.respuesta(fixture.nota(version: version)),
      );
      final nota = NotaInterna.desdeJson(fixture.nota());
      await fixture.abrir(
        tester,
        VistaPreviaNota(
          api: api,
          nota: nota,
          provisional: DocumentoNotaPdf.desdeRespuesta(_pdf(3), 3),
          confirmar: true,
        ),
      );
      FilledButton boton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirmar y continuar'),
      );
      expect(boton().onPressed, isNotNull);
      expect(find.text('Descargar PDF'), findsNothing);
      version = 4;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.textContaining('La nota cambió.'), findsOneWidget);
      expect(boton().onPressed, isNull);
      expect(
        find.text(
          'Vista previa sin confirmar. Revisa todas las páginas antes de continuar.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'al retirar el permiso oculta la hoja y bloquea la confirmación',
    (tester) async {
      var denegado = false;
      final api = fixture.conectar(
        (request) async => fixture.respuesta(
          denegado ? {} : fixture.nota(),
          denegado ? 403 : 200,
        ),
      );
      await fixture.abrir(
        tester,
        VistaPreviaNota(
          api: api,
          nota: NotaInterna.desdeJson(fixture.nota()),
          provisional: DocumentoNotaPdf.desdeRespuesta(_pdf(3), 3),
          confirmar: true,
        ),
      );
      denegado = true;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(VisorPdfInstitucional), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar y continuar'),
            )
            .onPressed,
        isNull,
      );
    },
  );
}
