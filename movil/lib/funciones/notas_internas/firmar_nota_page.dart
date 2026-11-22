import 'package:flutter/material.dart';

import '../../compartido/diseno/institucional.dart';
import 'firma_nota.dart';
import 'nota_interna.dart';

class FirmarNotaPage extends StatefulWidget {
  const FirmarNotaPage({super.key, required this.nota, required this.titulo});

  final NotaInterna nota;
  final String titulo;

  @override
  State<FirmarNotaPage> createState() => _FirmarNotaPageState();
}

class _FirmarNotaPageState extends State<FirmarNotaPage> {
  final _trazos = <List<List<int>>>[];
  bool _dibujando = false;
  bool _confirmada = false;
  String? _aviso;

  FirmaNota? get _firma {
    try {
      return FirmaNota.desdeJson(_trazos);
    } on FormatException {
      return null;
    }
  }

  void _confirmar() {
    if (_confirmada || _dibujando) return;
    final firma = _firma;
    if (firma == null) return;
    setState(() => _confirmada = true);
    Navigator.of(context).pop(firma);
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

  @override
  Widget build(BuildContext context) => InterfazInstitucional(
    builder: (context) => Scaffold(
      appBar: CabeceraInstitucional(titulo: widget.titulo),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Revisa la nota antes de firmar',
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
          Text(
            widget.nota.cuerpo ?? '',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const Divider(),
          Text(
            'Firma con el dedo dentro del recuadro.',
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
                  child: GestureDetector(
                    key: const ValueKey('area-firma'),
                    behavior: HitTestBehavior.opaque,
                    onPanDown: (d) =>
                        _punto(d.localPosition, limites.biggest, inicio: true),
                    onPanUpdate: (d) =>
                        _punto(d.localPosition, limites.biggest),
                    onPanEnd: (_) => setState(() => _dibujando = false),
                    onPanCancel: () => setState(() => _dibujando = false),
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
          TextButton.icon(
            onPressed: _trazos.isEmpty
                ? null
                : () => setState(() {
                    _trazos.clear();
                    _dibujando = false;
                    _aviso = null;
                  }),
            icon: const Icon(Icons.clear),
            label: const Text('Limpiar firma'),
          ),
          if (_aviso != null) Text(_aviso!),
          const Text(
            'Al confirmar, se enviará esta firma para la versión de la nota que acabas de revisar.',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _confirmada || _dibujando || _firma == null
                ? null
                : _confirmar,
            child: const Text('Confirmar firma'),
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
