import 'package:flutter/material.dart';

import '../theme/sakai_theme.dart';
import '../widgets/sakai_widgets.dart';

import '../services/sesion_controller.dart';

class AccesoLaravelPage extends StatefulWidget {
  const AccesoLaravelPage({super.key, required this.sesion});
  final SesionController sesion;
  @override
  State<AccesoLaravelPage> createState() => _AccesoLaravelPageState();
}

class _AccesoLaravelPageState extends State<AccesoLaravelPage> {
  final _form = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _ocultar = true;
  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (widget.sesion.ocupada || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await widget.sesion.ingresar(_correo.text, _clave.text);
    if (mounted) _clave.clear();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SakaiPanel(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        PrimeIcons.folder,
                        size: 48,
                        color: Sakai.green,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Correspondencia',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ingresa con tu cuenta institucional para consultar los documentos de tu unidad.',
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _correo,
                      enabled: !widget.sesion.ocupada,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (v) =>
                          v == null ||
                              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(v.trim())
                          ? 'Ingresa un correo válido.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _clave,
                      enabled: !widget.sesion.ocupada,
                      obscureText: _ocultar,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _ocultar
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          onPressed: () => setState(() => _ocultar = !_ocultar),
                          icon: Icon(
                            _ocultar
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Ingresa tu contraseña.'
                          : null,
                      onFieldSubmitted: (_) => _ingresar(),
                    ),
                    if (widget.sesion.mensaje != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            widget.sesion.mensaje!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: widget.sesion.ocupada ? null : _ingresar,
                      child: Text(
                        widget.sesion.ocupada
                            ? 'Ingresando...'
                            : 'Iniciar sesión',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
