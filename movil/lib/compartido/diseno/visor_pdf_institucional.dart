import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class VisorPdfInstitucional extends StatefulWidget {
  const VisorPdfInstitucional({super.key, required this.bytes, this.alCargar});
  final Uint8List bytes;
  final VoidCallback? alCargar;

  @override
  State<VisorPdfInstitucional> createState() => _VisorPdfInstitucionalState();
}

class _VisorPdfInstitucionalState extends State<VisorPdfInstitucional> {
  final _transformacion = TransformationController();
  Future<void> _trabajo = Future.value();
  PdfDocument? _pdf;
  Uint8List? _imagen;
  int _pagina = 1, _total = 0, _generacion = 0;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  void _abrir() {
    final generacion = ++_generacion;
    final bytes = widget.bytes;
    _imagen = null;
    _error = null;
    _cargando = true;
    _total = 0;
    _pagina = 1;
    _trabajo = _trabajo.then((_) async {
      await _pdf?.close();
      _pdf = null;
      if (!mounted || generacion != _generacion) return;
      try {
        _pdf = await PdfDocument.openData(bytes);
        if (!mounted || generacion != _generacion) return;
        if (_pdf!.pagesCount < 1) throw StateError('Documento sin páginas');
        setState(() => _total = _pdf!.pagesCount);
        await _renderizar(1, generacion);
      } catch (_) {
        _fallo(generacion);
      }
    });
  }

  Future<void> _renderizar(int pagina, int generacion) async {
    PdfPage? hoja;
    try {
      if (!mounted || generacion != _generacion) return;
      hoja = await _pdf!.getPage(pagina, autoCloseAndroid: true);
      final imagen = await hoja.render(
        width: 1800,
        height: 1800 * hoja.height / hoja.width,
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#FFFFFF',
      );
      if (!mounted || generacion != _generacion) return;
      if (imagen == null || imagen.bytes.isEmpty) {
        throw StateError('Página sin imagen');
      }
      setState(() {
        _imagen = imagen.bytes;
        _pagina = pagina;
        _cargando = false;
        _error = null;
      });
      widget.alCargar?.call();
    } catch (_) {
      _fallo(generacion);
    } finally {
      await hoja?.close();
    }
  }

  void _fallo(int generacion) {
    if (mounted && generacion == _generacion) {
      setState(() {
        _error = 'No se pudo mostrar el PDF. Vuelve a cargar el documento.';
        _imagen = null;
        _cargando = false;
      });
    }
  }

  void _ir(int pagina) {
    if (_cargando || pagina < 1 || pagina > _total) return;
    _transformacion.value = Matrix4.identity();
    setState(() {
      _cargando = true;
      _imagen = null;
    });
    final generacion = _generacion;
    _trabajo = _trabajo.then((_) => _renderizar(pagina, generacion));
  }

  void _zoom(double factor) {
    final escala = _transformacion.value.getMaxScaleOnAxis();
    final destino = (escala * factor).clamp(1.0, 5.0);
    _transformacion.value = _transformacion.value.clone()
      ..scaleByDouble(destino / escala, destino / escala, 1, 1);
  }

  @override
  void didUpdateWidget(covariant VisorPdfInstitucional oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) {
      _transformacion.value = Matrix4.identity();
      _abrir();
    }
  }

  @override
  void dispose() {
    _generacion++;
    unawaited(
      _trabajo.then((_) async {
        await _pdf?.close();
        _pdf = null;
      }),
    );
    _transformacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        children: [
          IconButton(
            tooltip: 'Página anterior',
            onPressed: !_cargando && _pagina > 1
                ? () => _ir(_pagina - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            _total == 0 ? 'Preparando páginas…' : 'Página $_pagina de $_total',
            key: const ValueKey('contador-pdf'),
          ),
          IconButton(
            tooltip: 'Página siguiente',
            onPressed: !_cargando && _pagina < _total
                ? () => _ir(_pagina + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: 'Ampliar documento',
            onPressed: _imagen != null ? () => _zoom(1.5) : null,
            icon: const Icon(Icons.zoom_in),
          ),
          IconButton(
            tooltip: 'Reducir documento',
            onPressed: _imagen != null ? () => _zoom(1 / 1.5) : null,
            icon: const Icon(Icons.zoom_out),
          ),
        ],
      ),
      Expanded(
        child: ColoredBox(
          color: const Color(0xFFF0F2F0),
          child: _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_error!),
                      ),
                      TextButton(
                        onPressed: () => setState(_abrir),
                        child: const Text('Reintentar PDF'),
                      ),
                    ],
                  ),
                )
              : _cargando || _imagen == null
              ? const Center(child: CircularProgressIndicator())
              : InteractiveViewer(
                  transformationController: _transformacion,
                  maxScale: 5,
                  child: SizedBox.expand(
                    child: Image.memory(
                      _imagen!,
                      fit: BoxFit.contain,
                      semanticLabel: 'Página $_pagina de $_total de la nota',
                      errorBuilder: (_, _, _) => const Center(
                        child: Text('No se pudo mostrar esta página.'),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    ],
  );
}
