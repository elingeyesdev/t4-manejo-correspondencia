import 'dart:async';

import 'package:flutter/material.dart';

import '../../compartido/api/laravel_api.dart';
import '../../compartido/diseno/sakai_widgets.dart';
import '../../compartido/diseno/institucional.dart';
import '../../compartido/diseno/tramite_finalizado.dart';
import '../../compartido/navegacion/volver_inicio.dart';
import '../mi_bandeja/detalle_laravel_page.dart';
import '../recorrido/recorrido_documento.dart';
import 'nota_interna.dart';
import 'notas_api.dart';
import 'firma_nota.dart';
import 'firmar_nota_page.dart';
import 'seguimiento_nota.dart';
import 'vista_previa_nota.dart';

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

class _DetalleNotaPageState extends State<DetalleNotaPage>
    with WidgetsBindingObserver {
  NotaInterna? _nota;
  Map<String, dynamic>? _documento;
  SolicitudNota? _pendiente;
  String? _errorCarga, _errorAccion, _mensaje, _avisoExpediente;
  bool _cargando = false, _guardando = false, _confirmando = false;
  bool _hojaOcupada = false, _hojaPendiente = false, _saliendo = false;
  Timer? _actualizador;
  final _scroll = ScrollController();
  bool _sincronizando = false;
  int _generacionConsulta = 0;
  String? _avisoSincronizacion;
  bool get _ocupada => _cargando || _guardando || _confirmando || _hojaOcupada;
  bool get _sinConfirmar => _pendiente != null || _hojaPendiente;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargar();
    _actualizador = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _actualizarVisible(),
    );
  }

  void _actualizarVisible() {
    if (!mounted ||
        _ocupada ||
        _sinConfirmar ||
        _sincronizando ||
        _saliendo ||
        widget.api.token == null ||
        !(ModalRoute.of(context)?.isCurrent ?? false) ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      return;
    }
    unawaited(_cargar(automatica: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _actualizarVisible();
  }

  @override
  void dispose() {
    _actualizador?.cancel();
    _scroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _limpiar() {
    _nota = null;
    _documento = null;
    _avisoExpediente = null;
    _pendiente = null;
    _hojaPendiente = false;
    _mensaje = null;
  }

  Future<void> _cargar({bool automatica = false}) async {
    if (automatica && (_cargando || _sincronizando)) return;
    final generacion = ++_generacionConsulta;
    bool vigente() => mounted && generacion == _generacionConsulta;
    final token = widget.api.token;
    final cuenta = widget.api.cuentaId;
    _sincronizando = automatica;
    setState(() {
      if (!automatica) {
        _cargando = true;
        _errorCarga = null;
        _documento = null;
        _avisoExpediente = null;
      }
    });
    try {
      final servicio = NotasApi(widget.api);
      final pendiente = widget.soloLectura
          ? null
          : await servicio.pendientePara(widget.id);
      if (!vigente()) return;
      if (automatica && (_ocupada || _sinConfirmar)) return;
      setState(() => _pendiente = pendiente);
      final nota = await servicio.detalle(widget.id);
      if (!mounted || !vigente()) return;
      if (automatica &&
          (_ocupada ||
              _sinConfirmar ||
              !(ModalRoute.of(context)?.isCurrent ?? false))) {
        return;
      }
      if (automatica && _nota != null && nota.version < _nota!.version) return;
      if (pendiente != null &&
          await servicio.descartarFirmaDesactualizada(nota, pendiente)) {
        if (!vigente()) return;
        setState(() {
          _pendiente = null;
          _mensaje = 'La nota cambió. Revisa el contenido y firma la nueva versión cuando esté disponible.';
        });
      } else if (pendiente != null &&
          await servicio.confirmarSiAplicado(nota, pendiente)) {
        if (!vigente()) return;
        setState(() {
          _pendiente = null;
          _mensaje = switch (pendiente.accion) {
            AccionNota.conformidad =>
              'La conformidad ya está registrada. Estado actualizado.',
            AccionNota.primeraRecepcion =>
              'La recepción ya está registrada. Estado actualizado.',
            AccionNota.firmaRemitente =>
              'La firma ya está registrada. Puedes emitir desde web.',
          };
        });
      }
      Map<String, dynamic>? vinculado;
      String? avisoExpediente;
      if (nota.documentoId != null && nota.hojaId != null) {
        Map<String, dynamic>? documento;
        try {
          documento = await widget.api.enviar(
            'GET',
            'hojas/${Uri.encodeComponent(nota.hojaId!)}',
          );
          if (!vigente()) return;
        } on ErrorLaravel catch (e) {
          if (!vigente()) return;
          // La nota y su expediente tienen permisos independientes. Una CC
          // autorizada no pierde la nota porque no pueda consultar la hoja.
          if (!{403, 404}.contains(e.estado)) rethrow;
          avisoExpediente = 'Tu cuenta puede consultar la nota, pero no el expediente vinculado.';
        }
        if (documento != null) {
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
          if (!vigente()) return;
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
      }
      if (token != widget.api.token || cuenta != widget.api.cuentaId) {
        throw const ErrorLaravel(
          'Tu sesión cambió. Vuelve a ingresar.',
          estado: 401,
        );
      }
      if (!mounted ||
          !vigente() ||
          (automatica &&
              (_ocupada ||
                  _sinConfirmar ||
                  !(ModalRoute.of(context)?.isCurrent ?? false)))) {
        return;
      }
      setState(() {
        _errorCarga = null;
        _avisoSincronizacion = null;
        _nota = nota;
        _documento = vinculado;
        _avisoExpediente = avisoExpediente;
      });
    } on ErrorLaravel catch (e) {
      if (!vigente()) return;
      setState(() {
        if (automatica && !{401, 403, 404}.contains(e.estado)) {
          _avisoSincronizacion =
              'Sin actualización: se muestra el último estado confirmado.';
        } else {
          _errorCarga = e.mensaje;
        }
        if ({401, 403, 404}.contains(e.estado) || token != widget.api.token) {
          _limpiar();
        }
      });
    } finally {
      if (vigente()) {
        _sincronizando = false;
        setState(() => _cargando = false);
      }
    }
  }

  void _invalidarConsulta() {
    _generacionConsulta++;
    _sincronizando = false;
  }

  Future<bool> _comprobarPendiente(SolicitudNota anterior) async {
    final token = widget.api.token;
    final cuenta = widget.api.cuentaId;
    setState(() {
      _confirmando = true;
      _errorAccion = null;
    });
    try {
      final servicio = NotasApi(widget.api);
      final actual = await servicio.detalle(widget.id);
      if (!mounted) return false;
      if (token != widget.api.token ||
          cuenta != widget.api.cuentaId ||
          anterior.token != token ||
          anterior.cuentaId != cuenta) {
        throw const ErrorLaravel(
          'Tu sesión cambió. Vuelve a abrir la nota.',
          estado: 401,
        );
      }
      final desactualizada = await servicio.descartarFirmaDesactualizada(
        actual,
        anterior,
      );
      final aplicada =
          !desactualizada &&
          await servicio.confirmarSiAplicado(actual, anterior);
      if (!mounted) return false;
      setState(() {
        _nota = actual;
        _documento = null;
        if (desactualizada || aplicada) {
          _pendiente = null;
          _mensaje = desactualizada
              ? 'La nota cambió. Revisa el contenido y firma la nueva versión cuando esté disponible.'
              : 'La acción anterior ya está registrada. Estado actualizado.';
        }
      });
      if (desactualizada || aplicada) {
        await _cargar();
        return false;
      }
      return true;
    } on ErrorLaravel catch (e) {
      if (mounted) {
        setState(() {
          _errorAccion = e.mensaje;
          if ({401, 403, 404}.contains(e.estado)) _limpiar();
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }

  Future<void> _ejecutar(AccionNota accion) async {
    if (_ocupada ||
        widget.soloLectura ||
        (_nota == null && !(_pendiente?.requiereFirma ?? false)) ||
        _hojaPendiente) {
      return;
    }
    _invalidarConsulta();
    final pendienteAnterior = _pendiente;
    if (pendienteAnterior != null &&
        !await _comprobarPendiente(pendienteAnterior)) {
      return;
    }
    if (!mounted) return;
    if (_pendiente?.requiereFirma ?? false) {
      final anterior = _pendiente!;
      final token = widget.api.token;
      final cuenta = widget.api.cuentaId;
      setState(() {
        _confirmando = true;
        _errorAccion = null;
      });
      try {
        final actual = _nota!;
        final permiso = anterior.accion == AccionNota.conformidad
            ? 'dar_conformidad'
            : 'firmar_borrador';
        if (actual.version != anterior.version ||
            !actual.permite(permiso) ||
            actual.cuerpo == null ||
            actual.cuerpo!.trim().isEmpty) {
          throw const ErrorLaravel(
            'No se puede firmar el intento anterior con esta versión o permiso. Se conservó su reserva; vuelve a comprobar la nota.',
            codigo: 'VERSION_PENDIENTE',
          );
        }
        setState(() => _nota = actual);
        final firma = await Navigator.of(context).push<FirmaNota>(
          MaterialPageRoute(
            builder: (_) => FirmarNotaPage(
              nota: actual,
              titulo: 'Recuperar firma pendiente',
              api: widget.api,
              accion: anterior.accion,
            ),
          ),
        );
        if (!mounted || firma == null) return;
        if (token != widget.api.token || cuenta != widget.api.cuentaId) {
          throw const ErrorLaravel(
            'Tu sesión cambió. Vuelve a abrir la nota.',
            estado: 401,
          );
        }
        _pendiente = anterior.conFirma(firma);
      } on ErrorLaravel catch (e) {
        if (!mounted) return;
        setState(() {
          _errorAccion = e.mensaje;
          if ({401, 403, 404}.contains(e.estado)) _limpiar();
        });
        return;
      } finally {
        if (mounted) setState(() => _confirmando = false);
      }
    }
    if (_pendiente == null) {
      final nota = _nota!;
      final token = widget.api.token;
      final cuenta = widget.api.cuentaId;
      final permiso = switch (accion) {
        AccionNota.conformidad => 'dar_conformidad',
        AccionNota.primeraRecepcion => 'confirmar_primera_recepcion',
        AccionNota.firmaRemitente => 'firmar_borrador',
      };
      if (_errorCarga != null || !nota.permite(permiso)) return;
      setState(() => _confirmando = true);
      FirmaNota? firma;
      final bool aceptar;
      {
        if (nota.cuerpo == null || nota.cuerpo!.trim().isEmpty) {
          setState(() {
            _confirmando = false;
            _errorAccion = 'No se pudo cargar el contenido completo. Actualiza la nota antes de firmar.';
          });
          return;
        }
        firma = await Navigator.of(context).push<FirmaNota>(
          MaterialPageRoute(
            builder: (_) => FirmarNotaPage(
              nota: nota,
              titulo: accion.titulo,
              api: widget.api,
              accion: accion,
            ),
          ),
        );
        aceptar = firma != null;
      }
      if (!mounted) return;
      setState(() => _confirmando = false);
      if (!aceptar) return;
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
        firma: firma.tieneFirma || firma.tieneImagenes ? firma : null,
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
        _mensaje = switch (solicitud.accion) {
          AccionNota.conformidad => 'Conformidad registrada.',
          AccionNota.primeraRecepcion => 'Recepción confirmada.',
          AccionNota.firmaRemitente =>
            'Firma registrada. Vuelve a web para emitir la nota.',
        };
      });
      await _cargar();
    } on ErrorLaravel catch (e) {
      if (!mounted) return;
      final rechazo = NotasApi.rechazoDefinitivo(e, solicitud: _pendiente);
      setState(() {
        if (rechazo) _pendiente = null;
        _errorAccion = e.estado == 409
            ? 'La nota cambió. Revisa la versión actualizada antes de confirmar.'
            : e.estado == 429
            ? 'El servidor limitó las solicitudes. Espera un momento y comprueba el mismo intento; se conservaron su clave y versión.'
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
    _invalidarConsulta();
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
    if (mounted && _scroll.hasClients) {
      await _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
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
        _documento == null ||
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

  void _volverInicio() {
    if (_ocupada || _sinConfirmar || _saliendo) return;
    setState(() => _saliendo = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) DestinoInicio.abrir(context);
    });
  }

  @override
  Widget build(BuildContext context) =>
      InterfazInstitucional(builder: _construir);

  Widget _construir(BuildContext context) {
    final nota = _nota;
    final puedeActuar = !_ocupada && !_sinConfirmar && _errorCarga == null;
    final finalizada = nota?.estado == 'cerrada' && _errorCarga == null;
    final acciones = <Widget>[
      if (!widget.soloLectura && nota != null && _pendiente == null) ...[
        if (nota.permite('firmar_borrador'))
          FilledButton(
            onPressed: puedeActuar
                ? () => _ejecutar(AccionNota.firmaRemitente)
                : null,
            child: const Text('Firmar borrador'),
          ),
        if (nota.permite('dar_conformidad'))
          FilledButton(
            onPressed: puedeActuar
                ? () => _ejecutar(AccionNota.conformidad)
                : null,
            child: const Text('Firmar y dar conformidad'),
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
          child: Text(
            _pendiente!.requiereFirma
                ? 'Firmar y recuperar el mismo intento'
                : 'Comprobar mismo intento',
          ),
        ),
    ];
    return PopScope(
      canPop: _saliendo,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _salir();
      },
      child: Scaffold(
        appBar: CabeceraInstitucional(
          titulo: 'Nota interna',
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
        bottomNavigationBar: finalizada
            ? VolverInicioFinalizado(
                onPressed: puedeActuar ? _volverInicio : null,
              )
            : acciones.isEmpty
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
          controller: _scroll,
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
            if (_avisoSincronizacion != null) Text(_avisoSincronizacion!),
            if (nota != null) ...[
              Text(
                nota.asunto,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              DatoInstitucional('CITE', nota.cite),
              if (widget.soloLectura) const Text('Copia para conocimiento.'),
              const SizedBox(height: 8),
              const SizedBox(height: 12),
              EstadoInstitucional(nota.etiquetaEstado),
              if (finalizada) const TramiteFinalizado(),
              if (nota.seguimiento != null) ...[
                const SizedBox(height: 16),
                BarraSeguimientoNota(seguimiento: nota.seguimiento!),
              ],
              if (nota.estadoFirma != null) ...[
                const SizedBox(height: 8),
                Text(switch (nota.estadoFirma) {
                  'pendiente' => 'Pendiente de firma del remitente',
                  'firmada' => 'Borrador firmado. Emisión disponible en web.',
                  _ => 'La firma todavía no fue solicitada desde web.',
                }),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.description_outlined),
                label: const Text('Abrir vista previa'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        VistaPreviaNota(nota: nota, api: widget.api),
                  ),
                ),
              ),
              DocumentoNota(nota: nota, api: widget.api),
              const SizedBox(height: 12),
              if (nota.datos['unidad_actual'] case final Map unidad)
                DatoInstitucional('Unidad actual', '${unidad['nombre']}'),
              if (nota.datos['destino_pendiente'] case final Map unidad)
                DatoInstitucional(
                  'Recepción pendiente en',
                  '${unidad['nombre']}',
                ),
              DatoInstitucional(
                'Fecha',
                sakaiDate(nota.datos['fecha_ultimo_movimiento']),
              ),
              const SizedBox(height: 20),
              if (_pendiente != null) ...[
                const Text(
                  'El resultado todavía no está confirmado. Se conservará el mismo intento al reintentar.',
                ),
              ],
              if (_documento != null && !widget.soloLectura)
                RecorridoDocumento(
                  key: const ValueKey('recorrido-nota'),
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
                    if (mounted) {
                      if (v) _invalidarConsulta();
                      setState(() => _hojaOcupada = v);
                    }
                  },
                  alPendiente: (v) {
                    if (mounted) setState(() => _hojaPendiente = v);
                  },
                ),
              if (nota.documentoId != null && nota.hojaId != null)
                OutlinedButton.icon(
                  onPressed: puedeActuar && _documento != null
                      ? _abrirExpediente
                      : null,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Ver expediente y adjuntos'),
                ),
              if (_avisoExpediente != null) Text(_avisoExpediente!),
              const Divider(height: 32),
              Text(
                'Historial de la nota',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
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
