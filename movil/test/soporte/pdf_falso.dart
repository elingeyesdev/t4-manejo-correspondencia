import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfx/pdfx.dart';
import 'package:pdfx/src/renderer/interfaces/platform.dart';

void usarPdfFalso() => PdfxPlatform.instance = _PlataformaPdf();

class _PlataformaPdf extends PdfxPlatform {
  static int _secuencia = 0;
  @override
  Future<PdfDocument> openData(
    FutureOr<Uint8List> data, {
    String? password,
  }) async {
    await data;
    return _Documento('${++_secuencia}');
  }

  @override
  Future<PdfDocument> openAsset(String name, {String? password}) =>
      throw UnimplementedError();
  @override
  Future<PdfDocument> openFile(String filePath, {String? password}) =>
      throw UnimplementedError();
}

class _Documento extends Fake implements PdfDocument {
  _Documento(this.id);
  @override
  final String id;
  @override
  int get pagesCount => 2;
  @override
  bool isClosed = false;
  @override
  Future<void> close() async {
    isClosed = true;
  }

  @override
  Future<PdfPage> getPage(
    int pageNumber, {
    bool autoCloseAndroid = false,
  }) async => _Pagina(this, pageNumber);
}

class _Pagina extends Fake implements PdfPage {
  _Pagina(this.document, this.pageNumber);
  @override
  final PdfDocument document;
  @override
  final int pageNumber;
  @override
  String get id => '${document.id}-$pageNumber';
  @override
  double get width => 612;
  @override
  double get height => 792;
  @override
  bool get isClosed => false;
  @override
  Future<void> close() async {}
  @override
  Future<PdfPageTexture> createTexture() async => _Textura(pageNumber);
  @override
  Future<PdfPageImage?> render({
    required double width,
    required double height,
    PdfPageImageFormat format = PdfPageImageFormat.jpeg,
    String? backgroundColor,
    Rect? cropRect,
    int quality = 100,
    bool forPrint = false,
    bool removeTempFile = true,
  }) async => _Imagen();
}

class _Imagen extends Fake implements PdfPageImage {
  @override
  Uint8List get bytes => base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
  );
}

class _Textura extends Fake implements PdfPageTexture {
  _Textura(this.pageNumber);
  @override
  final int pageNumber;
  @override
  int get id => pageNumber;
  @override
  int textureWidth = 612;
  @override
  int textureHeight = 792;
  @override
  bool get hasUpdatedTexture => true;
  @override
  Future<void> dispose() async {}
  @override
  Future<bool> updateRect({
    required String documentId,
    int destinationX = 0,
    int destinationY = 0,
    int? width,
    int? height,
    int sourceX = 0,
    int sourceY = 0,
    int? textureWidth,
    int? textureHeight,
    double? fullWidth,
    double? fullHeight,
    String? backgroundColor,
    bool allowAntiAliasing = true,
  }) async {
    if (textureWidth != null) this.textureWidth = textureWidth;
    if (textureHeight != null) this.textureHeight = textureHeight;
    return true;
  }
}
