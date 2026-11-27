import 'package:flutter/material.dart';

import '../../compartido/api/laravel_api.dart';
import '../../compartido/diseno/visor_pdf_institucional.dart';
import 'documento_nota_pdf.dart';
import 'nota_interna.dart';
import 'notas_api.dart';

class HojaNota extends StatefulWidget {
  const HojaNota({
    super.key,
    required this.api,
    required this.nota,
    this.provisional,
    this.alCargar,
  });
  final ApiLaravel api;
  final NotaInterna nota;
  final DocumentoNotaPdf? provisional;
  final VoidCallback? alCargar;

  @override
  State<HojaNota> createState() => _HojaNotaState();
}

class _HojaNotaState extends State<HojaNota> {
  late Future<DocumentoNotaPdf> _documento;
  late String? _token;

  void _cargar() {
    _token = widget.api.token;
    _documento = widget.provisional != null
        ? Future.value(widget.provisional)
        : NotasApi(widget.api).documento(widget.nota);
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant HojaNota oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nota.revisionDocumento != widget.nota.revisionDocumento ||
        oldWidget.provisional != widget.provisional ||
        _token != widget.api.token) {
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<DocumentoNotaPdf>(
    future: _documento,
    builder: (context, snapshot) {
      if (_token != widget.api.token) {
        return const Center(
          child: Text('Tu sesión cambió. Vuelve a abrir la nota.'),
        );
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  snapshot.error is ErrorLaravel
                      ? (snapshot.error as ErrorLaravel).mensaje
                      : 'No se pudo abrir el documento.',
                ),
                TextButton(
                  onPressed: () => setState(_cargar),
                  child: const Text('Reintentar documento'),
                ),
              ],
            ),
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done ||
          !snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return VisorPdfInstitucional(
        bytes: snapshot.data!.bytes,
        alCargar: widget.alCargar,
      );
    },
  );
}
