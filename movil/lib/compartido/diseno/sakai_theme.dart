import 'package:flutter/material.dart';

import 'institucional.dart';

/// Compatibilidad para las pantallas anteriores: toda la app usa la misma
/// paleta institucional. PrimeIcons conserva su licencia MIT original.
abstract final class Sakai {
  static const emerald = Institucional.cabecera;
  static const green = Institucional.accion;
  static const mint = Color(0xFFEAF4ED);
  static const background = Institucional.neutro;
  static const ink = Institucional.tinta;
  static const muted = Institucional.secundario;
  static const border = Institucional.borde;
  static const blue = green;
  static const blueLight = mint;
  static const violet = green;
  static const violetLight = mint;
  static const amber = Color(0xFF654A13);
  static const amberLight = Color(0xFFFBF5E4);
  static const cyan = green;
  static const cyanLight = mint;

  static ThemeData get theme => Institucional.tema;
}

/// Glifos de PrimeIcons originales, incluidos localmente bajo licencia MIT.
abstract final class PrimeIcons {
  static const home = IconData(0xe925, fontFamily: 'PrimeIcons');
  static const inbox = IconData(0xe961, fontFamily: 'PrimeIcons');
  static const search = IconData(0xe908, fontFamily: 'PrimeIcons');
  static const file = IconData(0xe958, fontFamily: 'PrimeIcons');
  static const folder = IconData(0xe963, fontFamily: 'PrimeIcons');
  static const user = IconData(0xe939, fontFamily: 'PrimeIcons');
  static const plus = IconData(0xe90d, fontFamily: 'PrimeIcons');
  static const chevronRight = IconData(0xe901, fontFamily: 'PrimeIcons');
  static const clock = IconData(0xe940, fontFamily: 'PrimeIcons');
  static const check = IconData(0xe90a, fontFamily: 'PrimeIcons');
}
