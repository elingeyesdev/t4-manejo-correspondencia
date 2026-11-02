import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../services/adjuntos_api.dart';
import '../services/laravel_api.dart';
import '../theme/sakai_theme.dart';

class AdjuntoPage extends StatefulWidget {
  const AdjuntoPage({super.key, required this.servicio, required this.adjunto});
  final AdjuntosApi servicio;
  final Adjunto adjunto;
  @override
  State<AdjuntoPage> createState() => _AdjuntoPageState();
}

class _AdjuntoPageState extends State<AdjuntoPage> {
  late Future<ContenidoAdjunto> _contenido;
  bool _abriendo = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _contenido = widget.servicio.descargar(widget.adjunto);
  }

  Future<void> _abrirPdf(ContenidoAdjunto contenido) async {
    if (_abriendo) return;
    setState(() {
      _abriendo = true;
      _error = null;
    });
    File? file;
    try {
      final temp = await getTemporaryDirectory();
      final carpeta = await Directory(
        '${temp.path}/adjunto-${nuevaClaveSolicitud()}',
      ).create();
      file = File('${carpeta.path}/documento.pdf');
      await file.writeAsBytes(contenido.bytes, flush: true);
      if (!mounted) {
        await file.delete();
        await carpeta.delete();
        return;
      }
      final result = await OpenFilex.open(file.path, type: 'application/pdf');
      if (result.type != ResultType.done) {
        await file.delete();
        await carpeta.delete();
        if (mounted) {
          setState(
            () => _error = result.type == ResultType.noAppToOpen
                ? 'No hay un lector de PDF disponible en este teléfono.'
                : 'No se pudo abrir el PDF. Vuelve a intentar.',
          );
        }
      }
      // El visor necesita leer el archivo después de abrirse. La copia queda en
      // caché privada temporal, nunca en Descargas ni en una dirección pública.
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'No se pudo abrir el PDF. Revisa el espacio disponible.',
        );
      }
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.adjunto.nombre,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: FutureBuilder<ContenidoAdjunto>(
      future: _contenido,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.error is ErrorLaravel
                        ? (snapshot.error as ErrorLaravel).mensaje
                        : 'No se pudo abrir el adjunto.',
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _contenido = widget.servicio.descargar(
                        widget.adjunto,
                      ),
                    ),
                    child: const Text('Reintentar descarga'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final contenido = snapshot.data!;
        if (widget.adjunto.mime != 'application/pdf') {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: Center(
              child: Image.memory(
                contenido.bytes,
                cacheWidth: 2048,
                fit: BoxFit.contain,
                semanticLabel: widget.adjunto.nombre,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No se pudo mostrar esta imagen.'),
                ),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(
              Icons.picture_as_pdf_outlined,
              color: Sakai.violet,
              size: 72,
            ),
            const SizedBox(height: 20),
            Text(widget.adjunto.nombre, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(widget.adjunto.tamanoTexto, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _abriendo ? null : () => _abrirPdf(contenido),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir PDF'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!),
              ),
          ],
        );
      },
    ),
  );
}
