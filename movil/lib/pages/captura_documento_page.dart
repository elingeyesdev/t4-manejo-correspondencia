import 'dart:async';

import 'package:flutter/material.dart';

import '../services/camara_documento.dart';
import '../theme/sakai_theme.dart';
import '../widgets/sakai_widgets.dart';

class CapturaDocumentoPage extends StatefulWidget {
  const CapturaDocumentoPage({
    super.key,
    required this.codigo,
    this.camara,
    this.instruccion,
  });
  final String codigo;
  final String? instruccion;
  final CamaraDocumento? camara;

  @override
  State<CapturaDocumentoPage> createState() => _CapturaDocumentoPageState();
}

class _CapturaDocumentoPageState extends State<CapturaDocumentoPage>
    with WidgetsBindingObserver {
  late final CamaraDocumento _camara = widget.camara ?? CamaraAndroid();
  FotoDocumento? _foto;
  ErrorCamara? _error;
  bool _ocupado = false, _enVivo = false, _reanudar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive && _enVivo && !_ocupado) {
      _reanudar = true;
      setState(() => _enVivo = false);
      unawaited(_camara.cerrar());
    } else if (state == AppLifecycleState.resumed && _reanudar && !_ocupado) {
      _reanudar = false;
      unawaited(_abrir(solicitarPermiso: false));
    }
  }

  Future<void> _abrir({bool solicitarPermiso = true}) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await _camara.iniciar(solicitarPermiso: solicitarPermiso);
      if (!mounted) return;
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        _reanudar = true;
        await _camara.cerrar();
      } else {
        setState(() => _enVivo = true);
      }
    } on ErrorCamara catch (e) {
      if (mounted) setState(() => _error = e);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = const ErrorCamara(
            'No se pudo abrir la cámara. Vuelve a intentar.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _tomar() async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final foto = await _camara.tomar();
      if (!mounted) {
        await foto.descartar();
        return;
      }
      setState(() {
        _foto = foto;
        _enVivo = false;
      });
      await _camara.cerrar();
    } on ErrorCamara catch (e) {
      if (mounted) setState(() => _error = e);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = const ErrorCamara(
            'No se pudo tomar la foto. Vuelve a intentar.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _repetir() async {
    final anterior = _foto;
    setState(() => _foto = null);
    await anterior?.descartar();
    if (mounted) await _abrir();
  }

  Future<void> _ajustes() async {
    _reanudar = true;
    if (!await _camara.abrirAjustes() && mounted) {
      _reanudar = false;
      setState(
        () => _error = const ErrorCamara(
          'No se pudieron abrir los ajustes. Puedes habilitar Cámara en los ajustes del teléfono.',
          abrirAjustes: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_camara.cerrar());
    unawaited(_foto?.descartar() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fotografiar documento')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(widget.codigo, style: const TextStyle(color: Sakai.muted)),
        const SizedBox(height: 16),
        SakaiSection(
          title: _foto == null
              ? 'Antes de tomar la foto'
              : 'Revisa que se lea bien',
          icon: Icons.photo_camera_outlined,
          color: Sakai.green,
          background: Sakai.mint,
          child: Text(
            _foto == null
                ? 'Incluye la hoja completa. Busca buena luz, evita sombras y reflejos y mantén el teléfono quieto.'
                : 'Comprueba que el texto esté enfocado, que no falten bordes y que ningún dedo cubra la hoja.',
          ),
        ),
        const SizedBox(height: 16),
        if (_foto != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ColoredBox(
              color: Sakai.border,
              child: Image.memory(
                _foto!.bytes,
                height: 360,
                fit: BoxFit.contain,
                semanticLabel: 'Vista previa de la foto del documento',
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No se pudo mostrar la foto. Vuelve a tomarla.'),
                ),
              ),
            ),
          )
        else if (_enVivo)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(height: 360, child: Center(child: _camara.vista())),
          )
        else if (_error == null && !_ocupado)
          const SakaiPanel(
            child: Column(
              children: [
                Icon(
                  Icons.document_scanner_outlined,
                  size: 64,
                  color: Sakai.blue,
                ),
                SizedBox(height: 16),
                Text('La cámara se abrirá cuando pulses el botón.'),
                SizedBox(height: 8),
                Text(
                  'Android te permitirá elegir cómo autorizar el acceso.',
                  style: TextStyle(color: Sakai.muted),
                ),
              ],
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: SakaiPanel(child: Text(_error!.mensaje)),
          ),
          if (_error!.abrirAjustes)
            OutlinedButton.icon(
              onPressed: _ocupado ? null : _ajustes,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Abrir ajustes'),
            ),
        ],
        const SizedBox(height: 16),
        if (_ocupado) const Center(child: CircularProgressIndicator()),
        if (_foto != null) ...[
          Text(
            widget.instruccion ?? 'Pulsa Usar foto para volver al documento y después Subir foto para guardarla.',
            style: TextStyle(color: Sakai.muted),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _ocupado
                ? null
                : () {
                    final foto = _foto!;
                    _foto =
                        null; // La pantalla del documento asume su limpieza.
                    Navigator.of(context).pop(foto);
                  },
            icon: const Icon(Icons.check),
            label: const Text('Usar foto'),
          ),
          OutlinedButton.icon(
            onPressed: _ocupado ? null : _repetir,
            icon: const Icon(Icons.refresh),
            label: const Text('Volver a tomar'),
          ),
        ] else if (!_ocupado && !(_error?.abrirAjustes ?? false))
          FilledButton.icon(
            onPressed: _enVivo ? _tomar : _abrir,
            icon: Icon(
              _enVivo ? Icons.camera_alt_outlined : Icons.photo_camera_outlined,
            ),
            label: Text(_enVivo ? 'Tomar foto' : 'Abrir cámara'),
          ),
        TextButton(
          onPressed: _ocupado ? null : () => Navigator.of(context).pop(),
          child: Text(_foto == null ? 'Cancelar' : 'Descartar'),
        ),
      ],
    ),
  );
}
