import 'package:flutter/material.dart';
import 'package:t4_movil/services/camara_documento.dart';

class CamaraPrueba extends CamaraDocumento {
  ErrorCamara? error;
  final solicitudes = <bool>[];
  final fotos = <FotoDocumento>[];
  int ajustes = 0;
  @override
  Future<void> iniciar({required bool solicitarPermiso}) async {
    solicitudes.add(solicitarPermiso);
    if (error != null) throw error!;
  }

  @override
  Widget vista() => const ColoredBox(
    color: Colors.black,
    child: Center(child: Text('Cámara de prueba')),
  );
  @override
  Future<FotoDocumento> tomar() async => fotos.removeAt(0);
  @override
  Future<void> cerrar() async {}
  @override
  Future<bool> abrirAjustes() async {
    ajustes++;
    return true;
  }
}
