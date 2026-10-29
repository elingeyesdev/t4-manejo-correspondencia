import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'theme/sakai_theme.dart';
import 'widgets/sakai_widgets.dart';
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

void main() {
  LicenseRegistry.addLicense(() async* {
    for (final entry in {
      'Sakai / PrimeVue': 'Sakai-MIT.txt',
      'PrimeIcons': 'PrimeIcons-MIT.txt',
    }.entries) {
      yield LicenseEntryWithLineBreaks([
        entry.key,
      ], await rootBundle.loadString('assets/licenses/${entry.value}'));
    }
  });
  runApp(const CorrespondenciaApp());
}

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
    theme: Sakai.theme,
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
  static const _ordenPestanas = [0, 3, 1, 4];
  final _deslizador = PageController();
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
  void _mostrar(int pagina) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _pagina = pagina;
      _visitadas.add(pagina);
    });
    if (widget.sesion != null && pagina != 2 && _deslizador.hasClients) {
      // Los botones saltan directamente sin cargar pestañas intermedias.
      _deslizador.jumpToPage(_ordenPestanas.indexOf(pagina));
    }
  }

  void _alDeslizar(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _pagina = _ordenPestanas[index];
      _visitadas.add(_pagina);
    });
  }

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
    _deslizador.dispose();
    super.dispose();
  }

  void _navegar(int pagina) {
    Navigator.pop(context);
    _mostrar(pagina);
  }

  String get _iniciales {
    final partes = (widget.sesion?.nombre ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2);
    return partes.isEmpty
        ? 'CU'
        : partes
              .map((p) => String.fromCharCode(p.runes.first))
              .join()
              .toUpperCase();
  }

  Widget _cuenta() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('Mi cuenta', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 20),
      SakaiSection(
        title: 'Cuenta institucional',
        icon: PrimeIcons.user,
        child: Column(
          children: [
            SakaiField('Nombre', widget.sesion!.nombre),
            SakaiField('Correo', widget.sesion!.usuario?['email']),
            SakaiField('Rol', widget.sesion!.rol),
          ],
        ),
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: widget.sesion!.ocupada ? null : () => widget.sesion!.salir(),
        icon: const Icon(Icons.logout),
        label: const Text('Cerrar sesión'),
      ),
      const SizedBox(height: 16),
      ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('Acerca de la aplicación'),
        subtitle: const Text('Sakai / PrimeVue · PrimeIcons'),
        onTap: () => showAboutDialog(
          context: context,
          applicationName: 'Correspondencia',
          applicationVersion: '1.0.0',
          applicationLegalese: 'Interfaz Flutter adaptada de Sakai / PrimeVue. Iconos PrimeIcons. Recursos originales bajo licencia MIT.',
          children: [
            const SelectableText(
              'Fuente: https://github.com/primefaces/sakai-vue',
            ),
          ],
        ),
      ),
      if (widget.sesion!.mensaje != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            widget.sesion!.mensaje!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ],
  );

  Widget _seccion(int pagina) => switch (pagina) {
    0 => HomePage(
      nombre: widget.sesion?.nombre ?? '',
      onConsultar: () => _mostrar(1),
      onVerDiseno: _verDiseno,
      onNuevoRegistro: () => _mostrar(2),
      puedeRegistrar: _puedeRegistrar,
      onBandeja: widget.sesion == null ? null : () => _mostrar(3),
    ),
    1 =>
      _visitadas.contains(1)
          ? ConsultaEnvioPage(servicio: _servicio)
          : const SizedBox.shrink(),
    3 =>
      _visitadas.contains(3)
          ? BandejaLaravelPage(api: widget.sesion!.api)
          : const SizedBox.shrink(),
    4 => _cuenta(),
    _ => const SizedBox.shrink(),
  };

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
            Icon(PrimeIcons.folder, size: 24, color: Sakai.green),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Correspondencia',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          if (widget.sesion != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                tooltip: 'Mi cuenta',
                onPressed: () => _mostrar(4),
                icon: CircleAvatar(
                  radius: 18,
                  backgroundColor: Sakai.mint,
                  child: Text(
                    _iniciales,
                    style: const TextStyle(
                      color: Sakai.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: widget.sesion == null || _pagina == 2
          ? null
          : NavigationBar(
              selectedIndex: switch (_pagina) {
                3 => 1,
                1 => 2,
                4 => 3,
                _ => 0,
              },
              onDestinationSelected: (index) => _mostrar(_ordenPestanas[index]),
              destinations: const [
                NavigationDestination(
                  icon: Icon(PrimeIcons.home),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(PrimeIcons.inbox),
                  label: 'Bandeja',
                ),
                NavigationDestination(
                  icon: Icon(PrimeIcons.search),
                  label: 'Consulta',
                ),
                NavigationDestination(
                  icon: Icon(PrimeIcons.user),
                  label: 'Cuenta',
                ),
              ],
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
          index: _pagina == 2 ? 1 : 0,
          children: [
            if (widget.sesion != null)
              PageView(
                key: const ValueKey('secciones-deslizables'),
                controller: _deslizador,
                onPageChanged: _alDeslizar,
                children: [
                  for (final pagina in _ordenPestanas)
                    _SeccionConservada(
                      key: ValueKey(pagina),
                      child: _seccion(pagina),
                    ),
                ],
              )
            else
              IndexedStack(
                index: _pagina == 1 ? 1 : 0,
                children: [_seccion(0), _seccion(1)],
              ),
            !_visitadas.contains(2)
                ? const SizedBox.shrink()
                : widget.sesion != null
                ? RegistroLaravelPage(api: widget.sesion!.api)
                : RegistroCorrespondenciaPage(api: _registro),
          ],
        ),
      ),
    ),
  );
}

/// Mantiene formularios, búsqueda y posición de desplazamiento entre pestañas.
class _SeccionConservada extends StatefulWidget {
  const _SeccionConservada({super.key, required this.child});
  final Widget child;
  @override
  State<_SeccionConservada> createState() => _SeccionConservadaState();
}

class _SeccionConservadaState extends State<_SeccionConservada>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
