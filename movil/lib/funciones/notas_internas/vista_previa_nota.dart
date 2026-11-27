import 'dart:async';

import 'package:flutter/material.dart';

import '../../compartido/api/laravel_api.dart';
import '../../compartido/diseno/institucional.dart';
import 'documento_nota_pdf.dart';
import 'hoja_nota.dart';
import 'nota_interna.dart';
import 'notas_api.dart';
import 'seguimiento_nota.dart';

class DocumentoNota extends StatelessWidget {
  const DocumentoNota({super.key, required this.nota, this.api});
  final NotaInterna nota;
  final ApiLaravel? api;
  @override
  Widget build(BuildContext context) => api != null
      ? SizedBox(
          height: 520,
          child: HojaNota(api: api!, nota: nota),
        )
      : Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Institucional.borde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'NOTA INTERNA',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              DatoInstitucional('CITE', nota.cite),
              DatoInstitucional('DE', nota.emisor),
              DatoInstitucional('A', nota.destinataria),
              DatoInstitucional('Asunto', nota.asunto),
              if (nota.datos['referencia'] case final String referencia)
                DatoInstitucional('Referencia', referencia),
              const Divider(height: 28),
              SelectableText(
                nota.cuerpo ?? 'El contenido no está disponible.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (nota.constancias.isNotEmpty) ...[
                const SizedBox(height: 24),
                ConstanciasNota(constancias: nota.constancias),
              ],
            ],
          ),
        );
}

class VistaPreviaNota extends StatefulWidget {
  const VistaPreviaNota({
    super.key,
    required this.nota,
    this.api,
    this.provisional,
    this.confirmar = false,
  });
  final NotaInterna nota;
  final ApiLaravel? api;
  final DocumentoNotaPdf? provisional;
  final bool confirmar;

  @override
  State<VistaPreviaNota> createState() => _VistaPreviaNotaState();
}

class _VistaPreviaNotaState extends State<VistaPreviaNota>
    with WidgetsBindingObserver {
  late NotaInterna _nota = widget.nota;
  late final String? _token = widget.api?.token;
  Timer? _reloj;
  bool _consultando = false,
      _lista = false,
      _cambio = false,
      _sesionInvalida = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.api != null) {
      _reloj = Timer.periodic(const Duration(seconds: 3), (_) => _actualizar());
    }
  }

  Future<void> _actualizar() async {
    final api = widget.api;
    if (!mounted ||
        api == null ||
        _consultando ||
        !(ModalRoute.of(context)?.isCurrent ?? false) ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      return;
    }
    _consultando = true;
    try {
      final actual = await NotasApi(api).detalle(_nota.id);
      if (!mounted) return;
      if (actual.version < _nota.version) return;
      if (_token != api.token) {
        throw const ErrorLaravel(
          'Tu sesión cambió. Vuelve a abrir la nota.',
          estado: 401,
        );
      }
      setState(() {
        _error = null;
        if (actual.revisionDocumento != _nota.revisionDocumento) {
          _cambio = widget.provisional != null;
          _lista = false;
          _nota = actual;
        }
      });
    } on ErrorLaravel catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _sesionInvalida =
            {401, 403, 404}.contains(e.estado) || _token != api.token;
      });
    } finally {
      _consultando = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_actualizar());
  }

  @override
  void dispose() {
    _reloj?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InterfazInstitucional(
    builder: (_) => Scaffold(
      appBar: const CabeceraInstitucional(titulo: 'Vista previa'),
      body: widget.api == null
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: DocumentoNota(nota: _nota),
            )
          : Column(
              children: [
                if (_cambio)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'La nota cambió. Vuelve atrás para revisar la acción y preparar nuevamente tu firma y sello.',
                    ),
                  ),
                if (widget.provisional != null && !_cambio)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Vista previa sin confirmar. Revisa todas las páginas antes de continuar.',
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!),
                  ),
                Expanded(
                  child: _sesionInvalida
                      ? const SizedBox.shrink()
                      : HojaNota(
                          api: widget.api!,
                          nota: _nota,
                          provisional: _cambio ? null : widget.provisional,
                          alCargar: () {
                            if (mounted) setState(() => _lista = true);
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: widget.confirmar
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed:
                      _lista && !_cambio && !_sesionInvalida && _error == null
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: const Text('Confirmar y continuar'),
                ),
              ),
            )
          : null,
    ),
  );
}
