import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';

import '../../compartido/api/laravel_api.dart';
import '../adjuntos/adjuntos_api.dart';

class ImagenConstancia {
  ImagenConstancia._(Uint8List bytes, this.mime)
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final Uint8List bytes;
  final String mime;
  static const maximo = 512 * 1024;
  String get extension => mime == 'image/png' ? 'png' : 'jpg';

  static Future<ImagenConstancia?> elegir() async {
    final archivo = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Firma o sello',
          extensions: ['png', 'jpg', 'jpeg'],
          mimeTypes: ['image/png', 'image/jpeg'],
        ),
      ],
    );
    if (archivo == null) return null;
    if (await archivo.length() > maximo) {
      throw const ErrorLaravel('La imagen debe ocupar hasta 512 KB.');
    }
    return validar(await archivo.readAsBytes());
  }

  static Future<ImagenConstancia> validar(Uint8List bytes) async {
    final imagen = ImagenConstancia.desdeBytes(bytes);
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      ui.ImageDescriptor? descriptor;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        if (descriptor.width > 2000 || descriptor.height > 2000) {
          throw const ErrorLaravel(
            'La imagen debe medir hasta 2000 por 2000 píxeles.',
          );
        }
      } finally {
        descriptor?.dispose();
        buffer.dispose();
      }
      return imagen;
    } on ErrorLaravel {
      rethrow;
    } catch (_) {
      throw const ErrorLaravel(
        'No se pudo leer la imagen. Elige un PNG o JPEG válido.',
      );
    }
  }

  factory ImagenConstancia.desdeBytes(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maximo) {
      throw const ErrorLaravel('La imagen debe ocupar hasta 512 KB.');
    }
    return ImagenConstancia._(bytes, AdjuntosApi.tipoFoto(bytes));
  }

  factory ImagenConstancia.desdeJson(Object? valor) {
    if (valor is! String || valor.length > 4 * ((maximo + 2) ~/ 3)) {
      throw const FormatException('Imagen guardada inválida');
    }
    return ImagenConstancia.desdeBytes(base64Decode(valor));
  }

  String toJson() => base64Encode(bytes);
}
