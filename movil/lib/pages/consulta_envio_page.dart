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
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF3E9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.travel_explore_outlined,
                    color: Color(0xFF456B2F),
                    size: 30,
                  ),
                ),
              ),
              Text(
                'Consultar envío',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ingrese el número de guía para conocer el estado y el último movimiento.',
              ),
              const SizedBox(height: 28),
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
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFDDE5D6)),
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
                          const SizedBox(height: 20),
                          const Text('Número de guía'),
                          SelectableText(
                            envio.numeroGuia,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                          const Text('Estado actual'),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF3E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              envio.estado,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: const Color(0xFF456B2F)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('Último movimiento'),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_outlined,
                                size: 18,
                                color: Color(0xFF667064),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _fechaAmigable(envio.fechaUltimoMovimiento),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_envio == null && _mensaje == null && !_consultando)
                Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.manage_search_outlined,
                        size: 42,
                        color: Color(0xFFB5BFAE),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'El seguimiento aparecerá aquí',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: const Color(0xFF75806E)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
