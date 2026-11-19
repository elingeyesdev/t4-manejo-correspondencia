import 'package:flutter/material.dart';

import '../../compartido/api/laravel_api.dart';
import '../../compartido/diseno/sakai_widgets.dart';
import '../../compartido/diseno/institucional.dart';
import '../mi_bandeja/detalle_laravel_page.dart';
import '../recorrido/recorrido_documento.dart';
import 'nota_interna.dart';
import 'notas_api.dart';

class DetalleNotaPage extends StatefulWidget {
  const DetalleNotaPage({
    super.key,
    required this.api,
    required this.id,
    this.soloLectura = false,
    this.puedeAdjuntar = true,
  });
  final ApiLaravel api;
  final String id;
  final bool soloLectura, puedeAdjuntar;

  @override
  State<DetalleNotaPage> createState() => _DetalleNotaPageState();
}

class _DetalleNotaPageState extends State<DetalleNotaPage> {
  NotaInterna? _nota;
  Map<String, dynamic>? _documento;
  SolicitudNota? _pendiente;
  String? _errorCarga, _errorAccion, _mensaje;
  bool _cargando = false, _guardando = false, _confirmando = false;
  bool _hojaOcupada = false, _hojaPendiente = false, _saliendo = false;
  bool get _ocupada => _cargando || _guardando || _confirmando || _hojaOcupada;
  bool get _sinConfirmar => _pendiente != null || _hojaPendiente;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _limpiar() {
    _nota = null;
    _documento = null;
    _pendiente = null;
    _hojaPendiente = false;
    _mensaje = null;
  }

