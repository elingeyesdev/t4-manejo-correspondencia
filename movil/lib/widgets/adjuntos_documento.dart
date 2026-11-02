import 'dart:async';

import 'package:flutter/material.dart';

import '../pages/adjunto_page.dart';
import '../pages/captura_documento_page.dart';
import '../services/adjuntos_api.dart';
import '../services/camara_documento.dart';
import '../services/laravel_api.dart';
import '../theme/sakai_theme.dart';
import 'sakai_widgets.dart';

class AdjuntosDocumento extends StatefulWidget {
  const AdjuntosDocumento({
    super.key,
    required this.api,
    required this.documentoId,
    required this.codigo,
    required this.alCambiar,
    this.alOcuparse,
    this.puedeAdjuntar = true,
    this.crearCamara,
    this.fotoInicial,
    this.nombreInicial,
    this.subirAlAbrir = false,
  });
  final FotoDocumento? fotoInicial;
  final String? nombreInicial;
  final bool subirAlAbrir;
  final ApiLaravel api;
  final String documentoId, codigo;
  final ValueChanged<bool> alCambiar;
  final ValueChanged<bool>? alOcuparse;
  final bool puedeAdjuntar;
  final CamaraDocumento Function()? crearCamara;
  @override
  State<AdjuntosDocumento> createState() => _AdjuntosDocumentoState();
}

