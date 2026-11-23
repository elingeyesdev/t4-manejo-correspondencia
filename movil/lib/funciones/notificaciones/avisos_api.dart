import '../../compartido/api/laravel_api.dart';
import '../notas_internas/nota_interna.dart';
import '../notas_internas/notas_api.dart';

class AvisoNota {
  const AvisoNota(this.id, this.notaId, this.tipo, this.fecha, this.leida);
  final String id, notaId, tipo;
  final DateTime fecha;
  final bool leida;
  factory AvisoNota.desdeJson(Object? datos) {
    if (datos is! Map ||
        !idAvisoValido(datos['id']) ||
        datos['nota_id'] is! String ||
        (datos['nota_id'] as String).isEmpty ||
        datos['tipo'] is! String ||
        datos['creada_en'] is! String ||
        DateTime.tryParse(datos['creada_en'] as String) == null ||
        (datos['leida_en'] != null &&
            (datos['leida_en'] is! String ||
                DateTime.tryParse(datos['leida_en'] as String) == null))) {
      throw const ErrorLaravel('No se pudo interpretar el aviso.');
    }
    return AvisoNota(
      datos['id'] as String,
      datos['nota_id'] as String,
      datos['tipo'] as String,
      DateTime.parse(datos['creada_en'] as String),
      datos['leida_en'] != null,
    );
  }
}

bool idAvisoValido(Object? valor) =>
    valor is String && RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(valor);

class PaginaAvisos {
  const PaginaAvisos(this.avisos, this.noLeidas, this.pagina, this.ultima);
  final List<AvisoNota> avisos;
  final int noLeidas, pagina, ultima;
}

class AvisosApi {
  const AvisosApi(this.api);
  final ApiLaravel api;
  Future<PaginaAvisos> listar({int pagina = 1}) async {
    final r = await api.enviar(
      'GET',
      'notificaciones?page=$pagina&per_page=15',
    );
    final meta = r['meta'];
    if (r['data'] is! List ||
        r['no_leidas'] is! int ||
        r['no_leidas'] < 0 ||
        meta is! Map ||
        meta['current_page'] != pagina ||
        meta['last_page'] is! int ||
        meta['last_page'] < pagina) {
      throw const ErrorLaravel('No se pudo interpretar el centro de avisos.');
    }
    return PaginaAvisos(
      (r['data'] as List).map(AvisoNota.desdeJson).toList(),
      r['no_leidas'] as int,
      pagina,
      meta['last_page'] as int,
    );
  }

  Future<NotaInterna> resolver(String id) async {
    if (!idAvisoValido(id)) {
      throw const ErrorLaravel('Esta notificación ya no está disponible.');
    }
    final token = api.token, cuenta = api.cuentaId;
    final r = await api.enviar(
      'GET',
      'notificaciones/${Uri.encodeComponent(id)}',
    );
    final aviso = AvisoNota.desdeJson(r);
    if (aviso.id != id) {
      throw const ErrorLaravel('Esta notificación ya no está disponible.');
    }
    final nota = await NotasApi(api).detalle(aviso.notaId);
    if (api.token != token || api.cuentaId != cuenta) {
      throw const ErrorLaravel(
        'Tu sesión cambió. Vuelve a abrir el aviso.',
        estado: 401,
      );
    }
    return nota;
  }

  Future<void> leer(String id) async {
    if (!idAvisoValido(id)) return;
    await api.enviar(
      'PUT',
      'notificaciones/${Uri.encodeComponent(id)}/lectura',
    );
  }

  Future<void> registrar(String instalacion, String token) => api.enviar(
    'PUT',
    'notificaciones/dispositivos/$instalacion',
    datos: {'token_fcm': token, 'plataforma': 'android'},
  );

  Future<void> desvincular(String instalacion) =>
      api.enviar('DELETE', 'notificaciones/dispositivos/$instalacion');
}
