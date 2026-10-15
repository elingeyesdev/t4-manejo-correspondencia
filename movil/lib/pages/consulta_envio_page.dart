import 'package:flutter/material.dart';

import '../models/envio_consulta.dart';
import '../services/consulta_envio_service.dart';

class ConsultaEnvioPage extends StatefulWidget {
  const ConsultaEnvioPage({super.key, required this.servicio});
  final ConsultaEnvioService servicio;
  @override
  State<ConsultaEnvioPage> createState() => _ConsultaEnvioPageState();
}

class _ConsultaEnvioPageState extends State<ConsultaEnvioPage> {
  final _form = GlobalKey<FormState>();
  final _guia = TextEditingController();
  bool _consultando = false;
  bool _validar = false;
  bool _esError = false;
  EnvioConsulta? _envio;
  String? _mensaje;

  @override
  void dispose() {
    _guia.dispose();
    super.dispose();
  }

  Future<void> _consultar() async {
    if (_consultando) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _validar = true;
      _envio = null;
      _mensaje = null;
      _esError = false;
    });
    if (!_form.currentState!.validate()) return;
    setState(() => _consultando = true);
    try {
      final envio = await widget.servicio.consultar(_guia.text.trim());
      if (!mounted) return;
      setState(() {
        _envio = envio;
        if (envio == null) {
          _mensaje = 'No se encontró un envío con ese número de guía.';
        }
      });
    } on ConsultaEnvioException catch (error) {
      if (!mounted) return;
      setState(() {
        _esError = true;
        _mensaje = error.mensaje;
      });
    } catch (error, stack) {
      debugPrint('Error de consulta: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _esError = true;
        _mensaje = 'No se pudo completar la consulta. Intente nuevamente.';
      });
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  String _fechaAmigable(DateTime fecha) {
    final local = fecha.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
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
                'Consultar envío',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Ingrese el número de guía para conocer el estado y el último movimiento.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _guia,
                enabled: !_consultando,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Número de guía',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingrese el número de guía.'
                    : null,
                onFieldSubmitted: (_) => _consultar(),
                onChanged: (_) => setState(() {
                  _envio = null;
                  _mensaje = null;
                  _esError = false;
                }),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _consultando ? null : _consultar,
                icon: _consultando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_consultando ? 'Consultando...' : 'Consultar'),
              ),
              const SizedBox(height: 24),
              if (_mensaje != null)
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _esError
                          ? Theme.of(context).colorScheme.errorContainer
                          : const Color(0xFFF4F5F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _esError ? Icons.error_outline : Icons.info_outline,
                          color: _esError
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_mensaje!)),
                      ],
                    ),
                  ),
                ),
              if (_envio case final envio?)
                Semantics(
                  liveRegion: true,
                  child: Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    color: const Color(0xFFF4F5F2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resultado de la consulta',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Divider(height: 28),
                          const Text('Número de guía'),
                          SelectableText(
                            envio.numeroGuia,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          const Text('Estado actual'),
                          Text(
                            envio.estado,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          const Text('Último movimiento'),
                          Text(_fechaAmigable(envio.fechaUltimoMovimiento)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
