import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class Institucional {
  static const cabecera = Color(0xFF20B72C);
  static const accion = Color(0xFF12682A);
  static const tinta = Color(0xFF171A18);
  static const secundario = Color(0xFF555B57);
  static const borde = Color(0xFFD4D8D5);
  static const neutro = Color(0xFFF0F2F0);
  static const error = Color(0xFF941E15);

  static final tema = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: accion,
      onPrimary: Colors.white,
      secondary: accion,
      onSecondary: Colors.white,
      primaryContainer: Color(0xFFEAF4ED),
      onPrimaryContainer: accion,
      secondaryContainer: neutro,
      onSecondaryContainer: tinta,
      tertiary: accion,
      onTertiary: Colors.white,
      tertiaryContainer: neutro,
      onTertiaryContainer: tinta,
      surface: Colors.white,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: neutro,
      surfaceContainerHigh: neutro,
      surfaceContainerHighest: neutro,
      surfaceTint: Colors.transparent,
      onSurface: tinta,
      onSurfaceVariant: secundario,
      outline: secundario,
      outlineVariant: borde,
      error: error,
      errorContainer: Color(0xFFFBECEA),
      onErrorContainer: error,
      inverseSurface: tinta,
      onInverseSurface: Colors.white,
      inversePrimary: Color(0xFFEAF4ED),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: tinta,
      ),
      headlineSmall: TextStyle(
        fontSize: 21,
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
      bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: tinta),
      bodyMedium: TextStyle(fontSize: 15, height: 1.45, color: tinta),
      bodySmall: TextStyle(fontSize: 12, height: 1.4, color: secundario),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: accion,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: tinta,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: Border(
        top: BorderSide(color: cabecera, width: 3),
        bottom: BorderSide(color: borde),
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: tinta,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: accion,
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
        foregroundColor: secundario,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: Color(0xFF777F79)),
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
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: borde),
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: const Color(0xFFEAF4ED),
      height: 72,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? accion : secundario,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected) ? accion : secundario,
        ),
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: const ListTileThemeData(
      selectedColor: accion,
      selectedTileColor: Color(0xFFEAF4ED),
      iconColor: secundario,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: accion),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: accion),
  );
}

class BanderaSantaCruz extends StatelessWidget {
  const BanderaSantaCruz({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Bandera de Santa Cruz',
    image: true,
    child: Container(
      width: 26.4,
      height: 18,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF006B2E)),
      ),
      child: const Column(
        children: [
          Expanded(
            child: ColoredBox(
              color: Color(0xFF006B2E),
              child: SizedBox.expand(),
            ),
          ),
          Expanded(
            child: ColoredBox(color: Colors.white, child: SizedBox.expand()),
          ),
          Expanded(
            child: ColoredBox(
              color: Color(0xFF006B2E),
              child: SizedBox.expand(),
            ),
          ),
        ],
      ),
    ),
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

class CabeceraInstitucional extends StatelessWidget
    implements PreferredSizeWidget {
  const CabeceraInstitucional({
    super.key,
    required this.titulo,
    this.leading,
    this.actions = const [],
  });
  final String titulo;
  final Widget? leading;
  final List<Widget> actions;
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 64,
    // El borde del Material puede quedar detrás de la barra de estado nativa.
    // Pinta el filete dentro del área segura para que sea visible en Android.
    flexibleSpace: const IgnorePointer(
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: double.infinity,
            height: 3,
            child: ColoredBox(color: Institucional.cabecera),
          ),
        ),
      ),
    ),
    leading: leading,
    titleSpacing: 8,
    title: Row(
      children: [
        const BanderaSantaCruz(),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Correspondencia institucional',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Institucional.tinta,
                ),
              ),
              Text(
                titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Institucional.secundario,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    actions: actions,
  );
}

class EstadoInstitucional extends StatelessWidget {
  const EstadoInstitucional(this.texto, {super.key});
  final String texto;
  @override
  Widget build(BuildContext context) {
    final pendiente =
        texto.startsWith('Pendiente') || texto == 'Emisión pendiente';
    final activa = texto == 'Recibida' || texto == 'En atención';
    final fondo = pendiente
        ? const Color(0xFFFBF5E4)
        : activa
        ? const Color(0xFFEAF4ED)
        : Institucional.neutro;
    final tinta = pendiente
        ? const Color(0xFF654A13)
        : activa
        ? const Color(0xFF174E2B)
        : const Color(0xFF343A36);
    final borde = pendiente
        ? const Color(0xFFE4D3A4)
        : activa
        ? const Color(0xFFC4DCCC)
        : Institucional.borde;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: fondo,
          border: Border.all(color: borde),
        ),
        child: Text(
          texto,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: tinta, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
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
