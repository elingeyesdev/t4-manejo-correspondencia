import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../compartido/api/laravel_api.dart';
import '../../compartido/diseno/institucional.dart';
import 'firma_nota.dart';
import 'hoja_nota.dart';
import 'imagen_constancia.dart';
import 'nota_interna.dart';
import 'notas_api.dart';
import 'vista_previa_nota.dart';

class FirmarNotaPage extends StatefulWidget {
  const FirmarNotaPage({
    super.key,
    required this.nota,
    required this.titulo,
    this.api,
    this.accion = AccionNota.firmaRemitente,
  });

  final NotaInterna nota;
  final String titulo;
  final ApiLaravel? api;
  final AccionNota accion;

  @override
  State<FirmarNotaPage> createState() => _FirmarNotaPageState();
}

class _FirmarNotaPageState extends State<FirmarNotaPage> {
  final _trazos = <List<List<int>>>[];
  bool _dibujando = false;
  bool _confirmada = false;
  int? _puntero;
  String? _aviso;
  ImagenConstancia? _imagenFirma, _imagenSello;
  bool _procesando = false, _documentoListo = false;
  bool get _requiereFirma => widget.accion != AccionNota.primeraRecepcion;

  FirmaNota? get _firma {
    try {
      return FirmaNota.desdeJson(_trazos);
    } on FormatException {
      return null;
    }
  }

