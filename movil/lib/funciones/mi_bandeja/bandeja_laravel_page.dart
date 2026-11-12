import 'package:flutter/material.dart';

import '../../compartido/api/laravel_api.dart';
import 'detalle_laravel_page.dart';
import '../qr/consulta_qr_page.dart';

export 'detalle_laravel_page.dart';
import '../../compartido/diseno/sakai_theme.dart';
import '../../compartido/diseno/sakai_widgets.dart';

class BandejaLaravelPage extends StatefulWidget {
  const BandejaLaravelPage({
    super.key,
    required this.api,
    this.puedeAdjuntar = true,
  });
  final bool puedeAdjuntar;
  final ApiLaravel api;
  @override
  State<BandejaLaravelPage> createState() => _BandejaLaravelPageState();
}

class _BandejaLaravelPageState extends State<BandejaLaravelPage> {
  final _documentos = <Map<String, dynamic>>[];
  bool _cargando = false;
  bool _reiniciarAlReintentar = true;
  String? _error;
  String _busqueda = '';
  int _pagina = 0;
  int _ultima = 1;
  @override
  void initState() {
    super.initState();
    _cargar(reiniciar: true);
  }

  Future<void> _cargar({bool reiniciar = false}) async {
    if (_cargando) return;
    setState(() {
      _cargando = true;
      _reiniciarAlReintentar = reiniciar;
      _error = null;
    });
    try {
      final pagina = reiniciar ? 1 : _pagina + 1;
      final r = await widget.api.enviar('GET', 'documentos?page=$pagina');
      final data = r['data'];
      if (data is! List ||
          data.any((d) => d is! Map<String, dynamic>) ||
          r['last_page'] is! int) {
        throw const ErrorLaravel('La bandeja recibida no es válida.');
      }
      if (!mounted) return;
      setState(() {
        if (reiniciar) _documentos.clear();
        _documentos.addAll(data.cast<Map<String, dynamic>>());
        _pagina = pagina;
        _ultima = r['last_page'] as int;
      });
    } on ErrorLaravel catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  bool _coincide(Map<String, dynamic> d) =>
      _busqueda.isEmpty ||
      [
        'asunto',
        'remitente',
        'codigo',
        'guia',
      ].any((key) => '${d[key] ?? ''}'.toLowerCase().contains(_busqueda));

  (Color, Color) _acento(Map<String, dynamic> d) {
    final tipo = (d['tipo'] as Map?)?['name']?.toString().toLowerCase() ?? '';
    if (tipo.contains('informe')) return (Sakai.violet, Sakai.violetLight);
    if (tipo.contains('nota') || tipo.contains('memor')) {
      return (Sakai.amber, Sakai.amberLight);
    }
    if (tipo.contains('carta')) return (Sakai.cyan, Sakai.cyanLight);
    return (Sakai.blue, Sakai.blueLight);
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () => _cargar(reiniciar: true),
    child: ListView(
      padding: const EdgeInsets.all(20),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Bandeja de correspondencia',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              onPressed: _cargando ? null : () => _cargar(reiniciar: true),
              tooltip: 'Actualizar bandeja',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Documentos disponibles para tu cuenta y unidad.'),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ConsultaQrPage(
                  api: widget.api,
                  puedeAdjuntar: widget.puedeAdjuntar,
                ),
              ),
            );
            if (mounted) await _cargar(reiniciar: true);
          },
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escanear QR de hoja de ruta'),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: () => _cargar(reiniciar: _reiniciarAlReintentar),
            child: const Text('Reintentar'),
          ),
        ],
        if (!_cargando && _error == null && _documentos.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Todavía no hay correspondencia disponible.'),
          ),

        TextField(
          decoration: const InputDecoration(
            hintText: 'Buscar documento',
            prefixIcon: Icon(PrimeIcons.search),
            helperText: 'Busca en los documentos que ya cargaste.',
          ),
          onChanged: (value) =>
              setState(() => _busqueda = value.trim().toLowerCase()),
        ),
        const SizedBox(height: 16),
        if (_busqueda.isNotEmpty && !_documentos.any(_coincide))
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Sin coincidencias en los documentos cargados.'),
          ),
        for (final d in _documentos.where(_coincide))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DetalleLaravelPage(
                        api: widget.api,
                        id: d['id'] as String,
                        puedeAdjuntar: widget.puedeAdjuntar,
                      ),
                    ),
                  );
                  if (mounted) await _cargar(reiniciar: true);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SakaiIcon(
                        PrimeIcons.file,
                        color: _acento(d).$1,
                        background: _acento(d).$2,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d['asunto'] as String? ?? 'Correspondencia',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${d['remitente'] ?? ''}',
                              style: const TextStyle(color: Sakai.muted),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${d['codigo'] ?? d['guia'] ?? ''}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (d['estado'] != null)
                                  SakaiStatus('${d['estado']}'),
                                Text(
                                  sakaiDate(d['fecha']),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 8, top: 12),
                        child: Icon(PrimeIcons.chevronRight, size: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_cargando)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
        if (!_cargando && _pagina > 0 && _pagina < _ultima)
          OutlinedButton(
            onPressed: _cargar,
            child: const Text('Cargar más documentos'),
          ),
      ],
    ),
  );
}
