import 'package:flutter/services.dart';

abstract final class GuardarPdf {
  static const _canal = MethodChannel('correspondencia/documentos');

  static Future<bool> guardar(Uint8List bytes, String nombre) async =>
      await _canal.invokeMethod<bool>('guardarPdf', {
        'bytes': bytes,
        'nombre': nombre,
      }) ??
      false;
}
