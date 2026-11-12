import '../../compartido/api/laravel_api.dart';

enum OperacionRecorrido {
  derivar('derivaciones', 'DERIVACION', 'Derivar hoja'),
  recibir('recepciones', 'RECEPCION', 'Confirmar recepción'),
  atender('atenciones', 'ATENCION', 'Registrar atención');

  const OperacionRecorrido(this.ruta, this.movimiento, this.titulo);
  final String ruta, movimiento, titulo;
}

class SolicitudRecorrido {
  SolicitudRecorrido({
    required this.hoja,
    required this.documento,
    required this.operacion,
    required Map<String, dynamic> datos,
    required this.token,
  }) : datos = Map.unmodifiable(datos),
       clave = nuevaClaveSolicitud();

  final String hoja, documento, clave;
  final String? token;
  final OperacionRecorrido operacion;
  final Map<String, dynamic> datos;
}

class RecorridoApi {
  const RecorridoApi(this.api);
  final ApiLaravel api;

  Future<List<({int id, String nombre})>> destinos(String hoja) async {
    final respuesta = await api.enviar(
      'GET',
      'hojas/${Uri.encodeComponent(hoja)}/destinos',
    );
    final data = respuesta['data'];
    if (data is! List ||
        data.any(
          (d) => d is! Map || d['id'] is! int || d['nombre'] is! String,
        )) {
      throw const ErrorLaravel(
        'No se pudieron interpretar las unidades de destino.',
      );
    }
    return data
        .map((d) => (id: d['id'] as int, nombre: d['nombre'] as String))
        .toList();
  }

  Future<Map<String, dynamic>> enviar(SolicitudRecorrido solicitud) async {
    if (api.token != solicitud.token) {
      throw const ErrorLaravel(
        'Tu sesión cambió. Vuelve a abrir el documento.',
        estado: 401,
      );
    }
    final resultado = await api.enviar(
      'POST',
      'hojas/${Uri.encodeComponent(solicitud.hoja)}/${solicitud.operacion.ruta}',
      datos: solicitud.datos,
      cabeceras: {'Idempotency-Key': solicitud.clave},
    );
    final hoja = resultado['hoja'];
    final movimiento = resultado['movimiento'];
    final estado = switch (solicitud.operacion) {
      OperacionRecorrido.derivar => 'PENDIENTE_RECEPCION',
      OperacionRecorrido.recibir => 'RECIBIDA',
      OperacionRecorrido.atender => 'EN_ATENCION',
    };
    if (resultado['documento_id'] != solicitud.documento ||
        hoja is! Map<String, dynamic> ||
        hoja['id'] != solicitud.hoja ||
        hoja['estado'] != estado ||
        hoja['responsable_id'] is! int ||
        hoja['unidad_vigente_id'] is! int ||
        hoja['version'] != (solicitud.datos['version'] as int) + 1 ||
        movimiento is! Map ||
        movimiento['id'] is! String ||
        movimiento['accion'] != solicitud.operacion.movimiento) {
      throw const ErrorLaravel(
        'No se pudo confirmar el resultado. Reintenta la misma solicitud para comprobarlo.',
        codigo: 'RESPUESTA_INCIERTA',
      );
    }
    return resultado;
  }
}

String textoRecorrido(String value) =>
    value.replaceAll(RegExp(r'^[ \t\r\n]+|[ \t\r\n]+$'), '');

String referenciaQr(String valor, String servidor) {
  final texto = valor.trim();
  final uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  if (uuid.hasMatch(texto)) return texto.toLowerCase();
  final uri = Uri.tryParse(texto);
  final base = Uri.parse(servidor);
  const locales = {'localhost', '127.0.0.1', '10.0.2.2'};
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.port != base.port ||
      (uri.host != base.host && !locales.contains(uri.host)) ||
      uri.pathSegments.length != 2 ||
      uri.pathSegments.first != 'hojas' ||
      !uuid.hasMatch(uri.pathSegments.last)) {
    throw const ErrorLaravel(
      'Este QR no corresponde a una hoja de ruta de este servidor.',
    );
  }
  return uri.pathSegments.last.toLowerCase();
}
