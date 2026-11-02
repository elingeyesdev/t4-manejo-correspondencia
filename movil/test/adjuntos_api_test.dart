import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:t4_movil/services/adjuntos_api.dart';
import 'package:t4_movil/services/camara_documento.dart';
import 'package:t4_movil/services/laravel_api.dart';

final png = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aDZkAAAAASUVORK5CYII=',
  ),
);
Map<String, dynamic> datos({
  String nombre = 'foto.png',
  String documento = 'doc-1',
  int? tamano,
}) => {
  'id': 'adjunto-1',
  'document_id': documento,
  'nombre': nombre,
  'mime': 'image/png',
  'tamano_bytes': tamano ?? png.length,
  'creado_en': '2026-11-02T12:00:00Z',
  'descarga_url': 'https://otro-origen.example/no-enviar-token',
};
void main() {
  test(
    'multipart conserva el token y campo archivo; solo confirma HTTP 201',
    () async {
      final api = ApiLaravel(
        baseUrl: 'http://api.test',
        client: MockClient((r) async {
          expect(r.method, 'POST');
          expect(r.url.path, '/api/documentos/doc-1/adjuntos');
          expect(r.headers['Authorization'], 'Bearer token');
          expect(
            r.headers['Content-Type'],
            startsWith('multipart/form-data; boundary='),
          );
          final body = latin1.decode(r.bodyBytes);
          expect(body, contains('name="archivo"'));
          expect(body, contains('filename="foto.png"'));
          expect(body.toLowerCase(), contains('content-type: image/png'));
          return http.Response(jsonEncode(datos()), 201);
        }),
      )..token = 'token';
      addTearDown(api.close);
      final a = await AdjuntosApi(api).subir(
        'doc-1',
        FotoDocumento('no-se-lee-disco', bytes: png),
        'foto.png',
      );
      expect(a.id, 'adjunto-1');
    },
  );

  test(
    'descarga autenticada ignora URL externa y comprueba MIME y tamaño',
    () async {
      final api = ApiLaravel(
        baseUrl: 'http://api.test',
        client: MockClient((r) async {
          expect(r.url.host, 'api.test');
          expect(
            r.url.path,
            '/api/documentos/doc-1/adjuntos/adjunto-1/descarga',
          );
          expect(r.headers['Authorization'], 'Bearer token');
          return http.Response.bytes(
            png,
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      )..token = 'token';
      addTearDown(api.close);
      final content = await AdjuntosApi(api)
          .descargar(Adjunto.leer(datos(), 'doc-1'));
      expect(content.bytes, png);
    },
  );

  test('archivo truncado y MIME distinto se rechazan sin abrirlos', () async {
    for (final tipo in ['image/png', 'text/html']) {
      final api = ApiLaravel(
        baseUrl: 'http://api.test',
        client: MockClient(
          (_) async => http.Response.bytes(
            png.sublist(1),
            200,
            headers: {'content-type': tipo},
          ),
        ),
      )..token = 't';
      addTearDown(api.close);
      await expectLater(
        AdjuntosApi(api).descargar(Adjunto.leer(datos(), 'doc-1')),
        throwsA(isA<ErrorLaravel>()),
      );
    }
  });

  test('respuesta perdida no repite el POST y permite comprobar el archivo guardado', () async {
    var posts = 0;
    final api = ApiLaravel(
      baseUrl: 'http://api.test',
      client: MockClient((r) async {
        if (r.method == 'POST') {
          posts++;
          throw http.ClientException('conexión cerrada');
        }
        if (r.url.path.endsWith('/descarga')) {
          return http.Response.bytes(
            png,
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        return http.Response(
          jsonEncode({
            'data': [datos()],
            'current_page': 1,
            'last_page': 1,
          }),
          200,
        );
      }),
    )..token = 't';
    addTearDown(api.close);
    final servicio = AdjuntosApi(api);
    final foto = FotoDocumento('temporal', bytes: png);
    await expectLater(
      servicio.subir('doc-1', foto, 'foto.png'),
      throwsA(
        isA<ErrorLaravel>().having(
          (e) => e.codigo,
          'código',
          'SUBIDA_INCIERTA',
        ),
      ),
    );
    final confirmado = await servicio.comprobar('doc-1', foto, 'foto.png');
    expect(confirmado?.id, 'adjunto-1');
    expect(posts, 1);
  });

  test('no confunde un nombre igual con contenido distinto; comprueba otras páginas', () async {
    final rutas = <String>[];
    final api = ApiLaravel(
      baseUrl: 'http://api.test',
      client: MockClient((r) async {
        rutas.add(r.url.toString());
        if (r.url.path.endsWith('/descarga')) {
          return http.Response.bytes(
            Uint8List(png.length),
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        final page = int.parse(r.url.queryParameters['page']!);
        return http.Response(
          jsonEncode({
            'data': page == 1 ? [] : [datos()],
            'current_page': page,
            'last_page': 2,
          }),
          200,
        );
      }),
    )..token = 't';
    addTearDown(api.close);
    expect(
      await AdjuntosApi(api)
          .comprobar('doc-1', FotoDocumento('temp', bytes: png), 'foto.png'),
      isNull,
    );
    expect(rutas.any((r) => r.contains('page=2')), isTrue);
  });

  test('401 invalida la sesión, 403 conserva el estado y 422 muestra el rechazo del archivo', () async {
    for (final estado in [401, 403, 422]) {
      var vencimientos = 0;
      final api = ApiLaravel(
        baseUrl: 'http://api.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'errors': {
                'archivo': ['Solo PDF, JPEG o PNG.'],
              },
            }),
            estado,
          ),
        ),
      )..token = 't';
      api.alVencerSesion = () async {
        vencimientos++;
        api.token = null;
      };
      addTearDown(api.close);
      await expectLater(
        AdjuntosApi(api)
            .subir('doc-1', FotoDocumento('temp', bytes: png), 'foto.png'),
        throwsA(isA<ErrorLaravel>().having((e) => e.estado, 'estado', estado)),
      );
      expect(vencimientos, estado == 401 ? 1 : 0);
    }
  });

  test('una respuesta 201 ilegible se considera incierta, nunca un éxito inventado', () async {
    final api = ApiLaravel(
      baseUrl: 'http://api.test',
      client: MockClient((_) async => http.Response('{}', 201)),
    )..token = 't';
    addTearDown(api.close);
    await expectLater(
      AdjuntosApi(api)
          .subir('doc-1', FotoDocumento('temp', bytes: png), 'foto.png'),
      throwsA(
        isA<ErrorLaravel>().having(
          (e) => e.codigo,
          'código',
          'SUBIDA_INCIERTA',
        ),
      ),
    );
  });

  test('no acepta adjuntos de otro documento ni listas incompletas', () async {
    expect(
      () => Adjunto.leer(datos(documento: 'otro'), 'doc-1'),
      throwsA(isA<ErrorLaravel>()),
    );
    final api = ApiLaravel(
      baseUrl: 'http://api.test',
      client: MockClient((_) async => http.Response('{"data":[]}', 200)),
    )..token = 't';
    addTearDown(api.close);
    await expectLater(
      AdjuntosApi(api).listar('doc-1'),
      throwsA(isA<ErrorLaravel>()),
    );
  });

  test(
    'no envía credenciales a otro origen y no sigue redirecciones',
    () async {
      var llamadas = 0;
      final api = ApiLaravel(
        baseUrl: 'http://api.test',
        client: MockClient((r) async {
          llamadas++;
          expect(r.followRedirects, isFalse);
          return http.Response(
            '',
            302,
            headers: {'location': 'https://otro.example'},
          );
        }),
      )..token = 't';
      addTearDown(api.close);
      await expectLater(
        api.enviarArchivo(
          http.Request('GET', Uri.parse('https://otro.example/api/x')),
        ),
        throwsA(isA<ErrorLaravel>()),
      );
      expect(llamadas, 0);
      await expectLater(
        api.enviarArchivo(
          http.Request('GET', Uri.parse('http://api.test/api/x')),
        ),
        throwsA(isA<ErrorLaravel>()),
      );
      expect(llamadas, 1);
    },
  );

  test(
    'una sesión reemplazada durante la descarga no recibe los datos anteriores',
    () async {
      final pendiente = Completer<http.Response>();
      final api = ApiLaravel(
        baseUrl: 'http://api.test',
        client: MockClient((_) => pendiente.future),
      )..token = 'viejo';
      addTearDown(api.close);
      final futuro = AdjuntosApi(api).descargar(Adjunto.leer(datos(), 'doc-1'));
      await Future<void>.delayed(Duration.zero);
      api.token = 'nuevo';
      pendiente.complete(
        http.Response.bytes(png, 200, headers: {'content-type': 'image/png'}),
      );
      await expectLater(
        futuro,
        throwsA(isA<ErrorLaravel>().having((e) => e.estado, 'estado', 401)),
      );
      expect(api.token, 'nuevo');
    },
  );
}
