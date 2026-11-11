class EnvioConsulta {
  const EnvioConsulta({
    required this.numeroGuia,
    required this.estado,
    required this.fechaUltimoMovimiento,
  });
  final String numeroGuia;
  final String estado;
  final DateTime fechaUltimoMovimiento;

  factory EnvioConsulta.fromJson(Map<String, dynamic> json) {
    final guia = json['guia'];
    final estado = json['estado'];
    final fecha = json['fechaUltimoMovimiento'];
    if (guia is! String ||
        guia.trim().isEmpty ||
        estado is! String ||
        estado.trim().isEmpty ||
        fecha is! String ||
        !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(fecha)) {
      throw const FormatException('Respuesta de seguimiento incompleta.');
    }
    final instante = DateTime.tryParse(fecha);
    if (instante == null) {
      throw const FormatException('Fecha de seguimiento no válida.');
    }
    return EnvioConsulta(
      numeroGuia: guia,
      estado: estado,
      fechaUltimoMovimiento: instante,
    );
  }
}
