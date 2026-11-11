import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class ErrorCamara implements Exception {
  const ErrorCamara(this.mensaje, {this.abrirAjustes = false});
  final String mensaje;
  final bool abrirAjustes;
}

class FotoDocumento {
  const FotoDocumento(this.ruta, {required this.bytes});
  final Uint8List bytes;
  final String ruta;

  Future<void> descartar() async {
    try {
      final file = File(ruta);
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // La captura está en la caché privada; Android puede haberla retirado.
    }
  }
}

abstract class CamaraDocumento {
  Future<void> iniciar({required bool solicitarPermiso});
  Widget vista();
  Future<FotoDocumento> tomar();
  Future<void> cerrar();
  Future<bool> abrirAjustes();
}

class CamaraAndroid extends CamaraDocumento {
  CameraController? _controller;
  int _generacion = 0;

  @override
  Future<void> iniciar({required bool solicitarPermiso}) async {
    await cerrar();
    final generacion = _generacion;
    var permiso = await Permission.camera.status;
    if (!permiso.isGranted &&
        solicitarPermiso &&
        !permiso.isPermanentlyDenied) {
      permiso = await Permission.camera.request();
    }
    if (!permiso.isGranted) {
      throw ErrorCamara(
        'Necesitamos permiso para fotografiar el documento. '
        'Puedes continuar usando la app sin tomar una foto.',
        abrirAjustes: permiso.isPermanentlyDenied || permiso.isRestricted,
      );
    }
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw const ErrorCamara(
          'No se encontró una cámara en este dispositivo.',
        );
      }
      if (generacion != _generacion) return;
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      // Solo fotografía: no se solicita permiso para grabar audio.
      controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (generacion != _generacion) {
        await controller.dispose();
        return;
      }
      _controller = controller;
    } on CameraException {
      await controller?.dispose();
      throw const ErrorCamara(
        'No se pudo abrir la cámara. Comprueba el permiso y vuelve a intentar.',
      );
    }
  }

  @override
  Widget vista() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return CameraPreview(controller);
  }

  @override
  Future<FotoDocumento> tomar() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const ErrorCamara('Abre la cámara antes de tomar la foto.');
    }
    FotoDocumento? foto;
    try {
      final ruta = (await controller.takePicture()).path;
      final file = File(ruta);
      final size = await file.length();
      if (size == 0 || size > 10 * 1024 * 1024) {
        await file.delete();
        throw const ErrorCamara(
          'La foto debe ocupar entre 1 byte y 10 MB. Vuelve a tomarla.',
        );
      }
      foto = FotoDocumento(ruta, bytes: await file.readAsBytes());
      return foto;
    } on CameraException {
      throw const ErrorCamara('No se pudo tomar la foto. Intenta nuevamente.');
    } on FileSystemException {
      await foto?.descartar();
      throw const ErrorCamara(
        'No se pudo conservar la foto. Revisa el espacio del teléfono.',
      );
    }
  }

  @override
  Future<void> cerrar() async {
    _generacion++;
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }

  @override
  Future<bool> abrirAjustes() => openAppSettings();
}
