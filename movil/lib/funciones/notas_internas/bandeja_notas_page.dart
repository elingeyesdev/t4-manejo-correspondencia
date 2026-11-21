import 'package:flutter/material.dart';

import '../../compartido/api/laravel_api.dart';
import '../../compartido/diseno/sakai_widgets.dart';
import '../../compartido/diseno/institucional.dart';
import 'detalle_nota_page.dart';
import 'nota_interna.dart';
import 'notas_api.dart';

class BandejaNotasPage extends StatefulWidget {
  const BandejaNotasPage({
    super.key,
    required this.api,
    this.puedeAdjuntar = true,
  });
  final ApiLaravel api;
  final bool puedeAdjuntar;

  @override
  State<BandejaNotasPage> createState() => _BandejaNotasPageState();
}

class _BandejaNotasPageState extends State<BandejaNotasPage> {
  BandejaNota _bandeja = BandejaNota.revisar;
  final _notas = <NotaInterna>[];
  bool _cargando = false, _reintentarInicio = true;
  String? _error;
  int _pagina = 0, _ultima = 1, _generacion = 0;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargar(reiniciar: true);
  }

  Future<void> _cargar({bool reiniciar = false}) async {
    if (_cargando) return;
    final generacion = ++_generacion;
    final bandeja = _bandeja;
    final token = widget.api.token;
    final pagina = reiniciar ? 1 : _pagina + 1;
    setState(() {
      _cargando = true;
      _error = null;
      _reintentarInicio = reiniciar;
    });
    try {
      final resultado = await NotasApi(widget.api)
          .bandeja(bandeja, pagina: pagina);
      if (!mounted || generacion != _generacion) return;
      if (token != widget.api.token) {
        throw const ErrorLaravel(
          'Tu sesión cambió. Vuelve a ingresar.',
          estado: 401,
        );
      }
      setState(() {
        final unicas = <String, NotaInterna>{
          if (!reiniciar)
            for (final n in _notas) n.id: n,
          for (final n in resultado.notas) n.id: n,
        };
        _notas
          ..clear()
          ..addAll(unicas.values);
        _pagina = resultado.actual;
        _ultima = resultado.ultima;
      });
    } on ErrorLaravel catch (e) {
      if (!mounted || generacion != _generacion) return;
      setState(() {
        _error = e.mensaje;
        if ({401, 403, 404}.contains(e.estado)) _notas.clear();
      });
    } finally {
      if (mounted && generacion == _generacion) {
        setState(() => _cargando = false);
      }
    }
  }

  void _cambiar(int indice) {
    final siguiente = BandejaNota.values[indice];
    if (siguiente == _bandeja) return;
    setState(() {
      _generacion++;
      _bandeja = siguiente;
      _notas.clear();
      _pagina = 0;
      _ultima = 1;
      _cargando = false;
    });
    _cargar(reiniciar: true);
  }

  Future<void> _abrir(NotaInterna nota) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetalleNotaPage(
          api: widget.api,
          id: nota.id,
          soloLectura: _bandeja == BandejaNota.copias,
          puedeAdjuntar: widget.puedeAdjuntar,
        ),
      ),
    );
    if (mounted) await _cargar(reiniciar: true);
  }

  @override
  Widget build(BuildContext context) =>
      InterfazInstitucional(builder: _construir);

  Widget _construir(BuildContext context) => DefaultTabController(
    length: BandejaNota.values.length,
    child: Scaffold(
      appBar: CabeceraInstitucional(
        titulo: 'Notas internas',
        actions: [
          IconButton(
            tooltip: 'Actualizar notas',
            onPressed: _cargando ? null : () => _cargar(reiniciar: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _cargar(reiniciar: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Bandeja de notas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            TabBar(
              isScrollable: true,
              onTap: _cambiar,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              tabs: [for (final b in BandejaNota.values) Tab(text: b.titulo)],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('buscar-notas'),
              decoration: const InputDecoration(
                labelText: 'Buscar por CITE o asunto',
                prefixIcon: Icon(Icons.search),
                helperText: 'Busca en las notas cargadas de esta bandeja.',
              ),
              onChanged: (texto) =>
                  setState(() => _busqueda = texto.trim().toLowerCase()),
            ),
            const SizedBox(height: 16),
            Text(
              _bandeja == BandejaNota.copias
                  ? 'Copias para tu conocimiento. No requieren una acción.'
                  : 'Notas disponibles para tu cuenta y unidad.',
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: _cargando
                    ? null
                    : () => _cargar(reiniciar: _reintentarInicio),
                child: const Text('Reintentar'),
              ),
            ],
            if (_cargando) const LinearProgressIndicator(),
            if (!_cargando && _error == null && _notas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay notas en esta bandeja.'),
              ),
            if (_busqueda.isNotEmpty && !_notas.any(_coincide))
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Sin coincidencias en las notas cargadas.'),
              ),
            for (final nota in _notas.where(_coincide)) ...[
              ListTile(
                key: ValueKey(nota.id),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nota.cite,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nota.asunto,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('Unidad de origen: ${nota.origen}'),
                    Text('Unidad destinataria: ${nota.destinataria}'),
                    Text(
                      sakaiDate(nota.datos['fecha_ultimo_movimiento']),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    EstadoInstitucional(nota.etiquetaEstado),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              _bandeja == BandejaNota.copias
                                  ? 'Ver copia'
                                  : nota.siguienteAccion,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward,
                            size: 18,
                            color: Institucional.accion,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: _cargando || _error != null ? null : () => _abrir(nota),
              ),
              const Divider(height: 1),
            ],
            if (_pagina < _ultima && _error == null)
              TextButton(
                onPressed: _cargando ? null : () => _cargar(),
                child: const Text('Cargar más notas'),
              ),
          ],
        ),
      ),
    ),
  );

  bool _coincide(NotaInterna nota) =>
      _busqueda.isEmpty ||
      nota.asunto.toLowerCase().contains(_busqueda) ||
      nota.cite.toLowerCase().contains(_busqueda);
}
