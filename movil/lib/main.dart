import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pages/consulta_envio_page.dart';
import 'pages/diseno_movil_page.dart';
import 'pages/home_page.dart';
import 'pages/acceso_laravel_page.dart';
import 'pages/bandeja_laravel_page.dart';
import 'pages/registro_laravel_page.dart';
import 'services/laravel_api.dart';
import 'services/sesion_controller.dart';
import 'pages/registro_correspondencia_page.dart';
import 'services/consulta_envio_service.dart';
import 'services/correspondencia_api.dart';

void main() => runApp(const CorrespondenciaApp());

class CorrespondenciaApp extends StatelessWidget {
  const CorrespondenciaApp({
    super.key,
    this.servicio,
    this.apiRegistro,
    this.sesion,
  });
  final ConsultaEnvioService? servicio;
  final CorrespondenciaApi? apiRegistro;
  final SesionController? sesion;
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
      scaffoldBackgroundColor: const Color(0xFFF7F8F5),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE4E8DF)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF7F8F5),
        foregroundColor: Color(0xFF263320),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCDD5C7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF456B2F), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF456B2F),
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF456B2F),
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: Color(0xFFCDD5C7)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
    home: servicio != null || apiRegistro != null
        ? PantallaPrincipal(servicio: servicio, apiRegistro: apiRegistro)
        : PuertaSesion(sesion: sesion),
  );
}

class PuertaSesion extends StatefulWidget {
  const PuertaSesion({super.key, this.sesion});
  final SesionController? sesion;
  @override
  State<PuertaSesion> createState() => _PuertaSesionState();
}

class _PuertaSesionState extends State<PuertaSesion> {
  late final SesionController _sesion;
  final _navegador = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    _sesion = widget.sesion ?? SesionController(api: ApiLaravel());
    _sesion.restaurar();
  }

  @override
  void dispose() {
    if (widget.sesion == null) {
      _sesion.api.close();
      _sesion.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _sesion,
    builder: (context, _) {
      if (!_sesion.inicializada) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return _sesion.autenticada
          ? NavigatorPopHandler(
              onPopWithResult: (_) => _navegador.currentState?.maybePop(),
              child: Navigator(
                key: _navegador,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) =>
                      PantallaPrincipal(servicio: null, sesion: _sesion),
                ),
              ),
            )
          : AccesoLaravelPage(sesion: _sesion);
    },
  );
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({
    super.key,
    required this.servicio,
    this.apiRegistro,
    this.sesion,
  });
  final ConsultaEnvioService? servicio;
  final CorrespondenciaApi? apiRegistro;
  final SesionController? sesion;
  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _pagina = 0;
  final _scaffold = GlobalKey<ScaffoldState>();
  bool _confirmandoSalida = false;

  Future<void> _volver() async {
    if (_scaffold.currentState?.isDrawerOpen ?? false) {
      _scaffold.currentState!.closeDrawer();
      return;
    }
    if (_pagina != 0) {
      _mostrar(0);
      return;
    }
    if (_confirmandoSalida) return;
    _confirmandoSalida = true;
    final salir = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir de Correspondencia?'),
        content: const Text(
          'Puedes volver a abrir la aplicación sin cerrar tu sesión.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    _confirmandoSalida = false;
    if (mounted && salir == true) await SystemNavigator.pop();
  }

  final _visitadas = <int>{0};
  bool get _puedeRegistrar => widget.sesion?.puedeRegistrar ?? true;
  void _mostrar(int pagina) => setState(() {
    _pagina = pagina;
    _visitadas.add(pagina);
  });
  late final ConsultaEnvioService _servicio;
  late final CorrespondenciaApi _registro;

  @override
  void initState() {
    super.initState();
    _servicio = widget.servicio ?? ConsultaEnvioApi(api: widget.sesion?.api);
    _registro = widget.apiRegistro ?? CorrespondenciaApi();
  }

  @override
  void dispose() {
    if (widget.servicio == null && _servicio is ConsultaEnvioApi) {
      _servicio.close();
    }
    if (widget.apiRegistro == null) _registro.close();
    super.dispose();
  }

  void _navegar(int pagina) {
    Navigator.pop(context);
    _mostrar(pagina);
  }

  void _verDiseno() {
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const DisenoMovilPage()));
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _volver();
    },
    child: Scaffold(
      key: _scaffold,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.markunread_mailbox_outlined, size: 24),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Correspondencia',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
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
              if (_puedeRegistrar)
                ListTile(
                  leading: const Icon(Icons.note_add_outlined),
                  title: const Text('Nueva correspondencia'),
                  selected: _pagina == 2,
                  onTap: () => _navegar(2),
                ),
              if (widget.sesion != null)
                ListTile(
                  leading: const Icon(Icons.inbox_outlined),
                  title: const Text('Mi bandeja'),
                  selected: _pagina == 3,
                  onTap: () => _navegar(3),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.design_services_outlined),
                title: const Text('Gestión documental'),
                subtitle: const Text('Diseño de próximas pantallas'),
                onTap: () {
                  Navigator.pop(context);
                  _verDiseno();
                },
              ),
              if (widget.sesion != null) ...[
                const Divider(),
                ListTile(
                  title: Text(widget.sesion!.nombre),
                  subtitle: Text(widget.sesion!.rol),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Cerrar sesión'),
                  enabled: !widget.sesion!.ocupada,
                  onTap: () {
                    Navigator.pop(context);
                    widget.sesion!.salir();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _pagina,
          children: [
            HomePage(
              onConsultar: () => _mostrar(1),
              onVerDiseno: _verDiseno,
              onNuevoRegistro: () => _mostrar(2),
              puedeRegistrar: _puedeRegistrar,
              onBandeja: widget.sesion == null ? null : () => _mostrar(3),
            ),
            _visitadas.contains(1)
                ? ConsultaEnvioPage(servicio: _servicio)
                : const SizedBox.shrink(),
            !_visitadas.contains(2)
                ? const SizedBox.shrink()
                : widget.sesion != null
                ? RegistroLaravelPage(api: widget.sesion!.api)
                : RegistroCorrespondenciaPage(api: _registro),
            if (widget.sesion != null)
              _visitadas.contains(3)
                  ? BandejaLaravelPage(api: widget.sesion!.api)
                  : const SizedBox.shrink(),
          ],
        ),
      ),
    ),
  );
}
