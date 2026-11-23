import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'compartido/diseno/sakai_theme.dart';
import 'compartido/diseno/sakai_widgets.dart';
import 'compartido/diseno/institucional.dart';
import 'funciones/consultar_envio/consulta_envio_page.dart';
import 'funciones/inicio/home_page.dart';
import 'funciones/iniciar_sesion/acceso_laravel_page.dart';
import 'funciones/mi_bandeja/bandeja_laravel_page.dart';
import 'funciones/notas_internas/bandeja_notas_page.dart';
import 'funciones/nueva_correspondencia/registro_laravel_page.dart';
import 'compartido/api/laravel_api.dart';
import 'funciones/iniciar_sesion/sesion_controller.dart';
import 'historico/registro_correspondencia_page.dart';
import 'funciones/consultar_envio/consulta_envio_service.dart';
import 'historico/correspondencia_api.dart';
import 'funciones/notificaciones/avisos_controller.dart';
import 'funciones/notificaciones/avisos_api.dart';
import 'funciones/notificaciones/avisos_page.dart';
import 'funciones/notificaciones/transporte_push.dart';
import 'funciones/notas_internas/detalle_nota_page.dart';

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
    this.push,
  });
  final ConsultaEnvioService? servicio;
  final CorrespondenciaApi? apiRegistro;
  final SesionController? sesion;
  final TransportePush? push;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Sistema de Correspondencia',
    debugShowCheckedModeBanner: false,
    locale: const Locale('es'),
    supportedLocales: const [Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: Institucional.tema,
    home: servicio != null || apiRegistro != null
        ? PantallaPrincipal(servicio: servicio, apiRegistro: apiRegistro)
        : PuertaSesion(sesion: sesion, push: push),
  );
}

class PuertaSesion extends StatefulWidget {
  const PuertaSesion({super.key, this.sesion, this.push});
  final SesionController? sesion;
  final TransportePush? push;
  @override
  State<PuertaSesion> createState() => _PuertaSesionState();
}

