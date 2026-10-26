import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/correspondencia.dart';
import '../services/correspondencia_api.dart';

class RegistroCorrespondenciaPage extends StatefulWidget {
  const RegistroCorrespondenciaPage({super.key, required this.api});
  final CorrespondenciaApi api;
  @override
  State<RegistroCorrespondenciaPage> createState() =>
      _RegistroCorrespondenciaPageState();
}

class _RegistroCorrespondenciaPageState
    extends State<RegistroCorrespondenciaPage> {
  final _form = GlobalKey<FormState>();
  final _remitente = TextEditingController();
  final _asunto = TextEditingController();
  final _fechaTexto = TextEditingController();
  String? _tipo;
  DateTime? _fecha;
  bool _guardando = false;
  bool _validar = false;
  Map<String, String> _errores = {};
  String? _mensajeError;
  bool _formularioRevisado = false;

  @override
  void dispose() {
    _remitente.dispose();
    _asunto.dispose();
    _fechaTexto.dispose();
    super.dispose();
  }

  void _editar(String campo) => setState(() {
    _errores.remove(campo);
    _mensajeError = null;
    _formularioRevisado = false;
  });

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha ?? DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Fecha de recepción',
      confirmText: 'Aceptar',
      cancelText: 'Cancelar',
    );
    if (!mounted || fecha == null) return;
    setState(() {
      _fecha = fecha;
      _fechaTexto.text =
          '${fecha.day.toString().padLeft(2, '0')}/'
          '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
      _errores.remove('fechaRecepcion');
      _mensajeError = null;
      _formularioRevisado = false;
    });
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _validar = true;
      _errores = {};
      _mensajeError = null;
      _formularioRevisado = false;
    });
    if (!_form.currentState!.validate()) return;
    if (!widget.api.configurada) {
      setState(() => _formularioRevisado = true);
      return;
    }
    setState(() => _guardando = true);
    try {
      final resultado = await widget.api.registrar(
        Correspondencia(
          remitente: _remitente.text,
          asunto: _asunto.text,
          tipoDocumento: _tipo!,
          fechaRecepcion: _fecha!,
        ),
      );
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _validar = false;
        _tipo = null;
        _fecha = null;
        _errores = {};
      });
      _form.currentState!.reset();
      _remitente.clear();
      _asunto.clear();
      _fechaTexto.clear();
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Correspondencia registrada correctamente'),
          content: SelectableText(
            resultado.correlativo,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errores = Map.of(error.errores);
        _mensajeError = error.mensaje;
      });
    } catch (error, stack) {
      debugPrint('Error al registrar correspondencia: $error\n$stack');
      if (!mounted) return;
      setState(
        () => _mensajeError =
            'No se pudo completar el registro. Intente nuevamente.',
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Form(
          key: _form,
          autovalidateMode: _validar
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nueva correspondencia',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Registro de correspondencia recibida'),
              if (!widget.api.configurada) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFFF4F5F2),
                  child: const Text(
                    'Registro pendiente de conexión. Por ahora puedes completar y validar los campos sin enviarlos.',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextFormField(
                controller: _remitente,
                enabled: !_guardando,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Remitente',
                  prefixIcon: const Icon(Icons.person_outline),
                  errorText: _errores['remitente'],
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingrese el remitente.'
                    : null,
                onChanged: (_) => _editar('remitente'),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _asunto,
                enabled: !_guardando,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                minLines: 2,
                maxLength: 150,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                decoration: InputDecoration(
                  labelText: 'Asunto',
                  prefixIcon: const Icon(Icons.subject),
                  errorText: _errores['asunto'],
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingrese el asunto.';
                  }
                  if (value.trim().length > 150) {
                    return 'El asunto no puede superar los 150 caracteres.';
                  }
                  return null;
                },
                onChanged: (_) => _editar('asunto'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Tipo de documento',
                  prefixIcon: const Icon(Icons.description_outlined),
                  errorText: _errores['tipoDocumento'],
                ),
                items: Correspondencia.tipos
                    .map(
                      (tipo) =>
                          DropdownMenuItem(value: tipo, child: Text(tipo)),
                    )
                    .toList(),
                onChanged: _guardando
                    ? null
                    : (value) {
                        _tipo = value;
                        _editar('tipoDocumento');
                      },
                validator: (value) =>
                    value == null ? 'Seleccione un tipo de documento.' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _fechaTexto,
                enabled: !_guardando,
                readOnly: true,
                onTap: _seleccionarFecha,
                decoration: InputDecoration(
                  labelText: 'Fecha de recepción',
                  hintText: 'Seleccione una fecha',
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  errorText: _errores['fechaRecepcion'],
                ),
                validator: (_) =>
                    _fecha == null ? 'Seleccione la fecha de recepción.' : null,
              ),
              if (_mensajeError != null) ...[
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Text(
                      _mensajeError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ],
              if (_formularioRevisado) ...[
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  child: const Text(
                    'Los campos son válidos. No se enviaron ni guardaron datos: falta conectar el registro con la API oficial.',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _guardando
                      ? 'Guardando...'
                      : widget.api.configurada
                      ? 'Guardar correspondencia'
                      : 'Validar formulario',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
