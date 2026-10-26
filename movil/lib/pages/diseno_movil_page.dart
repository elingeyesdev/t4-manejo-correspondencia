import 'package:flutter/material.dart';

enum PantallaDiseno {
  acceso('Inicio de sesión'),
  bandeja('Mi bandeja'),
  detalle('Documento e historial'),
  qr('Localizar por QR'),
  recepcion('Confirmar recepción'),
  adjuntos('Adjuntos'),
  camara('Capturar documento'),
  atencion('Registrar atención'),
  derivacion('Derivar hoja');

  const PantallaDiseno(this.titulo);
  final String titulo;
}

enum CasoDiseno {
  normal('Recorrido normal'),
  credenciales('Credenciales incorrectas'),
  conexion('Sin conexión'),
  sesion('Sesión vencida'),
  permisoCamara('Cámara sin permiso'),
  bandejaVacia('Bandeja vacía'),
  sinAcceso('Sin autorización'),
  conflicto('Documento actualizado');

  const CasoDiseno(this.titulo);
  final String titulo;
}

/// Prototipo visual aislado: no usa servicios, cámara, archivos ni credenciales.
class DisenoMovilPage extends StatefulWidget {
  const DisenoMovilPage({super.key});

  @override
  State<DisenoMovilPage> createState() => _DisenoMovilPageState();
}

class _DisenoMovilPageState extends State<DisenoMovilPage> {
  PantallaDiseno _pantalla = PantallaDiseno.acceso;
  final _scaffold = GlobalKey<ScaffoldState>();
  CasoDiseno _caso = CasoDiseno.normal;
  bool _captura = false;
  bool _recibida = false;
  bool _enAtencion = false;
  bool _derivada = false;
  bool _adjunto = false;
  String _destino = 'Secretaría';
  final _observacion = TextEditingController();
  final _motivo = TextEditingController();
  final _formAtencion = GlobalKey<FormState>();
  final _formDerivacion = GlobalKey<FormState>();

  @override
  void dispose() {
    _observacion.dispose();
    _motivo.dispose();
    super.dispose();
  }

  void _ir(PantallaDiseno pantalla) => setState(() => _pantalla = pantalla);

  String get _estado => _derivada || !_recibida
      ? 'Pendiente de recepción'
      : _enAtencion
      ? 'En atención'
      : 'Recibida';

  Widget _boton(String texto, VoidCallback accion, {bool principal = false}) =>
      principal
      ? FilledButton(onPressed: accion, child: Text(texto))
      : OutlinedButton(onPressed: accion, child: Text(texto));

