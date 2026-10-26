import 'package:flutter/material.dart';

import '../services/laravel_api.dart';

class BandejaLaravelPage extends StatefulWidget {
  const BandejaLaravelPage({super.key, required this.api});
  final ApiLaravel api;
  @override
  State<BandejaLaravelPage> createState() => _BandejaLaravelPageState();
}

class _BandejaLaravelPageState extends State<BandejaLaravelPage> {
  final _documentos = <Map<String, dynamic>>[];
  bool _cargando = false;
  String? _error;
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
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: () => _cargar(reiniciar: _pagina == 0),
            child: const Text('Reintentar'),
          ),
        ],
        if (!_cargando && _error == null && _documentos.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Todavía no hay correspondencia disponible.'),
          ),
        for (final d in _documentos)
          Card(
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(d['asunto'] as String? ?? 'Correspondencia'),
              subtitle: Text(
                '${d['remitente'] ?? ''}\n${d['guia'] ?? ''}\n${d['estado'] ?? ''} · ${d['fecha'] ?? ''}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DetalleLaravelPage(
                    api: widget.api,
                    id: d['id'] as String,
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

class DetalleLaravelPage extends StatefulWidget {
  const DetalleLaravelPage({super.key, required this.api, required this.id});
  final ApiLaravel api;
  final String id;
  @override
  State<DetalleLaravelPage> createState() => _DetalleLaravelPageState();
}

class _DetalleLaravelPageState extends State<DetalleLaravelPage> {
  late Future<Map<String, dynamic>> _documento;
  @override
  void initState() {
    super.initState();
    _documento = _cargar();
  }

  Future<Map<String, dynamic>> _cargar() =>
      widget.api.enviar('GET', 'documentos/${Uri.encodeComponent(widget.id)}');
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalle de correspondencia')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _documento,
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
                        : 'No se pudo abrir el documento.',
                  ),
                  TextButton(
                    onPressed: () => setState(() => _documento = _cargar()),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snapshot.data!;
        final movimientos = d['movimientos'] as List? ?? [];
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              d['asunto'] as String? ?? '',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            for (final entry in {
              'Guía': d['guia'],
              'Código': d['codigo'],
              'Remitente': d['remitente'],
              'Fecha': d['fecha'],
              'Estado': d['estado'],
              'Tipo': (d['tipo'] as Map?)?['name'],
              'Prioridad': (d['prioridad'] as Map?)?['name'],
              'Unidad': (d['unidad'] as Map?)?['name'],
              'Hoja de ruta': (d['hoja'] as Map?)?['codigo'],
            }.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SelectableText('${entry.value ?? 'Sin información'}'),
                  ],
                ),
              ),
            const Divider(),
            Text('Historial', style: Theme.of(context).textTheme.titleLarge),
            for (final m in movimientos.whereType<Map>())
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: Text('${m['action'] ?? ''}'),
                subtitle: Text('${m['occurred_at'] ?? ''}'),
              ),
          ],
        );
      },
    ),
  );
}
