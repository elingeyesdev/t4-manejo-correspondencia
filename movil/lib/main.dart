import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pages/consulta_envio_page.dart';
import 'pages/home_page.dart';
import 'services/consulta_envio_service.dart';

void main() => runApp(const CorrespondenciaApp());

class CorrespondenciaApp extends StatelessWidget {
  const CorrespondenciaApp({
    super.key,
    this.servicio = const ConsultaEnvioApi(),
  });
  final ConsultaEnvioService servicio;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Sistema de Correspondencia',
    debugShowCheckedModeBanner: false,
    locale: const Locale('es'),
    supportedLocales: const [Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8BC34A))
          .copyWith(
            primary: const Color(0xFF456B2F),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: const Color(0xFF202020),
          ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF456B2F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF4F5F2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF8BC34A),
          foregroundColor: const Color(0xFF202020),
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ),
    home: PantallaPrincipal(servicio: servicio),
  );
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key, required this.servicio});
  final ConsultaEnvioService servicio;
  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _pagina = 0;
  void _navegar(int pagina) {
    Navigator.pop(context);
    setState(() => _pagina = pagina);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Sistema de Correspondencia',
        style: TextStyle(fontSize: 17),
      ),
    ),
    drawer: Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 16, 20),
              child: Text('Correspondencia', style: TextStyle(fontSize: 20)),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Inicio'),
              selected: _pagina == 0,
              onTap: () => _navegar(0),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Consultar envío'),
              selected: _pagina == 1,
              onTap: () => _navegar(1),
            ),
          ],
        ),
      ),
    ),
    body: SafeArea(
      child: IndexedStack(
        index: _pagina,
        children: [
          HomePage(onConsultar: () => setState(() => _pagina = 1)),
          ConsultaEnvioPage(servicio: widget.servicio),
        ],
      ),
    ),
  );
}
