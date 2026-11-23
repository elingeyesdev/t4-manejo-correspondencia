import 'package:flutter/material.dart';

class DestinoInicio extends InheritedWidget {
  const DestinoInicio({super.key, required this.volver, required super.child});

  final VoidCallback volver;

  static void abrir(BuildContext context) {
    final destino = context.getInheritedWidgetOfExactType<DestinoInicio>();
    if (destino != null) {
      destino.volver();
    } else {
      Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    }
  }

  @override
  bool updateShouldNotify(DestinoInicio oldWidget) =>
      volver != oldWidget.volver;
}