  Future<void> _cargar() async {
    if (_cargando) return;
    final token = widget.api.token;
    final cuenta = widget.api.cuentaId;
    setState(() {
      _cargando = true;
      _errorCarga = null;
      _documento = null;
    });
    try {
      final servicio = NotasApi(widget.api);
      final pendiente = widget.soloLectura
          ? null
          : await servicio.pendientePara(widget.id);
      if (!mounted) return;
      setState(() => _pendiente = pendiente);
      final nota = await servicio.detalle(widget.id);
      if (!mounted) return;
      if (pendiente != null &&
          await servicio.confirmarSiAplicado(nota, pendiente)) {
        if (!mounted) return;
        setState(() {
          _pendiente = null;
          _mensaje = pendiente.accion == AccionNota.conformidad
              ? 'La conformidad ya está registrada. Estado actualizado.'
              : 'La recepción ya está registrada. Estado actualizado.';
        });
      }
      Map<String, dynamic>? vinculado;
      if (nota.documentoId != null && nota.hojaId != null) {
        final documento = await widget.api.enviar(
          'GET',
          'hojas/${Uri.encodeComponent(nota.hojaId!)}',
        );
        final hoja = documento['hoja'];
        if (documento['id'] != nota.documentoId ||
            hoja is! Map ||
            hoja['id'] != nota.hojaId ||
            hoja['version'] is! int ||
            documento['acciones_permitidas'] is! List ||
            (documento['acciones_permitidas'] as List).any(
              (a) => a is! String,
            )) {
          throw const ErrorLaravel('No se pudo comprobar la hoja vinculada.');
        }
        if (!mounted) return;
        final permitidas = <String>{
          if (!widget.soloLectura &&
              nota.permite('confirmar_recepcion_derivacion'))
            'recibir',
          if (!widget.soloLectura && nota.permite('registrar_atencion'))
            'atender',
        };
        vinculado = {
          ...documento,
          'acciones_permitidas': (documento['acciones_permitidas'] as List)
              .where(permitidas.contains)
              .toList(),
        };
      }
      if (token != widget.api.token || cuenta != widget.api.cuentaId) {
        throw const ErrorLaravel(
          'Tu sesión cambió. Vuelve a ingresar.',
          estado: 401,
        );
      }
      setState(() {
        _nota = nota;
        _documento = vinculado;
      });
    } on ErrorLaravel catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCarga = e.mensaje;
        if ({401, 403, 404}.contains(e.estado) || token != widget.api.token) {
          _limpiar();
        }
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _ejecutar(AccionNota accion) async {
    if (_ocupada || widget.soloLectura || _nota == null || _hojaPendiente) {
      return;
    }
    if (_pendiente == null) {
      final nota = _nota!;
      final token = widget.api.token;
      final cuenta = widget.api.cuentaId;
      final permiso = accion == AccionNota.conformidad
          ? 'dar_conformidad'
          : 'confirmar_primera_recepcion';
      if (_errorCarga != null || !nota.permite(permiso)) return;
      setState(() => _confirmando = true);
      final aceptar = await showDialog<bool>(
        context: context,
        builder: (context) => InterfazInstitucional(
          builder: (context) => AlertDialog(
            title: Text('¿${accion.titulo}?'),
            content: Text(
              '${nota.cite}\n${nota.asunto}\nVersión ${nota.version}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ),
      );
      if (!mounted) return;
      setState(() => _confirmando = false);
      if (aceptar != true) return;
      if (token != widget.api.token || cuenta != widget.api.cuentaId) {
        setState(() {
          _limpiar();
          _errorCarga = 'Tu sesión cambió. Vuelve a ingresar.';
        });
        return;
      }
      _pendiente = SolicitudNota(
        nota: nota,
        accion: accion,
        token: widget.api.token,
        cuentaId: widget.api.cuentaId,
      );
    }
    setState(() {
      _guardando = true;
      _errorAccion = null;
      _mensaje = null;
    });
    try {
      final solicitud = _pendiente!;
      final nota = await NotasApi(widget.api).ejecutar(solicitud);
      if (!mounted) return;
      setState(() {
        _pendiente = null;
        _nota = nota;
        _documento = null;
        _mensaje = solicitud.accion == AccionNota.conformidad
            ? 'Conformidad registrada.'
            : 'Recepción confirmada.';
      });
      await _cargar();
    } on ErrorLaravel catch (e) {
      if (!mounted) return;
      final rechazo = NotasApi.rechazoDefinitivo(e);
      setState(() {
        if (rechazo) _pendiente = null;
        _errorAccion = e.estado == 409
            ? 'La nota cambió. Revisa la versión actualizada antes de confirmar.'
            : [e.mensaje, ...e.errores.values].join('\n');
        if ({401, 403, 404}.contains(e.estado)) _limpiar();
      });
      if (e.estado == 409) await _cargar();
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _hojaConfirmada(Map<String, dynamic>? resultado) async {
    if (!mounted) return;
    setState(() {
      _hojaOcupada = false;
      _hojaPendiente = false;
    });
    if (resultado == null) {
      // El permiso debe comprobarse también sobre la nota, no sólo la hoja.
      setState(() => _documento = null);
    } else {
      setState(() {
        _documento = null;
        _mensaje = 'Acción confirmada. El recorrido fue actualizado.';
      });
    }
    await _cargar();
  }

  Future<void> _salir() async {
    if (_ocupada || _saliendo) return;
    if (_sinConfirmar) {
      final salir = await showDialog<bool>(
        context: context,
        builder: (context) => InterfazInstitucional(
          builder: (context) => AlertDialog(
            title: const Text('Hay una operación sin confirmar'),
            content: const Text(
              'Reintenta aquí para comprobar el mismo intento. Si sales, consulta el estado antes de realizar otra acción.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Seguir aquí'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salir'),
              ),
            ],
          ),
        ),
      );
      if (salir != true || !mounted) return;
    }
    setState(() => _saliendo = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _abrirExpediente() async {
    final nota = _nota;
    if (nota?.documentoId == null ||
        _ocupada ||
        _sinConfirmar ||
        _errorCarga != null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InterfazInstitucional(
          builder: (_) => DetalleLaravelPage(
            api: widget.api,
            id: nota!.documentoId!,
            puedeAdjuntar: widget.puedeAdjuntar,
            soloLectura: widget.soloLectura,
          ),
        ),
      ),
    );
    if (mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) =>
      InterfazInstitucional(builder: _construir);

  Widget _construir(BuildContext context) {
    final nota = _nota;
    final puedeActuar = !_ocupada && !_sinConfirmar && _errorCarga == null;
    final acciones = <Widget>[
      if (!widget.soloLectura && nota != null && _pendiente == null) ...[
        if (nota.permite('dar_conformidad'))
          FilledButton(
            onPressed: puedeActuar
                ? () => _ejecutar(AccionNota.conformidad)
                : null,
            child: const Text('Dar conformidad'),
          ),
        if (nota.permite('confirmar_primera_recepcion'))
          FilledButton(
            onPressed: puedeActuar
                ? () => _ejecutar(AccionNota.primeraRecepcion)
                : null,
            child: const Text('Confirmar recepción'),
          ),
      ],
      if (_pendiente != null)
        FilledButton(
          onPressed: _ocupada ? null : () => _ejecutar(_pendiente!.accion),
          child: const Text('Comprobar mismo intento'),
        ),
    ];
    return PopScope(
      canPop: _saliendo,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _salir();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nota interna'),
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: _ocupada ? null : _salir,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              tooltip: 'Actualizar nota',
              onPressed: _ocupada || _sinConfirmar ? null : _cargar,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        bottomNavigationBar: acciones.isEmpty
            ? null
            : SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Institucional.borde)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: acciones,
                  ),
                ),
              ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_cargando || _guardando || _hojaOcupada)
              const LinearProgressIndicator(),
            if (_mensaje != null)
              Text(
                _mensaje!,
                key: const ValueKey('nota-confirmada'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Institucional.accion,
                ),
              ),
            if (_errorCarga != null) ...[
              Text(
                _errorCarga!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: _ocupada || _sinConfirmar ? null : _cargar,
                child: const Text('Reintentar carga'),
              ),
            ],
            if (_errorAccion != null)
              Text(
                _errorAccion!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (nota != null) ...[
              Text(nota.cite, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(
                nota.asunto,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              EstadoInstitucional(nota.etiquetaEstado),
              const SizedBox(height: 12),
              DatoInstitucional('Origen', nota.origen),
              if (nota.datos['unidad_actual'] case final Map unidad)
                DatoInstitucional('Unidad actual', '${unidad['nombre']}'),
              if (nota.datos['destino_pendiente'] case final Map unidad)
                DatoInstitucional('Destino', '${unidad['nombre']}'),
              DatoInstitucional(
                'Fecha',
                sakaiDate(nota.datos['fecha_ultimo_movimiento']),
              ),
              if (nota.datos['referencia'] case final String referencia)
                DatoInstitucional('Referencia', referencia),
              const SizedBox(height: 20),
              Text('Contenido', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (nota.cuerpo != null)
                Text(
                  nota.cuerpo!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              const SizedBox(height: 20),
              if (widget.soloLectura) const Text('Copia para conocimiento.'),
              if (_pendiente != null) ...[
                const Text(
                  'El resultado todavía no está confirmado. Se conservará el mismo intento al reintentar.',
                ),
              ],
              if (_documento != null && !widget.soloLectura)
                RecorridoDocumento(
                  institucional: true,
                  api: widget.api,
                  documento: _documento!,
                  bloqueado:
                      _guardando ||
                      _cargando ||
                      _pendiente != null ||
                      _errorCarga != null,
                  alConfirmar: _hojaConfirmada,
                  alOcuparse: (v) {
                    if (mounted) setState(() => _hojaOcupada = v);
                  },
                  alPendiente: (v) {
                    if (mounted) setState(() => _hojaPendiente = v);
                  },
                ),
              if (nota.documentoId != null && nota.hojaId != null)
                OutlinedButton.icon(
                  onPressed: puedeActuar ? _abrirExpediente : null,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Ver expediente y adjuntos'),
                ),
              const Divider(height: 32),
              Text(
                'Historial de la nota',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Versión ${nota.version}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              for (final m
                  in (nota.datos['movimientos_nota'] as List? ?? const []))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${m['accion']} · ${sakaiDate(m['fecha'])}\n${m['actor'] is Map ? m['actor']['nombre'] ?? m['actor']['name'] ?? '' : m['actor'] ?? ''}',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
