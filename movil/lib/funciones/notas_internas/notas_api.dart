import '../../compartido/api/laravel_api.dart';
import 'nota_interna.dart';

enum AccionNota {
  conformidad('conformidades', 'Dar conformidad'),
  primeraRecepcion('recepciones', 'Confirmar recepción');

  const AccionNota(this.ruta, this.titulo);
  final String ruta, titulo;
}

class SolicitudNota {
  SolicitudNota({
    required NotaInterna nota,
    required this.accion,
    required this.token,
  }) : notaId = nota.id,
       version = nota.version,
       clave = nuevaClaveSolicitud();

  final String notaId, clave;
  final int version;
  final String? token;
  final AccionNota accion;
}

class NotasApi {
  const NotasApi(this.api);
  final ApiLaravel api;
  static final _intentos = Expando<Map<String, SolicitudNota>>();

  SolicitudNota? pendientePara(String id) {
    final intento = _intentos[api]?[id];
    if (intento != null && intento.token != api.token) {
      descartarIntento(id);
      return null;
    }
    return intento;
  }

  void descartarIntento(String id) => _intentos[api]?.remove(id);

  Future<PaginaNotas> bandeja(BandejaNota bandeja, {int pagina = 1}) async {
    final resultado = await api.enviar(
      'GET',
      'notas-internas?bandeja=${bandeja.parametro}&page=$pagina&per_page=15',
    );
    final data = resultado['data'];
    final meta = resultado['meta'];
    if (data is! List ||
        data.any((d) => d is! Map<String, dynamic>) ||
        meta is! Map ||
        meta['current_page'] != pagina ||
        meta['last_page'] is! int ||
        (meta['last_page'] as int) < pagina ||
        meta['total'] is! int ||
        (meta['total'] as int) < 0) {
      throw const ErrorLaravel('No se pudo interpretar la bandeja de notas.');
    }
    return PaginaNotas(
      data
          .map((n) => NotaInterna.desdeJson(n as Map<String, dynamic>))
          .toList(),
      pagina,
      meta['last_page'] as int,
      meta['total'] as int,
    );
  }

  Future<NotaInterna> detalle(String id) async {
    final resultado = await api.enviar(
      'GET',
      'notas-internas/${Uri.encodeComponent(id)}',
    );
    final nota = NotaInterna.desdeJson(resultado);
    if (nota.id != id) {
      throw const ErrorLaravel('La respuesta no corresponde a esta nota.');
    }
    return nota;
  }

  Future<NotaInterna> ejecutar(SolicitudNota solicitud) async {
    final anterior = pendientePara(solicitud.notaId);
    if (anterior != null && anterior.clave != solicitud.clave) {
      throw const ErrorLaravel(
        'Comprueba el intento pendiente antes de realizar otra acción.',
        codigo: 'RESULTADO_PENDIENTE',
      );
    }
    if (api.token != solicitud.token) {
      throw const ErrorLaravel(
        'Tu sesión cambió. Vuelve a abrir la nota.',
        estado: 401,
      );
    }
    (_intentos[api] ??= {})[solicitud.notaId] = solicitud;
    try {
      final nota = await _enviar(solicitud);
      descartarIntento(solicitud.notaId);
      return nota;
    } on ErrorLaravel catch (e) {
      if (rechazoDefinitivo(e)) descartarIntento(solicitud.notaId);
      rethrow;
    }
  }

  static bool rechazoDefinitivo(ErrorLaravel e) =>
      e.estado != null &&
      e.estado! >= 400 &&
      e.estado! < 500 &&
      !{408, 425}.contains(e.estado);

  Future<NotaInterna> _enviar(SolicitudNota solicitud) async {
    if (api.token != solicitud.token) {
      throw const ErrorLaravel(
        'Tu sesión cambió. Vuelve a abrir la nota.',
        estado: 401,
      );
    }
    final respuesta = await api.enviarConEstado(
      'POST',
      'notas-internas/${Uri.encodeComponent(solicitud.notaId)}/${solicitud.accion.ruta}',
      datos: {'version': solicitud.version},
      cabeceras: {'Idempotency-Key': solicitud.clave},
    );
    if (respuesta.estado == 202) {
      throw const ErrorLaravel(
        'La operación sigue pendiente. Reintenta para comprobar el mismo intento.',
        codigo: 'RESULTADO_PENDIENTE',
      );
    }
    NotaInterna nota;
    try {
      nota = NotaInterna.desdeJson(respuesta.datos);
    } on ErrorLaravel {
      throw const ErrorLaravel(
        'No se pudo confirmar el resultado. Reintenta para comprobar el mismo intento.',
        codigo: 'RESPUESTA_INCIERTA',
      );
    }
    if (nota.id != solicitud.notaId ||
        nota.version <= solicitud.version ||
        (solicitud.accion == AccionNota.primeraRecepcion &&
            (nota.documentoId == null || nota.hojaId == null))) {
      throw const ErrorLaravel(
        'No se pudo confirmar el resultado. Reintenta para comprobar el mismo intento.',
        codigo: 'RESPUESTA_INCIERTA',
      );
    }
    return nota;
  }
}