class _AdjuntosDocumentoState extends State<AdjuntosDocumento>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late final _servicio = AdjuntosApi(widget.api);
  FotoDocumento? _foto;
  String? _nombre, _error, _errorLista, _aviso;
  final _archivos = <Adjunto>[];
  bool _abriendo = false,
      _enviando = false,
      _incierta = false,
      _cargando = false;
  bool _reiniciarAlReintentar = true;
  bool _recargarDespues = false;
  int _pagina = 0, _ultima = 1;

  @override
  void initState() {
    super.initState();
    _foto = widget.fotoInicial;
    _nombre = widget.nombreInicial;
    unawaited(_cargar(reiniciar: true));
    if (widget.subirAlAbrir && _foto != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_subir());
      });
    }
  }

  Future<void> _cargar({bool reiniciar = false}) async {
    if (_cargando) {
      if (reiniciar) _recargarDespues = true;
      return;
    }
    setState(() {
      _cargando = true;
      _errorLista = null;
      _reiniciarAlReintentar = reiniciar;
    });
    try {
      final r = await _servicio.listar(
        widget.documentoId,
        pagina: reiniciar ? 1 : _pagina + 1,
      );
      if (!mounted) return;
      setState(() {
        if (reiniciar) _archivos.clear();
        for (final a in r.archivos) {
          if (!_archivos.any((actual) => actual.id == a.id)) _archivos.add(a);
        }
        _pagina = r.actual;
        _ultima = r.ultima;
      });
    } on ErrorLaravel catch (e) {
      if (mounted) setState(() => _errorLista = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(() => _errorLista = 'No se pudieron consultar los adjuntos.');
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
        if (_recargarDespues) {
          _recargarDespues = false;
          unawaited(_cargar(reiniciar: true));
        }
      }
    }
  }

  Future<void> _capturar() async {
    if (_abriendo || _enviando) return;
    setState(() => _abriendo = true);
    final nueva = await Navigator.of(context).push<FotoDocumento>(
      MaterialPageRoute(
        builder: (_) => CapturaDocumentoPage(
          codigo: widget.codigo,
          camara: widget.crearCamara?.call(),
        ),
      ),
    );
    if (!mounted) {
      await nueva?.descartar();
      return;
    }
    if (nueva != null) {
      try {
        final tipo = AdjuntosApi.tipoFoto(nueva.bytes);
        final anterior = _foto;
        setState(() {
          _foto = nueva;
          _nombre =
              'foto-${nuevaClaveSolicitud()}.${tipo == 'image/png' ? 'png' : 'jpg'}';
          _error = null;
          _aviso = null;
          _incierta = false;
        });
        widget.alCambiar(true);
        await anterior?.descartar();
      } on ErrorLaravel catch (e) {
        await nueva.descartar();
        if (mounted) setState(() => _error = e.mensaje);
      }
    }
    if (mounted) setState(() => _abriendo = false);
  }

  void _ocupacion(bool valor) {
    setState(() => _enviando = valor);
    widget.alOcuparse?.call(valor);
  }

  Future<void> _confirmar(Adjunto adjunto) async {
    final foto = _foto;
    setState(() {
      _foto = null;
      _nombre = null;
      _incierta = false;
      _error = null;
      _aviso = 'Foto guardada correctamente.';
      if (!_archivos.any((a) => a.id == adjunto.id)) {
        _archivos.insert(0, adjunto);
      }
    });
    widget.alCambiar(false);
    await foto?.descartar();
  }

  Future<void> _subir() async {
    if (_enviando || _foto == null || _incierta) return;
    _ocupacion(true);
    setState(() {
      _error = null;
      _aviso = null;
    });
    try {
      final r = await _servicio.subir(widget.documentoId, _foto!, _nombre!);
      if (!mounted) return;
      await _confirmar(r);
      if (mounted) await _cargar(reiniciar: true);
    } on ErrorLaravel catch (e) {
      if (mounted) {
        setState(() {
          _error = e.mensaje;
          _incierta = e.codigo == 'SUBIDA_INCIERTA';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No pudimos confirmar la subida. Comprueba los adjuntos antes de volver a enviar.';
          _incierta = true;
        });
      }
    } finally {
      if (mounted) _ocupacion(false);
    }
  }

  Future<void> _comprobar() async {
    if (_enviando || _foto == null) return;
    _ocupacion(true);
    try {
      final r = await _servicio.comprobar(widget.documentoId, _foto!, _nombre!);
      if (!mounted) return;
      if (r != null) {
        await _confirmar(r);
      } else {
        setState(
          () => _error = 'La foto todavía no aparece en los adjuntos. Espera un momento y vuelve a comprobar antes de enviarla otra vez.',
        );
      }
      if (mounted) await _cargar(reiniciar: true);
    } on ErrorLaravel catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo comprobar la subida. Revisa la conexión.',
        );
      }
    } finally {
      if (mounted) _ocupacion(false);
    }
  }

  Future<void> _reenviar() async {
    final aceptar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Volver a enviar la foto?'),
        content: const Text(
          'Si el primer envío se guardó pero su respuesta se perdió, podrías crear un duplicado. Comprueba primero los adjuntos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Volver a enviar'),
          ),
        ],
      ),
    );
    if (aceptar == true && mounted) {
      setState(() => _incierta = false);
      await _subir();
    }
  }

  Future<void> _descartar() async {
    final anterior = _foto;
    setState(() {
      _foto = null;
      _nombre = null;
      _error = null;
      _incierta = false;
    });
    widget.alCambiar(false);
    await anterior?.descartar();
  }

  @override
  void dispose() {
    unawaited(_foto?.descartar() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SakaiSection(
      title: 'Adjuntos',
      icon: Icons.attach_file,
      color: Sakai.cyan,
      background: Sakai.cyanLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_aviso != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _aviso!,
                  style: const TextStyle(color: Sakai.green),
                ),
              ),
            ),
          if (widget.puedeAdjuntar && _foto == null) ...[
            const Text('Fotografía la hoja y guárdala junto a este documento.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _abriendo || _enviando ? null : _capturar,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Adjuntar foto'),
            ),
          ],
          if (_foto != null) ...[
            const Text('Revisa la foto antes de enviarla.'),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _foto!.bytes,
                height: 240,
                fit: BoxFit.contain,
                semanticLabel: 'Foto lista para subir',
                errorBuilder: (_, _, _) =>
                    const Text('No se pudo mostrar la foto. Vuelve a tomarla.'),
              ),
            ),
            const SizedBox(height: 12),
            if (!_incierta)
              FilledButton.icon(
                onPressed: _enviando ? null : _subir,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Subir foto'),
              ),
            if (_incierta) ...[
              FilledButton.icon(
                onPressed: _enviando ? null : _comprobar,
                icon: const Icon(Icons.refresh),
                label: const Text('Comprobar subida'),
              ),
              TextButton(
                onPressed: _enviando ? null : _reenviar,
                child: const Text('Volver a enviar'),
              ),
            ],
            OutlinedButton.icon(
              onPressed: _abriendo || _enviando ? null : _capturar,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Cambiar foto'),
            ),
            TextButton(
              onPressed: _enviando || _abriendo ? null : _descartar,
              child: const Text('Descartar foto'),
            ),
          ],
          if (_enviando) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Espera a que termine la operación.'),
          ],
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Archivos guardados',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: 'Actualizar adjuntos',
                onPressed: _cargando || _enviando
                    ? null
                    : () => _cargar(reiniciar: true),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (_errorLista != null) ...[
            Text(_errorLista!),
            TextButton(
              onPressed: _cargando
                  ? null
                  : () => _cargar(reiniciar: _reiniciarAlReintentar),
              child: const Text('Reintentar adjuntos'),
            ),
          ],
          if (!_cargando && _errorLista == null && _archivos.isEmpty)
            const Text('Este documento todavía no tiene adjuntos.'),
          for (final archivo in _archivos)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                archivo.mime == 'application/pdf'
                    ? Icons.picture_as_pdf_outlined
                    : Icons.image_outlined,
                color: archivo.mime == 'application/pdf'
                    ? Sakai.violet
                    : Sakai.blue,
              ),
              title: Text(
                archivo.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${archivo.tamanoTexto} · ${sakaiDate(archivo.fecha)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _enviando
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            AdjuntoPage(servicio: _servicio, adjunto: archivo),
                      ),
                    ),
            ),
          if (_cargando) const Center(child: CircularProgressIndicator()),
          if (!_cargando && _pagina > 0 && _pagina < _ultima)
            OutlinedButton(
              onPressed: () => _cargar(),
              child: const Text('Cargar más adjuntos'),
            ),
        ],
      ),
    );
  }
}
