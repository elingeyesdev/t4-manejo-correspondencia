import 'dart:convert';

import '../../compartido/api/laravel_api.dart';
import 'seguimiento_nota.dart';

enum BandejaNota {
  firmar('por_firmar', 'Por firmar'),
  revisar('por_revisar', 'Por revisar'),
  recibir('por_recibir', 'Por recibir'),
  atender('por_atender', 'Por atender'),
  copias('copias', 'Copias'),
  misNotas('mis_notas', 'Mis notas'),
  cerradas('cerradas', 'Cerradas');

  const BandejaNota(this.parametro, this.titulo);
  final String parametro, titulo;
}

class NotaInterna {
  NotaInterna._(this.datos, this.seguimiento, this.constancias);
  final Map<String, dynamic> datos;
  final SeguimientoNota? seguimiento;
  final List<ConstanciaNota> constancias;

  factory NotaInterna.desdeJson(Map<String, dynamic> datos) {
    final acciones = datos['acciones_permitidas'];
    if (datos['id'] is! String ||
        (datos['id'] as String).isEmpty ||
        datos['asunto'] is! String ||
        datos['estado'] is! String ||
        datos['version'] is! int ||
        (datos['version'] as int) < 1 ||
        acciones is! List ||
        acciones.any((a) => a is! String) ||
        !_unidadValida(datos['unidad_origen']) ||
        !_unidadValida(datos['unidad_destinataria'], opcional: true) ||
        !_unidadValida(datos['autor'], opcional: true) ||
        !_unidadValida(datos['unidad_actual'], opcional: true) ||
        !_unidadValida(datos['destino_pendiente'], opcional: true) ||
        !_textoOpcional(datos['cite']) ||
        !_textoOpcional(datos['cuerpo']) ||
        !_textoOpcional(datos['referencia']) ||
        !_textoOpcional(datos['documento_id']) ||
        !_textoOpcional(datos['hoja_id']) ||
        (datos['estado_firma'] != null &&
            !{
              'sin_solicitar',
              'pendiente',
              'firmada',
            }.contains(datos['estado_firma'])) ||
        datos['fecha_ultimo_movimiento'] is! String ||
        DateTime.tryParse(datos['fecha_ultimo_movimiento'] as String) == null) {
      throw const ErrorLaravel(
        'No se pudieron interpretar los datos de la nota.',
      );
    }
    final movimientos = datos['movimientos_nota'];
    if (movimientos != null &&
        (movimientos is! List ||
            movimientos.any((m) => m is! Map<String, dynamic>))) {
      throw const ErrorLaravel(
        'No se pudo interpretar el recorrido de la nota.',
      );
    }
    final seguimiento = datos['seguimiento'] == null
        ? null
        : SeguimientoNota.desdeJson(datos['seguimiento']);
    final constancias = datos['constancias'];
    if (constancias != null && constancias is! List) {
      throw const ErrorLaravel('No se pudieron interpretar las constancias.');
    }
    return NotaInterna._(
      Map.unmodifiable({
        ...datos,
        'acciones_permitidas': List<String>.unmodifiable(
          acciones.cast<String>(),
        ),
      }),
      seguimiento,
      List.unmodifiable([
        ...(constancias as List? ?? [])
            .map(ConstanciaNota.desdeJson)
            .where(
              (c) => datos['sello_recepcion'] == null || c.tipo != 'recepcion',
            ),
        if (datos['sello_recepcion'] != null)
          ConstanciaNota.desdeSello(datos['sello_recepcion']),
      ]),
    );
  }

  static bool _textoOpcional(Object? valor) => valor == null || valor is String;

  static bool _unidadValida(Object? valor, {bool opcional = false}) =>
      (opcional && valor == null) ||
      (valor is Map && valor['id'] is int && valor['nombre'] is String);

  String get id => datos['id'] as String;
  String get asunto => datos['asunto'] as String;
  String get cite => datos['cite'] as String? ?? 'Sin CITE asignado';
  String get estado => datos['estado'] as String;
  int get version => datos['version'] as int;
  String get revisionDocumento => jsonEncode([
    version,
    estado,
    estadoFirma,
    datos['fecha_ultimo_movimiento'],
    datos['movimientos_nota'],
    datos['constancias'],
    datos['sello_recepcion'],
  ]);
  String get origen => (datos['unidad_origen'] as Map)['nombre'] as String;
  String get emisor {
    final nombre = (datos['autor'] as Map?)?['nombre'];
    return nombre is String && nombre.isNotEmpty ? '$nombre · $origen' : origen;
  }

  String get destinataria =>
      (datos['unidad_destinataria'] as Map?)?['nombre'] as String? ??
      (datos['destino_pendiente'] as Map?)?['nombre'] as String? ??
      'No indicada';
  String? get cuerpo => datos['cuerpo'] as String?;
  String? get estadoFirma => datos['estado_firma'] as String?;
  String? get documentoId => datos['documento_id'] as String?;
  String? get hojaId => datos['hoja_id'] as String?;
  List<String> get acciones => datos['acciones_permitidas'] as List<String>;
  bool permite(String accion) => acciones.contains(accion);

  String get etiquetaEstado => switch (estado) {
    'borrador' => 'Borrador',
    'emision_pendiente' => 'Emisión pendiente',
    'pendiente_revision' => 'Pendiente de revisión',
    'pendiente_recepcion' => 'Pendiente de recepción',
    'recibida' => 'Recibida',
    'en_atencion' => 'En atención',
    'cerrada' => 'Cerrada',
    _ => estado.replaceAll('_', ' '),
  };

  String get siguienteAccion {
    if (permite('firmar_borrador')) return 'Firmar borrador';
    if (permite('dar_conformidad')) return 'Revisar nota';
    if (permite('confirmar_primera_recepcion') ||
        permite('confirmar_recepcion_derivacion')) {
      return 'Recibir nota';
    }
    if (permite('registrar_atencion')) return 'Atender nota';
    return 'Ver nota';
  }
}

class PaginaNotas {
  const PaginaNotas(this.notas, this.actual, this.ultima, this.total);
  final List<NotaInterna> notas;
  final int actual, ultima, total;
}
