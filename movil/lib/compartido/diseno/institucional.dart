import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class Institucional {
  static const cabecera = Color(0xFF20B72C);
  static const accion = Color(0xFF12682A);
  static const tinta = Color(0xFF171A18);
  static const secundario = Color(0xFF555B57);
  static const borde = Color(0xFFD4D8D5);
  static const neutro = Color(0xFFF0F2F0);
  static const error = Color(0xFFB42318);

  static final tema = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: accion,
      onPrimary: Colors.white,
      secondary: accion,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: tinta,
      onSurfaceVariant: secundario,
      outline: secundario,
      outlineVariant: borde,
      error: error,
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 23,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: tinta,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: tinta,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: tinta,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: tinta),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: tinta),
      bodySmall: TextStyle(fontSize: 12, height: 1.4, color: secundario),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: accion,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: cabecera,
      foregroundColor: tinta,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: tinta,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: cabecera,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: tinta,
      unselectedLabelColor: secundario,
      indicatorColor: accion,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: borde,
      tabAlignment: TabAlignment.start,
      labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
    ),
    dividerTheme: const DividerThemeData(color: borde, thickness: 1, space: 24),
    iconTheme: const IconThemeData(color: secundario, size: 22),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      hintStyle: const TextStyle(color: secundario),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: secundario),
        borderRadius: BorderRadius.circular(4),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: accion, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accion,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accion,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: accion),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accion,
        minimumSize: const Size(48, 48),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: borde),
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: accion),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: accion),
  );
}

class InterfazInstitucional extends StatelessWidget {
  const InterfazInstitucional({super.key, required this.builder});
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) => Theme(
    data: Institucional.tema,
    child: Builder(builder: builder),
  );
}

class EstadoInstitucional extends StatelessWidget {
  const EstadoInstitucional(this.texto, {super.key});
  final String texto;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Institucional.neutro,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Institucional.tinta),
      ),
    ),
  );
}

class DatoInstitucional extends StatelessWidget {
  const DatoInstitucional(this.etiqueta, this.valor, {super.key});
  final String etiqueta, valor;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Institucional.borde)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final titulo = Text(
          etiqueta,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Institucional.secundario,
            fontWeight: FontWeight.w600,
          ),
        );
        final contenido = Text(
          valor,
          style: Theme.of(context).textTheme.bodyMedium,
        );
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titulo, const SizedBox(height: 4), contenido],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 100, child: titulo),
            const SizedBox(width: 12),
            Expanded(child: contenido),
          ],
        );
      },
    ),
  );
}
