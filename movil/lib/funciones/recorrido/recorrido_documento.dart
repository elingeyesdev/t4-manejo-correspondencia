import 'package:flutter/material.dart';

import '../../compartido/api/laravel_api.dart';
import '../../compartido/diseno/sakai_widgets.dart';
import 'recorrido_api.dart';

class RecorridoDocumento extends StatefulWidget {
  const RecorridoDocumento({
    super.key,
    required this.api,
    required this.documento,
    required this.alConfirmar,
    required this.alOcuparse,
    required this.alPendiente,
    this.bloqueado = false,
  });
  final ApiLaravel api;
  final Map<String, dynamic> documento;
  final Future<void> Function(Map<String, dynamic>? resultado) alConfirmar;
  final ValueChanged<bool> alOcuparse, alPendiente;
  final bool bloqueado;

  @override
  State<RecorridoDocumento> createState() => _RecorridoDocumentoState();
}

class _RecorridoDocumentoState extends State<RecorridoDocumento>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _form = GlobalKey<FormState>();
  final _texto = TextEditingController();
  OperacionRecorrido? _operacion;
  List<({int id, String nombre})> _destinos = [];
  int? _destino;
  SolicitudRecorrido? _pendiente;
  bool _ocupada = false;
  String? _error, _aviso;
  Map<String, String> _errores = {};

  Map get _hoja => widget.documento['hoja'] as Map? ?? {};
  List get _acciones => widget.documento['acciones_permitidas'] as List? ?? [];
  bool get _valida => _hoja['id'] is String && _hoja['version'] is int;

  @override
  void didUpdateWidget(covariant RecorridoDocumento oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pendiente == null &&
        _operacion != null &&
        !_acciones.contains(_operacion!.name)) {
      _operacion = null;
    }
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _elegir(OperacionRecorrido operacion) async {
    if (_ocupada || _pendiente != null || widget.bloqueado) return;
    setState(() {
      _operacion = operacion;
      _error = null;
      _aviso = null;
      _errores = {};
      _destinos = [];
      _destino = null;
      _texto.clear();
    });
    if (operacion != OperacionRecorrido.derivar) return;
    setState(() => _ocupada = true);
    widget.alOcuparse(true);
    try {
      final destinos = await RecorridoApi(widget.api)
          .destinos(_hoja['id'] as String);
      if (!mounted) return;
      setState(() {
        _destinos = destinos;
        if (destinos.isEmpty) {
          _error = 'No hay otra unidad habilitada para recibir esta hoja.';
        }
      });
    } on ErrorLaravel catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) {
        setState(() => _ocupada = false);
        widget.alOcuparse(false);
      }
    }
  }

  Future<void> _enviar() async {
    if (_ocupada || widget.bloqueado || !_valida || _operacion == null) return;
    if (_pendiente == null) {
      if (!_form.currentState!.validate()) return;
      if (_operacion == OperacionRecorrido.recibir) {
        final aceptar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Confirmar recepción?'),
            content: const Text(
              'Quedarás como responsable de esta hoja en tu unidad.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar recepción'),
              ),
            ],
          ),
        );
        if (aceptar != true || !mounted) return;
      }
      _pendiente = SolicitudRecorrido(
        hoja: _hoja['id'] as String,
        documento: widget.documento['id'] as String,
        operacion: _operacion!,
        token: widget.api.token,
        datos: {
          'version': _hoja['version'],
          if (_operacion == OperacionRecorrido.derivar) ...{
            'destino_unidad_id': _destino,
            'motivo': textoRecorrido(_texto.text),
          },
          if (_operacion == OperacionRecorrido.atender)
            'observacion': textoRecorrido(_texto.text),
        },
      );
      widget.alPendiente(true);
    }
    setState(() {
      _ocupada = true;
      _error = null;
      _aviso = null;
      _errores = {};
    });
    widget.alOcuparse(true);
    try {
      final solicitud = _pendiente!;
      final resultado = await RecorridoApi(widget.api).enviar(solicitud);
      if (!mounted) return;
      _pendiente = null;
      widget.alPendiente(false);
      setState(() {
        _operacion = null;
        _texto.clear();
        _aviso = switch (solicitud.operacion) {
          OperacionRecorrido.derivar =>
            'Hoja derivada. Espera la confirmación de la unidad de destino.',
          OperacionRecorrido.recibir =>
            'Recepción confirmada. Ya eres responsable de la hoja.',
          OperacionRecorrido.atender =>
            'Atención guardada. Puedes adjuntar una foto si corresponde.',
        };
      });
      await widget.alConfirmar(resultado);
    } on ErrorLaravel catch (e) {
      if (!mounted) return;
      final rechazo = e.estado != null && e.estado! >= 400 && e.estado! < 500;
      if (rechazo) {
        _pendiente = null;
        widget.alPendiente(false);
      }
      setState(() {
        _errores = e.errores;
        _error = !rechazo
            ? 'No se pudo confirmar el resultado. Reintenta para recuperar la misma operación sin duplicarla.'
            : e.estado == 409
            ? 'La hoja cambió. Revisa el estado actualizado antes de volver a guardar.'
            : e.mensaje;
      });
      if (e.estado == 409 || e.estado == 403 || e.estado == 404) {
        await widget.alConfirmar(null);
      }
    } finally {
      if (mounted) {
        setState(() => _ocupada = false);
        widget.alOcuparse(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_valida) return const SizedBox.shrink();
    final bloqueado = _ocupada || widget.bloqueado;
    final operacion = _operacion;
    return SakaiSection(
      title: 'Acciones de la hoja',
      icon: Icons.route_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_aviso != null) Text(_aviso!, semanticsLabel: _aviso),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          if (_pendiente == null && operacion == null)
            if (!_acciones.any(
              (a) => {'derivar', 'recibir', 'atender'}.contains(a),
            ))
              const Text(
                'Puedes consultar el expediente. No tienes acciones disponibles en su estado actual.',
              )
            else
              for (final accion in OperacionRecorrido.values)
                if (_acciones.contains(accion.name))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton(
                      onPressed: bloqueado ? null : () => _elegir(accion),
                      child: Text(accion.titulo),
                    ),
                  ),
          if (operacion != null)
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    operacion.titulo,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (operacion == OperacionRecorrido.derivar) ...[
                    DropdownButtonFormField<int>(
                      key: ValueKey(_destinos.map((d) => d.id).join(',')),
                      initialValue: _destino,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Unidad de destino',
                        errorText: _errores['destino_unidad_id'],
                      ),
                      items: _destinos
                          .map(
                            (d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(d.nombre),
                            ),
                          )
                          .toList(),
                      onChanged: bloqueado || _pendiente != null
                          ? null
                          : (value) => setState(() => _destino = value),
                      validator: (value) => value == null
                          ? 'Selecciona una unidad de destino.'
                          : null,
                    ),
                    if (_destinos.isEmpty && !_ocupada)
                      TextButton(
                        onPressed: widget.bloqueado
                            ? null
                            : () => _elegir(operacion),
                        child: const Text('Consultar destinos'),
                      ),
                    const SizedBox(height: 12),
                  ],
                  if (operacion != OperacionRecorrido.recibir)
                    TextFormField(
                      controller: _texto,
                      readOnly: bloqueado || _pendiente != null,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(
                        labelText: operacion == OperacionRecorrido.derivar
                            ? 'Motivo'
                            : 'Observación',
                        helperText: operacion == OperacionRecorrido.derivar
                            ? 'Hasta 500 caracteres.'
                            : 'Hasta 2 000 caracteres.',
                        errorText:
                            _errores[operacion == OperacionRecorrido.derivar
                                ? 'motivo'
                                : 'observacion'],
                      ),
                      validator: (value) {
                        final texto = textoRecorrido(value ?? '');
                        final maximo = operacion == OperacionRecorrido.derivar
                            ? 500
                            : 2000;
                        if (texto.isEmpty) {
                          return 'Escribe el texto antes de guardar.';
                        }
                        if (texto.runes.length > maximo) {
                          return 'El texto permite hasta $maximo caracteres.';
                        }
                        return null;
                      },
                    ),
                  if (operacion == OperacionRecorrido.recibir)
                    const Text(
                      'Confirma únicamente cuando la correspondencia haya llegado a tu unidad.',
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: bloqueado ? null : _enviar,
                    child: Text(
                      _pendiente != null
                          ? 'Reintentar confirmación'
                          : operacion == OperacionRecorrido.atender
                          ? 'Guardar atención'
                          : operacion.titulo,
                    ),
                  ),
                  if (_pendiente == null)
                    TextButton(
                      onPressed: bloqueado
                          ? null
                          : () => setState(() {
                              _operacion = null;
                              _error = null;
                            }),
                      child: const Text('Cancelar'),
                    ),
                ],
              ),
            ),
          if (_ocupada) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
