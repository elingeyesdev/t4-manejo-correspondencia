import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/sakai_theme.dart';
import '../widgets/sakai_widgets.dart';

import '../services/laravel_api.dart';

class RegistroLaravelPage extends StatefulWidget {
  const RegistroLaravelPage({super.key, required this.api});
  final ApiLaravel api;
  @override
  State<RegistroLaravelPage> createState() => _RegistroLaravelPageState();
}

class _RegistroLaravelPageState extends State<RegistroLaravelPage> {
  final _form = GlobalKey<FormState>();
  final _remitente = TextEditingController();
  final _asunto = TextEditingController();
  Map<String, dynamic>? _config;
  Map<String, String> _errores = {};
  Map<String, dynamic>? _guardado;
  int? _tipo, _prioridad, _unidad;
  DateTime _fecha = DateUtils.dateOnly(DateTime.now());
  bool _cargando = true, _enviando = false;
  String? _error, _huella, _clave;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _remitente.dispose();
    _asunto.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await widget.api.enviar('GET', 'configuracion-registro');
      for (final key in ['tipos', 'prioridades', 'unidades']) {
        if (r[key] is! List ||
            (r[key] as List).any(
              (x) => x is! Map || x['id'] is! int || x['name'] is! String,
            )) {
          throw const ErrorLaravel(
            'No se pudieron interpretar las opciones de registro.',
          );
        }
      }
      if (mounted) {
        setState(() {
          _config = r;
          if ((r['unidades'] as List).length == 1) {
            _unidad = r['unidades'][0]['id'] as int;
          }
        });
      }
    } on ErrorLaravel catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String get _fechaTexto =>
      '${_fecha.year}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}';
  Future<void> _guardar() async {
    if (_enviando) return;
    setState(() {
      _errores = {};
      _error = null;
    });
    if (!_form.currentState!.validate()) return;
    final datos = <String, dynamic>{
      'remitente': _remitente.text.trim(),
      'asunto': _asunto.text.trim(),
      'fecha': _fechaTexto,
      'tipo_id': _tipo,
      'prioridad_id': _prioridad,
      'unidad_id': _unidad,
    };
    final huella = jsonEncode(datos);
    if (_huella != huella) {
      _huella = huella;
      _clave = nuevaClaveSolicitud();
    }
    setState(() => _enviando = true);
    try {
      final r = await widget.api.enviar(
        'POST',
        'documentos',
        datos: datos,
        cabeceras: {'Idempotency-Key': _clave!},
      );
      if (r['id'] is! String ||
          r['guia'] is! String ||
          r['codigo'] is! String) {
        throw const ErrorLaravel(
          'La respuesta está incompleta. Consulta la bandeja antes de volver a registrar.',
        );
      }
      if (mounted) setState(() => _guardado = r);
    } on ErrorLaravel catch (e) {
      if (mounted) {
        setState(() {
          _error = e.mensaje;
          _errores = e.errores;
        });
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _selector(
    String label,
    String lista,
    String campo,
    int? valor,
    ValueChanged<int?> cambiar,
  ) => DropdownButtonFormField<int>(
    initialValue: valor,
    isExpanded: true,
    decoration: InputDecoration(labelText: label, errorText: _errores[campo]),
    items: [
      for (final x in (_config![lista] as List).cast<Map>())
        DropdownMenuItem(
          value: x['id'] as int,
          child: Text(x['name'] as String),
        ),
    ],
    onChanged: _enviando ? null : cambiar,
    validator: (v) => v == null ? 'Selecciona una opción.' : null,
  );
  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_config == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'No se pudo preparar el registro.'),
              TextButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    if (_guardado case final Map<String, dynamic> r) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.check_circle_outline, color: Sakai.green, size: 56),
          const SizedBox(height: 16),
          Text(
            'Correspondencia registrada',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          const Text('Número de guía'),
          SelectableText(r['guia'] as String),
          const SizedBox(height: 12),
          const Text('Código de documento'),
          SelectableText(r['codigo'] as String),
          const SizedBox(height: 12),
          Text('Hoja de ruta: ${(r['hoja'] as Map?)?['codigo'] ?? ''}'),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => setState(() {
              _guardado = null;
              _remitente.clear();
              _asunto.clear();
              _huella = null;
              _clave = null;
              _errores = {};
              _fecha = DateUtils.dateOnly(DateTime.now());
            }),
            child: const Text('Registrar otra correspondencia'),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SakaiPanel(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nueva correspondencia',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Completa los datos de recepción. La guía se genera al guardar.',
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    SakaiIcon(
                      PrimeIcons.plus,
                      color: Sakai.green,
                      background: Sakai.mint,
                      size: 36,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Datos del documento',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _remitente,
                  enabled: !_enviando,
                  maxLength: 150,
                  decoration: InputDecoration(
                    labelText: 'Remitente',
                    errorText: _errores['remitente'],
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa el remitente.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _asunto,
                  enabled: !_enviando,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Asunto',
                    errorText: _errores['asunto'],
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa el asunto.'
                      : null,
                ),
                const SizedBox(height: 16),
                _selector(
                  'Tipo de documento',
                  'tipos',
                  'tipo_id',
                  _tipo,
                  (v) => setState(() => _tipo = v),
                ),
                const SizedBox(height: 16),
                _selector(
                  'Prioridad',
                  'prioridades',
                  'prioridad_id',
                  _prioridad,
                  (v) => setState(() => _prioridad = v),
                ),
                const SizedBox(height: 16),
                _selector(
                  'Unidad',
                  'unidades',
                  'unidad_id',
                  _unidad,
                  (v) => setState(() => _unidad = v),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('Fecha de recepción: $_fechaTexto'),
                  onPressed: _enviando
                      ? null
                      : () async {
                          final fecha = await showDatePicker(
                            context: context,
                            initialDate: _fecha,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (fecha != null && mounted) {
                            setState(() => _fecha = fecha);
                          }
                        },
                ),
                if (_errores['fecha'] != null) Text(_errores['fecha']!),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _enviando ? null : _guardar,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _enviando ? 'Guardando…' : 'Registrar correspondencia',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