class _PuertaSesionState extends State<PuertaSesion>
    with WidgetsBindingObserver {
  late final SesionController _sesion;
  late final AvisosController _avisos;
  bool _abriendoAviso = false;
  String? _mostrado;
  final _navegador = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    _sesion = widget.sesion ?? SesionController(api: ApiLaravel());
    WidgetsBinding.instance.addObserver(this);
    _avisos = AvisosController(
      sesion: _sesion,
      push: widget.push ?? FirebasePush(),
    );
    _avisos.addListener(_nuevoAviso);
    unawaited(_avisos.iniciar());
    _sesion.restaurar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _avisos.reanudar();
  }

  void _nuevoAviso() {
    final id = _avisos.avisoVisible;
    if (id == null) {
      _mostrado = null;
      return;
    }
    if (_mostrado == id) return;
    _mostrado = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sesion.autenticada || _avisos.avisoVisible != id) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tienes una nueva tarea'),
          action: SnackBarAction(
            label: 'Abrir',
            onPressed: () => _avisos.abrir(id),
          ),
        ),
      );
    });
  }

  Future<void> _abrirAviso() async {
    final id = _avisos.pendiente;
    final navegador = _navegador.currentState;
    if (!mounted ||
        !_sesion.autenticada ||
        id == null ||
        navegador == null ||
        _abriendoAviso) {
      return;
    }
    _abriendoAviso = true;
    _avisos.consumido(id);
    final token = _sesion.api.token, cuenta = _sesion.api.cuentaId;
    var abierta = false;
    try {
      final nota = await AvisosApi(_sesion.api).resolver(id);
      if (!mounted ||
          token != _sesion.api.token ||
          cuenta != _sesion.api.cuentaId) {
        return;
      }
      unawaited(
        navegador.push<void>(
          MaterialPageRoute(
            builder: (_) => DetalleNotaPage(
              api: _sesion.api,
              id: nota.id,
              puedeAdjuntar: _sesion.puedeRegistrar,
            ),
          ),
        ),
      );
      abierta = true;
    } on ErrorLaravel catch (e) {
      if (!mounted ||
          token != _sesion.api.token ||
          cuenta != _sesion.api.cuentaId) {
        return;
      }
      if (!navegador.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            {403, 404}.contains(e.estado)
                ? 'Esta notificación ya no está disponible.'
                : e.mensaje,
          ),
        ),
      );
    } finally {
      _abriendoAviso = false;
      if (mounted && _avisos.pendiente != null) unawaited(_abrirAviso());
    }
    if (!abierta ||
        !mounted ||
        token != _sesion.api.token ||
        cuenta != _sesion.api.cuentaId) {
      return;
    }
    try {
      await AvisosApi(_sesion.api).leer(id);
    } on ErrorLaravel {
      /* Se recupera al volver al centro. */
    }
    if (mounted &&
        token == _sesion.api.token &&
        cuenta == _sesion.api.cuentaId) {
      unawaited(_avisos.refrescar());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _avisos.removeListener(_nuevoAviso);
    _avisos.dispose();
    if (widget.sesion == null) {
      _sesion.api.close();
      _sesion.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_sesion, _avisos]),
    builder: (context, _) {
      if (!_sesion.inicializada) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (_sesion.autenticada && _avisos.pendiente != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _abrirAviso());
      }
      return _sesion.autenticada
          ? NavigatorPopHandler(
              onPopWithResult: (_) => _navegador.currentState?.maybePop(),
              child: Navigator(
                key: _navegador,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => PantallaPrincipal(
                    servicio: null,
                    sesion: _sesion,
                    avisos: _avisos,
                  ),
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
    this.avisos,
  });
  final ConsultaEnvioService? servicio;
  final CorrespondenciaApi? apiRegistro;
  final SesionController? sesion;
  final AvisosController? avisos;
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
        subtitle: const Text('Interfaz institucional · Santa Cruz'),
        onTap: () => showAboutDialog(
          context: context,
          applicationName: 'Correspondencia',
          applicationVersion: '1.0.0',
          applicationLegalese: 'Interfaz institucional implementada en Flutter. Iconos PrimeIcons y componentes adaptados originalmente de Sakai bajo licencia MIT.',
          children: [
            const SelectableText(
              'Diseño compartido con la web institucional. Los créditos y licencias de terceros están disponibles en Licencias.',
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

  Future<void> _abrirNotas() async {
    final sesion = widget.sesion;
    if (sesion == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BandejaNotasPage(
          api: sesion.api,
          puedeAdjuntar: sesion.puedeRegistrar,
        ),
      ),
    );
  }

  void _abrirAvisos() {
    if (widget.avisos == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AvisosPage(controller: widget.avisos!),
      ),
    );
  }

  Widget _seccion(int pagina) => switch (pagina) {
    0 => HomePage(
      nombre: widget.sesion?.nombre ?? '',
      onConsultar: () => _mostrar(1),
      onNuevoRegistro: () => _mostrar(2),
      puedeRegistrar: _puedeRegistrar,
      onBandeja: widget.sesion == null ? null : () => _mostrar(3),
      onNotas: widget.sesion == null ? null : _abrirNotas,
    ),
    1 =>
      _visitadas.contains(1)
          ? ConsultaEnvioPage(servicio: _servicio)
          : const SizedBox.shrink(),
    3 =>
      _visitadas.contains(3)
          ? BandejaLaravelPage(
              api: widget.sesion!.api,
              puedeAdjuntar: widget.sesion!.puedeRegistrar,
              activa: _pagina == 3,
            )
          : const SizedBox.shrink(),
    4 => _cuenta(),
    _ => const SizedBox.shrink(),
  };

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _volver();
    },
    child: Scaffold(
      key: _scaffold,
      appBar: CabeceraInstitucional(
        titulo: switch (_pagina) {
          1 => 'Consultar envío',
          2 => 'Nueva correspondencia',
          3 => 'Mi bandeja',
          4 => 'Mi cuenta',
          _ => 'Inicio',
        },
        actions: [
          if (widget.avisos != null)
            AnimatedBuilder(
              animation: widget.avisos!,
              builder: (context, _) => IconButton(
                tooltip: 'Avisos',
                onPressed: _abrirAvisos,
                icon: Badge(
                  isLabelVisible: (widget.avisos!.pagina?.noLeidas ?? 0) > 0,
                  label: Text('${widget.avisos!.pagina?.noLeidas ?? 0}'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              ),
            ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BanderaSantaCruz(),
                    SizedBox(height: 12),
                    Text(
                      'Correspondencia institucional',
                      style: TextStyle(fontSize: 20),
                    ),
                  ],
                ),
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
              if (widget.sesion != null) ...[
                if (widget.avisos != null)
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Avisos'),
                    onTap: () {
                      Navigator.pop(context);
                      _abrirAvisos();
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Notas internas'),
                  subtitle: const Text('Revisar, recibir, atender y copias'),
                  onTap: () {
                    Navigator.pop(context);
                    _abrirNotas();
                  },
                ),
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
        child: Column(
          children: [
            Expanded(
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
