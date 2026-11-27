import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:t4_movil/compartido/api/laravel_api.dart';
import 'package:t4_movil/funciones/notas_internas/firma_nota.dart';
import 'package:t4_movil/funciones/notas_internas/imagen_constancia.dart';
import 'package:t4_movil/funciones/notas_internas/nota_interna.dart';
import 'package:t4_movil/funciones/notas_internas/notas_api.dart';

import 'notas_internas_test.dart' as fixture;

class _Cliente extends http.BaseClient {
  _Cliente(this.responder);
  final Future<http.StreamedResponse> Function(http.BaseRequest) responder;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      responder(request);
}

http.StreamedResponse _json(Object data, [int estado = 200]) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(data))),
      estado,
      headers: {'content-type': 'application/json'},
    );
http.StreamedResponse _pdf({
  int version = 3,
  Uint8List? bytes,
  String mime = 'application/pdf',
}) => http.StreamedResponse(
  Stream.value(
    bytes ?? File('test/fixtures/nota-dos-paginas.pdf').readAsBytesSync(),
  ),
  200,
  headers: {'content-type': mime, 'x-note-version': '$version'},
);

Uint8List get _png => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  ApiLaravel conectar(
    Future<http.StreamedResponse> Function(http.BaseRequest) responder,
  ) {
    final api =
        ApiLaravel(
            baseUrl: 'https://institucion.test',
            client: _Cliente(responder),
          )
          ..token = 'sesion-ficticia'
          ..cuentaId = '1';
    addTearDown(api.close);
    return api;
  }

  test(
    'lee el PDF de la versión consultada sin redirecciones y con sesión',
    () async {
      final api = conectar((request) async {
        expect(request.url.path, '/api/notas-internas/nota-1/documento.pdf');
        expect(request.url.queryParameters['version'], '3');
        expect(request.headers['Authorization'], 'Bearer sesion-ficticia');
        expect(request.headers['Accept'], 'application/pdf');
        expect(request.followRedirects, isFalse);
        return _pdf();
      });
      final documento = await NotasApi(api)
          .documento(NotaInterna.desdeJson(fixture.nota()));
      expect(documento.version, 3);
      expect(
        documento.bytes,
        File('test/fixtures/nota-dos-paginas.pdf').readAsBytesSync(),
      );
    },
  );

  for (final caso in [
    'otra versión',
    'tipo incorrecto',
    'archivo incompleto',
    'sesión cambiada',
  ]) {
    test('no presenta un documento con $caso', () async {
      late ApiLaravel api;
      api = conectar((request) async {
        if (caso == 'sesión cambiada') api.token = 'otra-sesion';
        return _pdf(
          version: caso == 'otra versión' ? 4 : 3,
          mime: caso == 'tipo incorrecto' ? 'text/html' : 'application/pdf',
          bytes: caso == 'archivo incompleto'
              ? Uint8List.fromList(ascii.encode('%PDF-1.7 incompleto'))
              : null,
        );
      });
      await expectLater(
        NotasApi(api).documento(NotaInterna.desdeJson(fixture.nota())),
        throwsA(isA<ErrorLaravel>()),
      );
    });
  }

  test(
    'vista previa separa firma y sello y no guarda ni confirma la acción',
    () async {
      final imagen = ImagenConstancia.desdeBytes(_png);
      final api = conectar((request) async {
        final form = request as http.MultipartRequest;
        expect(form.url.path, '/api/notas-internas/nota-1/vista-previa');
        expect(form.fields, {'version': '3', 'accion': 'dar_conformidad'});
        expect(form.headers.containsKey('Idempotency-Key'), isFalse);
        expect(form.files.map((f) => f.field), [
          'imagen_firma',
          'imagen_sello',
        ]);
        for (final file in form.files) {
          expect(await file.finalize().toBytes(), _png);
        }
        return _pdf();
      });
      await NotasApi(api).previsualizar(
        NotaInterna.desdeJson(fixture.nota()),
        AccionNota.conformidad,
        FirmaNota.constancia(firma: imagen, sello: imagen),
      );
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
    },
  );

  for (final accion in AccionNota.values) {
    test(
      '${accion.name}: recupera imágenes, clave y versión después de perder la respuesta',
      () async {
        final imagen = ImagenConstancia.desdeBytes(_png);
        final envios = <Map<String, Object>>[];
        final api = conectar((request) async {
          final form = request as http.MultipartRequest;
          final archivos = <String, List<int>>{};
          for (final file in form.files) {
            archivos[file.field] = await file.finalize().toBytes();
          }
          envios.add({
            'version': form.fields['version']!,
            'clave': form.headers['Idempotency-Key']!,
            'archivos': archivos,
          });
          if (envios.length == 1) throw http.ClientException('Sin respuesta');
          return _json({
            ...fixture.nota(
              version: accion == AccionNota.firmaRemitente ? 3 : 4,
              acciones: [],
              vinculada: accion == AccionNota.primeraRecepcion,
            ),
            if (accion == AccionNota.firmaRemitente) 'estado_firma': 'firmada',
          });
        });
        final original = SolicitudNota(
          nota: NotaInterna.desdeJson(fixture.nota()),
          accion: accion,
          token: api.token,
          cuentaId: api.cuentaId,
          firma: FirmaNota.constancia(
            firma: accion == AccionNota.primeraRecepcion ? null : imagen,
            sello: imagen,
          ),
        );
        await expectLater(
          NotasApi(api).ejecutar(original),
          throwsA(isA<ErrorLaravel>()),
        );
        final guardado = await const FlutterSecureStorage().readAll();
        expect(jsonDecode(guardado.values.single)['schema'], 3);
        final recuperado = (await NotasApi(api).pendientePara('nota-1'))!;
        expect(recuperado.clave, original.clave);
        expect(recuperado.version, original.version);
        expect(recuperado.requiereFirma, isFalse);
        await NotasApi(api).ejecutar(recuperado);
        expect(envios.last, envios.first);
        expect(await const FlutterSecureStorage().readAll(), isEmpty);
      },
    );
  }

  test('rechaza imágenes falsas y demasiado grandes antes de enviarlas', () {
    expect(
      () => ImagenConstancia.desdeBytes(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<ErrorLaravel>()),
    );
    expect(
      () => ImagenConstancia.desdeBytes(Uint8List(ImagenConstancia.maximo + 1)),
      throwsA(isA<ErrorLaravel>()),
    );
    expect(
      () => ImagenConstancia.desdeJson('valor-invalido'),
      throwsA(anything),
    );
  });
}
