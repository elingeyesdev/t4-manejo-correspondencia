import 'package:flutter/material.dart';

import '../../compartido/api/laravel_api.dart';
import '../../compartido/diseno/sakai_theme.dart';
import '../../compartido/diseno/sakai_widgets.dart';
import '../camara/camara_documento.dart';
import '../adjuntos/adjuntos_documento.dart';
import '../recorrido/recorrido_documento.dart';

class DetalleLaravelPage extends StatefulWidget {
  const DetalleLaravelPage({
    super.key,
    required this.api,
    required this.id,
    this.crearCamara,
    this.puedeAdjuntar = true,
  });
  final ApiLaravel api;
  final String id;
  final bool puedeAdjuntar;
  final CamaraDocumento Function()? crearCamara;
  @override
  State<DetalleLaravelPage> createState() => _DetalleLaravelPageState();
}

class _DetalleLaravelPageState extends State<DetalleLaravelPage> {
  Map<String, dynamic>? _datos;
  List? _historial;
  String? _error;
  bool _cargando = false,
      _fotoPendiente = false,
      _subiendo = false,
      _operando = false,
      _solicitudPendiente = false,
      _saliendo = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (_cargando) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await widget.api.enviar(
        'GET',
        'documentos/${Uri.encodeComponent(widget.id)}',
      );
      if (!mounted) return;
      final hojaRecibida = datos['hoja'];
      final accionesRecibidas = datos['acciones_permitidas'];
      if (datos['id'] is! String ||
          (hojaRecibida != null && hojaRecibida is! Map) ||
          (accionesRecibidas != null &&
              (accionesRecibidas is! List ||
                  accionesRecibidas.any((a) => a is! String)))) {
        throw const ErrorLaravel(
          'No se pudieron interpretar los datos del documento.',
        );
      }
      setState(() => _datos = datos);
      if ((datos['hoja'] as Map?)?['id'] is String) {
        final historia = await widget.api.enviar(
          'GET',
          'documentos/${Uri.encodeComponent(widget.id)}/historial',
        );
        if (!mounted) return;
        if (historia['data'] is! List) {
          throw const ErrorLaravel(
            'No se pudo interpretar el historial del documento.',
          );
        }
        setState(() => _historial = historia['data'] as List);
      }
    } on ErrorLaravel catch (e) {
      if (mounted) {
        setState(() {
          _error = e.mensaje;
          if (e.estado == 403 || e.estado == 404) {
            _datos = null;
            _historial = null;
            _fotoPendiente = false;
            _subiendo = false;
            _operando = false;
            _solicitudPendiente = false;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _confirmado(Map<String, dynamic>? resultado) async {
    if (resultado != null && _datos != null) {
      final hoja = resultado['hoja'] as Map<String, dynamic>;
      setState(
        () => _datos = {
          ..._datos!,
          'estado': hoja['estado'],
          'hoja': {...?(_datos!['hoja'] as Map?), ...hoja},
          'acciones_permitidas': <String>[],
        },
      );
    }
    await _cargar();
  }

  Future<void> _volver() async {
    if (_saliendo) return;
    if (_subiendo || _operando) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _subiendo
                ? 'Espera a que termine la subida.'
                : 'Espera a que termine la operación.',
          ),
        ),
      );
      return;
    }
    if (_fotoPendiente || _solicitudPendiente) {
      final salir = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            _fotoPendiente
                ? '¿Descartar la foto pendiente?'
                : '¿Salir con una operación sin confirmar?',
          ),
          content: Text(
            _fotoPendiente
                ? 'La foto no se ha subido. Si sales de este documento, se descartará.'
                : 'Primero puedes reintentar para recuperar la confirmación. Si sales, revisa el historial antes de registrar una nueva operación.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Seguir aquí'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_fotoPendiente ? 'Descartar y salir' : 'Salir'),
            ),
          ],
        ),
      );
      if (salir != true || !mounted) return;
    }
    if (!mounted) return;
    setState(() => _saliendo = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final datos = _datos;
    final hoja = datos?['hoja'] as Map? ?? {};
    final acciones = datos?['acciones_permitidas'] as List? ?? [];
    final responsable = hoja['responsable'];
    final movimientos = _historial ?? datos?['movimientos'] as List? ?? [];
    final puedeAdjuntar =
        datos?['estado'] != 'CERRADA' &&
        (widget.puedeAdjuntar || acciones.contains('atender'));
    return PopScope(
      canPop:
          (!_fotoPendiente &&
              !_subiendo &&
              !_operando &&
              !_solicitudPendiente) ||
          _saliendo,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _volver();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalle de correspondencia'),
          leading: BackButton(onPressed: _volver),
          actions: [
            IconButton(
              tooltip: 'Actualizar documento',
              onPressed:
                  _cargando || _operando || _subiendo || _solicitudPendiente
                  ? null
                  : _cargar,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: datos == null
            ? Center(
                child: _cargando
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error ?? 'No se pudo abrir el documento.'),
                            TextButton(
                              onPressed: _cargar,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_cargando) const LinearProgressIndicator(),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton(
                      onPressed: _operando || _solicitudPendiente
                          ? null
                          : _cargar,
                      child: const Text('Reintentar actualización'),
                    ),
                  ],
                  Text(
                    (datos['asunto'] ?? '').toString(),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    (datos['codigo'] ?? '').toString(),
                    style: const TextStyle(color: Sakai.muted),
                  ),
                  const SizedBox(height: 10),
                  SakaiStatus((datos['estado'] ?? '').toString()),
                  const SizedBox(height: 20),
                  SakaiSection(
                    title: 'Información del documento',
                    icon: PrimeIcons.file,
                    child: Column(
                      children: [
                        SakaiField('Guía', datos['guia']),
                        const Divider(),
                        SakaiField('Remitente', datos['remitente']),
                        SakaiField('Fecha', sakaiDate(datos['fecha'])),
                        SakaiField('Tipo', (datos['tipo'] as Map?)?['name']),
                        SakaiField(
                          'Prioridad',
                          (datos['prioridad'] as Map?)?['name'],
                        ),
                        SakaiField(
                          'Unidad de registro',
                          (datos['unidad'] as Map?)?['name'],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SakaiSection(
                    title: 'Hoja de ruta',
                    icon: PrimeIcons.folder,
                    color: Sakai.violet,
                    background: Sakai.violetLight,
                    child: Column(
                      children: [
                        SakaiField('Código', hoja['codigo']),
                        if (responsable != null)
                          SakaiField(
                            'Responsable actual',
                            responsable is Map
                                ? responsable['nombre'] ?? responsable['name']
                                : responsable,
                          ),
                        if (hoja['unidad_vigente'] is Map)
                          SakaiField(
                            'Unidad vigente',
                            (hoja['unidad_vigente'] as Map)['nombre'],
                          ),
                        if (hoja['destino_pendiente_id'] != null)
                          const Text(
                            'La hoja espera confirmación de la unidad de destino.',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_fotoPendiente)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Sube o descarta la foto pendiente antes de cambiar el recorrido.',
                      ),
                    ),
                  RecorridoDocumento(
                    key: const ValueKey('recorrido'),
                    api: widget.api,
                    documento: datos,
                    bloqueado:
                        _cargando ||
                        _error != null ||
                        _subiendo ||
                        _fotoPendiente,
                    alConfirmar: _confirmado,
                    alOcuparse: (valor) {
                      if (mounted) setState(() => _operando = valor);
                    },
                    alPendiente: (valor) {
                      if (mounted) setState(() => _solicitudPendiente = valor);
                    },
                  ),
                  const SizedBox(height: 16),
                  IgnorePointer(
                    key: const ValueKey('adjuntos'),
                    ignoring: _operando || _solicitudPendiente || _cargando,
                    child: AdjuntosDocumento(
                      key: ValueKey(widget.id),
                      api: widget.api,
                      documentoId: widget.id,
                      codigo: (datos['codigo'] ?? datos['guia'] ?? '')
                          .toString(),
                      puedeAdjuntar: puedeAdjuntar,
                      crearCamara: widget.crearCamara,
                      alOcuparse: (valor) {
                        if (mounted) setState(() => _subiendo = valor);
                      },
                      alCambiar: (valor) {
                        if (mounted) setState(() => _fotoPendiente = valor);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SakaiSection(
                    title: 'Historial',
                    icon: PrimeIcons.clock,
                    color: Sakai.amber,
                    background: Sakai.amberLight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (movimientos.isEmpty)
                          const Text('Sin movimientos disponibles.'),
                        for (final movimiento in movimientos.whereType<Map>())
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (movimiento['accion'] ??
                                          movimiento['action'] ??
                                          '')
                                      .toString(),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                if (movimiento['actor'] is Map)
                                  Text(
                                    ((movimiento['actor'] as Map)['nombre'] ??
                                            (movimiento['actor']
                                                as Map)['name'] ??
                                            '')
                                        .toString(),
                                  ),
                                Text(
                                  sakaiDate(
                                    movimiento['fecha'] ??
                                        movimiento['occurred_at'],
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if ((movimiento['motivo'] ??
                                        movimiento['reason']) !=
                                    null)
                                  Text(
                                    (movimiento['motivo'] ??
                                            movimiento['reason'])
                                        .toString(),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: _volver,
                    child: const Text('Volver a mi bandeja'),
                  ),
                ],
              ),
      ),
    );
  }
}