  Widget _acciones(List<Widget> botones) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Wrap(spacing: 10, runSpacing: 10, children: botones),
  );

  Widget _aviso(String texto, {IconData icono = Icons.info_outline}) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5F2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(texto)),
          ],
        ),
      );

  Widget _titulo(String titulo, String subtitulo) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(subtitulo),
      ],
    ),
  );

  Widget _dato(String nombre, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nombre, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 3),
        Text(valor, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );

  Future<bool> _confirmar(String titulo, String contenido) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(titulo),
          content: Text(
            '$contenido\n\nConexión pendiente. Este recorrido no envía cambios al servidor.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar recorrido'),
            ),
          ],
        ),
      ) ??
      false;

  void _mensaje(String mensaje) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));

  bool _permitirOperacion() {
    if (!_recibida || _derivada) {
      _mensaje(
        'Primero recibe la hoja; no debe haber una derivación pendiente.',
      );
      return false;
    }
    if (_caso == CasoDiseno.conflicto) {
      _mensaje(
        'La hoja cambió. Revisa el detalle antes de intentar otra vez. No se aplicó ningún cambio.',
      );
      return false;
    }
    return true;
  }

  List<Widget> _casoEspecial() {
    if (_caso == CasoDiseno.credenciales) {
      return [
        _titulo(
          'No pudimos iniciar sesión',
          'Usuario o contraseña incorrectos.',
        ),
        _aviso(
          'Revisa tus datos e intenta nuevamente.',
          icono: Icons.lock_outline,
        ),
        _boton(
          'Volver al acceso',
          () => setState(() {
            _caso = CasoDiseno.normal;
            _pantalla = PantallaDiseno.acceso;
          }),
          principal: true,
        ),
      ];
    }
    if (_caso == CasoDiseno.conexion) {
      return [
        _titulo('No pudimos conectarnos', 'No se confirmó ningún cambio.'),
        _aviso(
          'Revisa tu conexión. La información del formulario se conserva.',
          icono: Icons.wifi_off,
        ),
        _boton(
          'Reintentar',
          () => setState(() => _caso = CasoDiseno.normal),
          principal: true,
        ),
      ];
    }
    if (_caso == CasoDiseno.sesion) {
      return [
        _titulo('Tu sesión venció', 'Vuelve a ingresar para continuar.'),
        _aviso(
          'No se confirmó ningún cambio pendiente.',
          icono: Icons.lock_outline,
        ),
        _boton(
          'Volver al acceso',
          () => setState(() {
            _caso = CasoDiseno.normal;
            _pantalla = PantallaDiseno.acceso;
          }),
          principal: true,
        ),
      ];
    }
    if (_caso == CasoDiseno.sinAcceso) {
      return [
        _titulo(
          'No tienes acceso',
          'Este documento está fuera de tus permisos.',
        ),
        _aviso(
          'Leer su QR no cambia la autorización.',
          icono: Icons.no_accounts_outlined,
        ),
        _boton(
          'Volver a mi bandeja',
          () => setState(() {
            _caso = CasoDiseno.normal;
            _pantalla = PantallaDiseno.bandeja;
          }),
        ),
      ];
    }
    if (_caso == CasoDiseno.permisoCamara &&
        (_pantalla == PantallaDiseno.camara ||
            _pantalla == PantallaDiseno.qr)) {
      return [
        _titulo(
          'Permiso de cámara necesario',
          'Activa el permiso para continuar.',
        ),
        _aviso(
          'No se crea un adjunto vacío ni se confirma una recepción.',
          icono: Icons.no_photography_outlined,
        ),
        _boton(
          'Ver cámara habilitada',
          () => setState(() => _caso = CasoDiseno.normal),
          principal: true,
        ),
      ];
    }
    return [];
  }

  Widget _historia(String accion, String actor) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.history),
    title: Text(accion),
    subtitle: Text(actor),
  );

  List<Widget> _contenido() {
    final especial = _casoEspecial();
    if (especial.isNotEmpty) return especial;
    switch (_pantalla) {
      case PantallaDiseno.acceso:
        return [
          _titulo('Iniciar sesión', 'Acceso de funcionarios'),
          const Text(
            'El acceso de usuarios está pendiente de conexión.',
            style: TextStyle(color: Color(0xFF667064)),
          ),
          const SizedBox(height: 20),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Usuario',
              prefixIcon: Icon(Icons.person_outline),
            ),
            enableSuggestions: false,
            autocorrect: false,
          ),
          const SizedBox(height: 16),
          const TextField(
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            enableSuggestions: false,
            autocorrect: false,
          ),
          _acciones([
            _boton(
              'Abrir bandeja',
              () => _ir(PantallaDiseno.bandeja),
              principal: true,
            ),
          ]),
        ];
      case PantallaDiseno.bandeja:
        return [
          _titulo('Mi bandeja', 'Unidad administrativa'),
          if (_caso == CasoDiseno.bandejaVacia)
            _aviso(
              'No tienes documentos asignados. Las nuevas asignaciones aparecerán aquí.',
              icono: Icons.inbox_outlined,
            )
          else
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: const Color(0xFFF4F5F2),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_estado),
                    const SizedBox(height: 10),
                    Text(
                      'Solicitud de información',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text('DOC-2026-001\nHR-2026-001'),
                    _acciones([
                      _boton(
                        'Ver documento',
                        () => _ir(PantallaDiseno.detalle),
                        principal: true,
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          _acciones([
            _boton('Localizar por QR', () => _ir(PantallaDiseno.qr)),
            _boton('Volver al acceso', () => _ir(PantallaDiseno.acceso)),
          ]),
        ];
      case PantallaDiseno.detalle:
        return [
          _titulo(
            'Solicitud de información',
            'Documento DOC-2026-001\nHoja HR-2026-001',
          ),
          _aviso(_estado),
          _dato(
            'Responsable activo',
            _recibida ? 'Unidad administrativa' : 'Recepción',
          ),
          _dato(
            'Destino pendiente',
            _derivada
                ? _destino
                : _recibida
                ? 'Ninguno'
                : 'Unidad administrativa',
          ),
          _dato('Remitente', 'Recepción institucional'),
          Text(
            'Historial del documento',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          _historia(
            'Registro de documento',
            'Recepción · Fecha del movimiento',
          ),
          _historia(
            'Derivación a Unidad administrativa',
            'Recepción · Fecha del movimiento',
          ),
          if (_recibida)
            _historia(
              'Recepción confirmada',
              'Unidad administrativa · Fecha del movimiento',
            ),
          if (_enAtencion)
            _historia(
              'Atención registrada',
              'Unidad administrativa · Fecha del movimiento',
            ),
          if (_derivada)
            _historia(
              'Derivación enviada',
              'Destino: $_destino · pendiente de recepción',
            ),
          _acciones([
            _boton('Ver adjuntos', () => _ir(PantallaDiseno.adjuntos)),
            if (!_recibida)
              _boton(
                'Confirmar recepción',
                () => _ir(PantallaDiseno.recepcion),
                principal: true,
              ),
            if (_recibida && !_derivada) ...[
              _boton(
                'Registrar atención',
                () => _ir(PantallaDiseno.atencion),
                principal: true,
              ),
              _boton('Capturar documento', () => _ir(PantallaDiseno.camara)),
              _boton('Derivar hoja', () => _ir(PantallaDiseno.derivacion)),
            ],
          ]),
          if (_derivada)
            _aviso(
              'Sigues siendo responsable hasta que el destino reciba. Durante la espera no se permite otra derivación ni atención.',
            ),
        ];
      case PantallaDiseno.qr:
        return [
          _titulo(
            'Localizar por QR',
            'Centra la referencia de la hoja de ruta.',
          ),
          _marco(Icons.qr_code_scanner, 'Centra el código dentro del encuadre'),
          _aviso(
            'Escanear solo localiza. No concede permisos ni confirma la recepción.',
          ),
          _boton(
            'Abrir hoja de ruta',
            () => _ir(PantallaDiseno.detalle),
            principal: true,
          ),
        ];
      case PantallaDiseno.recepcion:
        return [
          _titulo(
            'Confirmar recepción',
            '¿Recibiste físicamente este documento?',
          ),
          _dato('Hoja de ruta', 'HR-2026-001'),
          _dato('Origen', 'Recepción'),
          _dato('Destino', 'Unidad administrativa'),
          _aviso(
            _recibida
                ? 'El recorrido local ya muestra la recepción. No se repite.'
                : 'Esta acción está separada de la lectura del QR. El destinatario debe confirmar.',
          ),
          _acciones([
            _boton('Volver al detalle', () => _ir(PantallaDiseno.detalle)),
            if (!_recibida)
              _boton('Revisar recepción', () async {
                if (_caso == CasoDiseno.conflicto) {
                  _mensaje(
                    'La hoja cambió. Revisa el detalle antes de confirmar. No se aplicó ningún cambio.',
                  );
                  return;
                }
                final aceptar = await _confirmar(
                  'Revisar recepción',
                  'Tu unidad pasaría a ser responsable.',
                );
                if (!mounted || !aceptar) return;
                setState(() {
                  _recibida = true;
                  _pantalla = PantallaDiseno.detalle;
                });
              }, principal: true),
          ]),
        ];
      case PantallaDiseno.adjuntos:
        return [
          _titulo('Adjuntos', 'Documento DOC-2026-001'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('solicitud.pdf'),
            subtitle: const Text('PDF · Documento de referencia'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Solicitud de información'),
                content: const Text(
                  'Archivo pendiente de conexión. Aquí se abrirá el documento autorizado.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ),
          ),
          if (_adjunto)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.image_outlined),
              title: Text('captura-documento.jpg'),
              subtitle: Text('Imagen pendiente de envío'),
            ),
          _acciones([
            if (_recibida && !_derivada)
              _boton(
                'Agregar captura',
                () => _ir(PantallaDiseno.camara),
                principal: true,
              ),
            _boton('Volver al detalle', () => _ir(PantallaDiseno.detalle)),
          ]),
        ];
      case PantallaDiseno.camara:
        return [
          _titulo(
            _captura ? 'Revisar captura' : 'Capturar documento',
            'Documento DOC-2026-001',
          ),
          _marco(
            _captura ? Icons.description_outlined : Icons.photo_camera_outlined,
            _captura
                ? 'Solicitud de información\nRevisión de legibilidad'
                : 'Encuadra el documento completo',
          ),
          _aviso(
            _captura
                ? 'Revisa que sea legible. Puedes repetir antes de confirmar.'
                : 'La captura con cámara está pendiente de conexión.',
          ),
          _acciones([
            if (!_captura)
              _boton(
                'Ver previsualización',
                () => setState(() => _captura = true),
                principal: true,
              ),
            if (_captura) ...[
              _boton('Repetir', () => setState(() => _captura = false)),
              _boton('Revisar envío', () async {
                if (!_permitirOperacion()) return;
                final aceptar = await _confirmar(
                  'Revisar adjunto',
                  'La aplicación enviaría la captura y esperaría la confirmación del servidor.',
                );
                if (!mounted || !aceptar) return;
                setState(() {
                  _adjunto = true;
                  _captura = false;
                  _pantalla = PantallaDiseno.adjuntos;
                });
              }, principal: true),
            ],
          ]),
        ];
      case PantallaDiseno.atencion:
        return [
          _titulo('Registrar atención', 'Hoja HR-2026-001'),
          Form(
            key: _formAtencion,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _observacion,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Observación',
                    alignLabelWithHint: true,
                    hintText: 'Describe la atención realizada',
                  ),
                  validator: (valor) => valor == null || valor.trim().isEmpty
                      ? 'Escribe una observación.'
                      : null,
                ),
                _acciones([
                  _boton('Cancelar', () => _ir(PantallaDiseno.detalle)),
                  _boton('Revisar atención', () async {
                    if (!_formAtencion.currentState!.validate() ||
                        !_permitirOperacion()) {
                      return;
                    }
                    final aceptar = await _confirmar(
                      'Revisar atención',
                      'Se añadiría un movimiento con autor y hora del servidor.',
                    );
                    if (!mounted || !aceptar) return;
                    setState(() {
                      _enAtencion = true;
                      _pantalla = PantallaDiseno.detalle;
                    });
                  }, principal: true),
                ]),
              ],
            ),
          ),
          _aviso(
            'Solo el responsable de una hoja recibida puede registrar atención. Una hoja pendiente o cerrada no la acepta.',
          ),
        ];
      case PantallaDiseno.derivacion:
        return [
          _titulo('Derivar hoja', 'Hoja HR-2026-001'),
          Form(
            key: _formDerivacion,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _destino,
                  decoration: const InputDecoration(
                    labelText: 'Destino autorizado',
                  ),
                  isExpanded: true,
                  items: ['Secretaría', 'Unidad técnica']
                      .map(
                        (valor) =>
                            DropdownMenuItem(value: valor, child: Text(valor)),
                      )
                      .toList(),
                  onChanged: (valor) {
                    if (valor != null) setState(() => _destino = valor);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _motivo,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motivo',
                    alignLabelWithHint: true,
                    hintText: 'Explica por qué se deriva',
                  ),
                  validator: (valor) => valor == null || valor.trim().isEmpty
                      ? 'Escribe el motivo de derivación.'
                      : null,
                ),
                _acciones([
                  _boton('Cancelar', () => _ir(PantallaDiseno.detalle)),
                  _boton('Revisar derivación', () async {
                    if (!_formDerivacion.currentState!.validate() ||
                        !_permitirOperacion()) {
                      return;
                    }
                    final aceptar = await _confirmar(
                      'Revisar derivación',
                      'Destino: $_destino.\nMotivo: ${_motivo.text.trim()}\nEl responsable se conserva hasta la recepción del destino.',
                    );
                    if (!mounted || !aceptar) return;
                    setState(() {
                      _derivada = true;
                      _pantalla = PantallaDiseno.detalle;
                    });
                  }, principal: true),
                ]),
              ],
            ),
          ),
        ];
    }
  }

  Widget _marco(IconData icono, String texto) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F5F2),
      border: Border.all(color: const Color(0xFFC8D5C0)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Icon(icono, size: 64, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(texto, textAlign: TextAlign.center),
      ],
    ),
  );

  String get _requisito => switch (_pantalla) {
    PantallaDiseno.acceso => 'HU-02 / CU-01 · acceso y sesión',
    PantallaDiseno.bandeja ||
    PantallaDiseno.detalle => 'HU-12 / CU-08 · consulta autorizada e historial',
    PantallaDiseno.qr || PantallaDiseno.recepcion =>
      'HU-10 / CU-06 · localizar y confirmar recepción',
    PantallaDiseno.adjuntos ||
    PantallaDiseno.camara => 'HU-07 / CU-04 · captura y adjuntos',
    PantallaDiseno.atencion => 'HU-11 / CU-07 · atención y observaciones',
    PantallaDiseno.derivacion => 'HU-09 / CU-05 · derivación autorizada',
  };

  void _reiniciar() => setState(() {
    _pantalla = PantallaDiseno.acceso;
    _caso = CasoDiseno.normal;
    _captura = _recibida = _enAtencion = _derivada = _adjunto = false;
    _observacion.clear();
    _motivo.clear();
    _destino = 'Secretaría';
  });

  void _revisar() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Revisión de pantallas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<PantallaDiseno>(
                initialValue: _pantalla,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Ir a una pantalla',
                ),
                items: PantallaDiseno.values
                    .map(
                      (p) => DropdownMenuItem(value: p, child: Text(p.titulo)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  Navigator.pop(sheetContext);
                  _ir(value);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CasoDiseno>(
                initialValue: _caso,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Estado de la pantalla',
                ),
                items: CasoDiseno.values
                    .map(
                      (c) => DropdownMenuItem(value: c, child: Text(c.titulo)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  Navigator.pop(sheetContext);
                  setState(() => _caso = value);
                },
              ),
              const SizedBox(height: 20),
              Text(_requisito, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              const Text(
                'Datos de referencia para revisar el diseño. Las operaciones todavía no se conectan al servidor.',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _reiniciar();
                },
                icon: const Icon(Icons.restart_alt),
                label: const Text('Volver al inicio del recorrido'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _volver() {
    if (_scaffold.currentState?.isDrawerOpen ?? false) {
      _scaffold.currentState!.closeDrawer();
      return;
    }
    if (_caso != CasoDiseno.normal) {
      setState(() => _caso = CasoDiseno.normal);
    } else if (_pantalla == PantallaDiseno.acceso) {
      Navigator.pop(context);
    } else {
      _ir(switch (_pantalla) {
        PantallaDiseno.bandeja => PantallaDiseno.acceso,
        PantallaDiseno.detalle || PantallaDiseno.qr => PantallaDiseno.bandeja,
        _ => PantallaDiseno.detalle,
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: _pantalla == PantallaDiseno.acceso && _caso == CasoDiseno.normal,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _volver();
    },
    child: Scaffold(
      key: _scaffold,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: _volver,
        ),
        title: Text(
          _pantalla.titulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Revisar pantallas',
            icon: const Icon(Icons.tune),
            onPressed: _revisar,
          ),
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Secciones',
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Gestión documental',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              for (final p in PantallaDiseno.values)
                ListTile(
                  leading: Icon(switch (p) {
                    PantallaDiseno.acceso => Icons.person_outline,
                    PantallaDiseno.bandeja => Icons.inbox_outlined,
                    PantallaDiseno.detalle => Icons.description_outlined,
                    PantallaDiseno.qr => Icons.qr_code_scanner,
                    PantallaDiseno.recepcion => Icons.task_alt,
                    PantallaDiseno.adjuntos => Icons.attach_file,
                    PantallaDiseno.camara => Icons.photo_camera_outlined,
                    PantallaDiseno.atencion => Icons.edit_note,
                    PantallaDiseno.derivacion =>
                      Icons.forward_to_inbox_outlined,
                  }),
                  title: Text(p.titulo),
                  selected: _pantalla == p,
                  onTap: () {
                    Navigator.pop(context);
                    _ir(p);
                  },
                ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          size: 15,
                          color: Color(0xFF75806E),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Conexión pendiente · cambios locales',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFF75806E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._contenido(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
