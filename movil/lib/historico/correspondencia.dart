class Correspondencia {
  const Correspondencia({
    required this.remitente,
    required this.asunto,
    required this.tipoDocumento,
    required this.fechaRecepcion,
  });
  final String remitente;
  final String asunto;
  final String tipoDocumento;
  final DateTime fechaRecepcion;
  static const tipos = ['Carta', 'Oficio', 'Memo', 'Factura', 'Otro'];
  Map<String, String> toJson() => {
    'remitente': remitente.trim(),
    'asunto': asunto.trim(),
    'tipoDocumento': tipoDocumento,
    'fechaRecepcion':
        '${fechaRecepcion.year.toString().padLeft(4, '0')}-'
        '${fechaRecepcion.month.toString().padLeft(2, '0')}-'
        '${fechaRecepcion.day.toString().padLeft(2, '0')}',
  };
}

class RegistroResultado {
  const RegistroResultado({
    required this.id,
    required this.correlativo,
    required this.mensaje,
  });
  final int id;
  final String correlativo;
  final String mensaje;
  factory RegistroResultado.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final correlativo = json['correlativo'];
    final mensaje = json['mensaje'];
    if (id is! int ||
        id <= 0 ||
        correlativo is! String ||
        correlativo.trim().isEmpty ||
        mensaje is! String ||
        mensaje.trim().isEmpty) {
      throw const FormatException('Respuesta de registro incompleta.');
    }
    return RegistroResultado(
      id: id,
      correlativo: correlativo,
      mensaje: mensaje,
    );
  }
}