  Future<void> _confirmar() async {
    if (_confirmada || _procesando || _dibujando || _puntero != null) return;
    final firma = FirmaNota.constancia(
      trazo: _firma,
      firma: _imagenFirma,
      sello: _imagenSello,
    );
    if (_requiereFirma && !firma.tieneFirma) return;
    final api = widget.api;
    if (api == null) {
      setState(() => _confirmada = true);
      Navigator.of(context).pop(firma);
      return;
    }
    if (!_documentoListo) return;
    final token = api.token;
    setState(() {
      _procesando = true;
      _aviso = null;
    });
    try {
      final pdf = await NotasApi(api)
          .previsualizar(widget.nota, widget.accion, firma);
      if (!mounted) return;
      final confirmado = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => VistaPreviaNota(
            nota: widget.nota,
            api: api,
            provisional: pdf,
            confirmar: true,
          ),
        ),
      );
      if (!mounted || confirmado != true) return;
      if (api.token != token) {
        throw const ErrorLaravel(
          'Tu sesión cambió. Vuelve a abrir la nota.',
          estado: 401,
        );
      }
      _confirmada = true;
      Navigator.of(context).pop(firma);
    } on ErrorLaravel catch (e) {
      if (mounted) {
        setState(
          () => _aviso = e.estado == 409
              ? 'La nota cambió. Vuelve al detalle y revisa la versión actual antes de confirmar.'
              : [e.mensaje, ...e.errores.values].join('\n'),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _elegirImagen(bool firma) async {
    if (_procesando || _confirmada) return;
    setState(() {
      _procesando = true;
      _aviso = null;
    });
    try {
      final imagen = await ImagenConstancia.elegir();
      if (!mounted || imagen == null) return;
      setState(() {
        if (firma) {
          _imagenFirma = imagen;
          _trazos.clear();
        } else {
          _imagenSello = imagen;
        }
      });
    } on ErrorLaravel catch (e) {
      if (mounted) setState(() => _aviso = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(
          () => _aviso = 'No se pudo abrir la imagen. Vuelve a seleccionarla.',
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _punto(Offset posicion, Size area, {bool inicio = false}) {
    if (inicio) {
      _dibujando = _trazos.length < 32;
      if (_dibujando) _trazos.add([]);
    }
    if (!_dibujando) {
      setState(() => _aviso = 'Limpia el área para dibujar nuevamente.');
      return;
    }
    if (_trazos.fold<int>(0, (n, t) => n + t.length) >= 2000) {
      setState(() {
        _dibujando = false;
        _aviso =
            'Se alcanzó el límite del trazo. Puedes limpiar y volver a firmar.';
      });
      return;
    }
    final xy = [
      (posicion.dx / area.width * 1000).round().clamp(0, 1000),
      (posicion.dy / area.height * 1000).round().clamp(0, 1000),
    ];
    final trazo = _trazos.last;
    if (trazo.isNotEmpty && trazo.last[0] == xy[0] && trazo.last[1] == xy[1]) {
      return;
    }
    setState(() => trazo.add(xy));
  }

  void _terminar(int puntero) {
    if (_puntero != puntero) return;
    setState(() {
      _puntero = null;
      _dibujando = false;
    });
  }

  @override
  Widget build(BuildContext context) => InterfazInstitucional(
    builder: (context) => Scaffold(
      appBar: CabeceraInstitucional(titulo: widget.titulo),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Revisa la nota antes de confirmar',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text(
            widget.nota.asunto,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DatoInstitucional('DE', widget.nota.emisor),
          DatoInstitucional('A', widget.nota.destinataria),
          if (widget.nota.datos['referencia'] case final String referencia)
            DatoInstitucional('Referencia', referencia),
          DatoInstitucional('Versión', '${widget.nota.version}'),
          const Divider(),
          if (widget.api == null)
            Text(
              widget.nota.cuerpo ?? '',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          if (widget.api != null) ...[
            SizedBox(
              height: 460,
              child: HojaNota(
                api: widget.api!,
                nota: widget.nota,
                alCargar: () {
                  if (mounted && !_documentoListo) {
                    setState(() => _documentoListo = true);
                  }
                },
              ),
            ),
            OutlinedButton.icon(
              onPressed: _procesando
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            VistaPreviaNota(nota: widget.nota, api: widget.api),
                      ),
                    ),
              icon: const Icon(Icons.fullscreen),
              label: const Text('Leer documento completo'),
            ),
          ],
          const Divider(),
          Text(
            _requiereFirma ? 'Firma con el dedo o carga una imagen.' : 'La recepción genera RECIBIDO automáticamente. Agregar tu firma o una imagen de sello es opcional.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.8,
            child: LayoutBuilder(
              builder: (context, limites) => DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Institucional.secundario),
                ),
                child: Semantics(
                  label: 'Área para dibujar la firma',
                  child: RawGestureDetector(
                    key: const ValueKey('area-firma'),
                    behavior: HitTestBehavior.opaque,
                    gestures: {
                      EagerGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            EagerGestureRecognizer
                          >(() => EagerGestureRecognizer(), (_) {}),
                    },
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e) {
                        if (_puntero != null || _confirmada || _procesando) {
                          return;
                        }
                        _imagenFirma = null;
                        _puntero = e.pointer;
                        _punto(e.localPosition, limites.biggest, inicio: true);
                      },
                      onPointerMove: (e) {
                        if (e.pointer == _puntero && _dibujando) {
                          _punto(e.localPosition, limites.biggest);
                        }
                      },
                      onPointerUp: (e) => _terminar(e.pointer),
                      onPointerCancel: (e) => _terminar(e.pointer),
                      child: CustomPaint(
                        painter: _TrazoFirma([
                          for (final t in _trazos)
                            [for (final p in t) List<int>.of(p)],
                        ]),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _trazos.isEmpty || _procesando
                ? null
                : () => setState(() {
                    _trazos.clear();
                    _dibujando = false;
                    _puntero = null;
                    _aviso = null;
                  }),
            icon: const Icon(Icons.clear),
            label: const Text('Limpiar firma'),
          ),
          if (widget.api != null) ...[
            OutlinedButton.icon(
              onPressed: _procesando ? null : () => _elegirImagen(true),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Cargar firma'),
            ),
            if (_imagenFirma != null) ...[
              Image.memory(
                _imagenFirma!.bytes,
                height: 100,
                fit: BoxFit.contain,
                semanticLabel: 'Firma seleccionada',
              ),
              TextButton(
                onPressed: _procesando
                    ? null
                    : () => setState(() => _imagenFirma = null),
                child: const Text('Quitar imagen de firma'),
              ),
            ],
            OutlinedButton.icon(
              onPressed: _procesando ? null : () => _elegirImagen(false),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Cargar sello'),
            ),
            if (_imagenSello != null) ...[
              Image.memory(
                _imagenSello!.bytes,
                height: 100,
                fit: BoxFit.contain,
                semanticLabel: 'Sello seleccionado',
              ),
              TextButton(
                onPressed: _procesando
                    ? null
                    : () => setState(() => _imagenSello = null),
                child: const Text('Quitar imagen de sello'),
              ),
            ],
            const Text(
              'PNG o JPEG de hasta 512 KB y 2000 por 2000 píxeles. El sello es opcional.',
            ),
          ],
          if (_aviso != null) Text(_aviso!),
          Text(
            widget.api == null
                ? 'Al confirmar, se enviará esta firma para la versión de la nota que acabas de revisar.'
                : 'Primero revisa cómo quedan las marcas sobre la hoja. La acción se registrará al confirmar esa vista previa.',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed:
                _confirmada ||
                    _procesando ||
                    _dibujando ||
                    _puntero != null ||
                    (_requiereFirma &&
                        _firma == null &&
                        _imagenFirma == null) ||
                    (widget.api != null && !_documentoListo)
                ? null
                : _confirmar,
            child: Text(
              _procesando
                  ? 'Preparando documento…'
                  : widget.api == null
                  ? 'Confirmar firma'
                  : _requiereFirma
                  ? 'Revisar firma y sello sobre la hoja'
                  : 'Revisar recepción sobre la hoja',
            ),
          ),
        ),
      ),
    ),
  );
}

class _TrazoFirma extends CustomPainter {
  const _TrazoFirma(this.trazos);
  final List<List<List<int>>> trazos;

  @override
  void paint(Canvas canvas, Size size) {
    final tinta = Paint()
      ..color = Institucional.tinta
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.clipRect(Offset.zero & size);
    for (final trazo in trazos) {
      final recorrido = Path();
      for (var i = 0; i < trazo.length; i++) {
        final punto = trazo[i];
        final x = punto[0] / 1000 * size.width;
        final y = punto[1] / 1000 * size.height;
        if (i == 0) {
          recorrido.moveTo(x, y);
        } else {
          recorrido.lineTo(x, y);
        }
      }
      canvas.drawPath(recorrido, tinta);
    }
  }

  @override
  bool shouldRepaint(covariant _TrazoFirma oldDelegate) => true;
}
