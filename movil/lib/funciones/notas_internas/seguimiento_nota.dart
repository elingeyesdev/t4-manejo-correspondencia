import 'package:flutter/material.dart';

import '../../compartido/api/laravel_api.dart';
import '../../compartido/diseno/institucional.dart';

class SeguimientoNota {
  SeguimientoNota._(this.pasos, this.etiqueta, this.unidad);
  final List<PasoNota> pasos;
  final String etiqueta, unidad;
  static const etapas = {
    'preparacion': 'Preparación',
    'revision': 'Revisión VÍA',
    'recepcion': 'Recepción',
    'atencion': 'Atención',
    'cierre': 'Cierre',
  };

  factory SeguimientoNota.desdeJson(Object? valor) {
    if (valor is! Map ||
        !etapas.containsKey(valor['etapa']) ||
        valor['etiqueta'] is! String ||
        (valor['etiqueta'] as String).trim().isEmpty ||
        valor['unidad'] is! Map ||
        valor['unidad']['id'] is! int ||
        valor['unidad']['nombre'] is! String ||
        (valor['unidad']['nombre'] as String).trim().isEmpty) {
      throw const ErrorLaravel(
        'No se pudo interpretar el seguimiento confirmado.',
      );
    }
    final pasos = [
      for (final etapa in etapas.entries)
        PasoNota._(
          etapa.key,
          etapa.value,
          etapa.key == valor['etapa']
              ? valor['unidad']['nombre'] as String
              : null,
          etapa.key == valor['etapa'] ? 'actual' : 'inactiva',
        ),
    ];
    return SeguimientoNota._(
      List.unmodifiable(pasos),
      valor['etiqueta'] as String,
      valor['unidad']['nombre'] as String,
    );
  }
}

class PasoNota {
  PasoNota._(this.id, this.etiqueta, this.unidad, this.estado);
  final String id, etiqueta, estado;
  final String? unidad;
}

class BarraSeguimientoNota extends StatefulWidget {
  const BarraSeguimientoNota({super.key, required this.seguimiento});
  final SeguimientoNota seguimiento;
  @override
  State<BarraSeguimientoNota> createState() => _BarraSeguimientoNotaState();
}

class _BarraSeguimientoNotaState extends State<BarraSeguimientoNota> {
  final _scroll = ScrollController();
  SeguimientoNota get seguimiento => widget.seguimiento;
  String get _activa =>
      seguimiento.pasos.singleWhere((p) => p.estado == 'actual').id;
  @override
  void initState() {
    super.initState();
    _centrar();
  }

  @override
  void didUpdateWidget(covariant BarraSeguimientoNota oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seguimiento.pasos
            .singleWhere((p) => p.estado == 'actual')
            .id !=
        _activa) {
      _centrar();
    }
  }

  void _centrar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final indice = seguimiento.pasos.indexWhere((p) => p.estado == 'actual');
      final offset =
          (indice * 142 - _scroll.position.viewportDimension / 2 + 61)
              .clamp(0.0, _scroll.position.maxScrollExtent)
              .toDouble();
      _scroll.jumpTo(offset);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Seguimiento', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      SizedBox(
        height:
            132 *
            (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 3.0),
        child: ListView.separated(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          itemCount: seguimiento.pasos.length,
          separatorBuilder: (_, _) => const Padding(
            padding: EdgeInsets.only(top: 17),
            child: SizedBox(width: 20, child: Divider()),
          ),
          itemBuilder: (context, i) {
            final paso = seguimiento.pasos[i];
            final activo = paso.estado == 'actual';
            return Semantics(
              label:
                  '${paso.etiqueta}, ${activo ? 'etapa actual' : 'etapa del recorrido'}${paso.unidad == null ? '' : ', ${paso.unidad}'}',
              child: SizedBox(
                width: 122,
                child: Column(
                  children: [
                    Icon(
                      activo ? Icons.mail : Icons.radio_button_unchecked,
                      key: activo ? const ValueKey('sobre-etapa-actual') : null,
                      color: activo ? Institucional.accion : Colors.grey,
                      size: 28,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      paso.etiqueta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: activo
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (paso.unidad != null)
                      Text(
                        paso.unidad!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      Text('${seguimiento.etiqueta} · ${seguimiento.unidad}'),
    ],
  );
}

class ConstanciaNota {
  ConstanciaNota._(
    this.tipo,
    this.accion,
    this.actor,
    this.unidad,
    this.fecha,
    this.version,
  );
  final String tipo, accion, actor, unidad;
  final DateTime fecha;
  final int? version;
  factory ConstanciaNota.desdeJson(Object? valor) {
    if (valor is! Map ||
        !{'firma', 'recepcion'}.contains(valor['tipo']) ||
        valor['accion'] is! String ||
        valor['actor'] is! Map ||
        valor['actor']['nombre'] is! String ||
        valor['unidad'] is! Map ||
        valor['unidad']['nombre'] is! String ||
        valor['fecha'] is! String ||
        DateTime.tryParse(valor['fecha'] as String) == null ||
        (valor['version'] != null &&
            (valor['version'] is! int || valor['version'] < 1))) {
      throw const ErrorLaravel('No se pudo interpretar una constancia.');
    }
    return ConstanciaNota._(
      valor['tipo'] as String,
      valor['accion'] as String,
      valor['actor']['nombre'] as String,
      valor['unidad']['nombre'] as String,
      DateTime.parse(valor['fecha'] as String),
      valor['version'] as int?,
    );
  }

  factory ConstanciaNota.desdeSello(Object? valor) {
    if (valor is! Map ||
        valor['id'] is! String ||
        (valor['id'] as String).isEmpty ||
        (valor['cite'] != null && valor['cite'] is! String) ||
        (valor['unidad'] != null && valor['unidad'] is! String) ||
        (valor['funcionario'] != null && valor['funcionario'] is! String) ||
        valor['fecha_hora'] is! String ||
        DateTime.tryParse(valor['fecha_hora'] as String) == null) {
      throw const ErrorLaravel('No se pudo interpretar el sello de recepción.');
    }
    return ConstanciaNota._(
      'recepcion',
      'recepcion_inicial',
      valor['funcionario'] as String? ?? 'No disponible',
      valor['unidad'] as String? ?? 'No disponible',
      DateTime.parse(valor['fecha_hora'] as String),
      null,
    );
  }
}

class ConstanciasNota extends StatelessWidget {
  const ConstanciasNota({super.key, required this.constancias});
  final List<ConstanciaNota> constancias;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Firmas y recepción',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      for (final c in constancias)
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Institucional.borde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.tipo == 'recepcion'
                    ? 'RECIBIDO · DEMOSTRACIÓN'
                    : 'Firma registrada',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Institucional.accion,
                ),
              ),
              Text(switch (c.accion) {
                'firma_remitente' => 'Firma del remitente',
                'conformidad_via' => 'Conformidad VÍA',
                'recepcion_inicial' => 'Recepción inicial',
                _ => c.accion.replaceAll('_', ' '),
              }),
              Text(c.actor),
              Text(c.unidad),
              Text(_fechaBolivia(c.fecha)),
            ],
          ),
        ),
    ],
  );

  static String _fechaBolivia(DateTime fecha) {
    final hora = fecha.toUtc().subtract(const Duration(hours: 4));
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(hora.day)}/${dos(hora.month)}/${hora.year} '
        '${dos(hora.hour)}:${dos(hora.minute)}:${dos(hora.second)} · Bolivia';
  }
}
