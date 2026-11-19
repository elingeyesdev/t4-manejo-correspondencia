import 'dart:async';
import 'dart:convert';

import '../../compartido/api/laravel_api.dart';
import 'almacen_intentos_nota.dart';
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
    required this.cuentaId,
  }) : notaId = nota.id,
       version = nota.version,
       clave = nuevaClaveSolicitud();

  final String notaId, clave;
  final int version;
  final String? token;
  final String? cuentaId;
  final AccionNota accion;

  const SolicitudNota._({
    required this.notaId,
    required this.clave,
    required this.version,
    required this.accion,
    required this.token,
    required this.cuentaId,
  });
}

class NotasApi {
  const NotasApi(this.api, {this.almacen = const AlmacenSeguroIntentosNota()});
  final ApiLaravel api;
  final AlmacenIntentosNota almacen;
  static final _bloqueos = <String, Future<void>>{};

  ({String origen, String cuenta, String token}) _identidad() {
    final cuenta = api.cuentaId, token = api.token;
    if (cuenta == null || cuenta.isEmpty || token == null || token.isEmpty) {
      throw const ErrorLaravel(
        'Vuelve a iniciar sesión para recuperar tus acciones pendientes.',
        estado: 401,
      );
    }
    return (
      origen: api.baseUrl.replaceAll(RegExp(r'/+$'), ''),
      cuenta: cuenta,
      token: token,
    );
  }

  void _comprobar(({String origen, String cuenta, String token}) identidad) {
    if (api.token != identidad.token || api.cuentaId != identidad.cuenta) {
      throw const ErrorLaravel(
        'Tu sesión cambió. Vuelve a abrir la nota.',
        estado: 401,
      );
    }
  }

  String _clave(
    String id,
    AccionNota accion,
    ({String origen, String cuenta, String token}) identidad,
  ) =>
      'correspondencia.nota.intento.v1.${base64Url.encode(utf8.encode(jsonEncode([identidad.origen, identidad.cuenta, id, accion.name])))}';

  Future<T> _exclusiva<T>(String id, Future<T> Function() operacion) async {
    final identidad = _identidad();
    final recurso = jsonEncode([identidad.origen, identidad.cuenta, id]);
    final anterior = _bloqueos[recurso] ?? Future<void>.value();
    final fin = Completer<void>();
    _bloqueos[recurso] = fin.future;
    try {
      await anterior;
      _comprobar(identidad);
      return await operacion();
    } finally {
      fin.complete();
      if (identical(_bloqueos[recurso], fin.future)) _bloqueos.remove(recurso);
    }
  }

  Future<SolicitudNota?> pendientePara(String id) async {
    final identidad = _identidad();
    SolicitudNota? pendiente;
    try {
      for (final accion in AccionNota.values) {
        final guardado = await almacen.leer(_clave(id, accion, identidad));
        _comprobar(identidad);
        if (guardado == null) continue;
        final datos = jsonDecode(guardado);
        if (datos is! Map ||
            datos['schema'] != 1 ||
            datos['origen'] != identidad.origen ||
            datos['cuenta'] != identidad.cuenta ||
            datos['nota'] != id ||
            datos['accion'] != accion.name ||
            datos['version'] is! int ||
            (datos['version'] as int) < 1 ||
            datos['clave'] is! String ||
            !RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
            ).hasMatch(datos['clave'] as String) ||
            pendiente != null) {
          throw const FormatException('Intento inválido');
        }
        pendiente = SolicitudNota._(
          notaId: id,
          clave: datos['clave'] as String,
          version: datos['version'] as int,
          accion: accion,
          token: identidad.token,
          cuentaId: identidad.cuenta,
        );
      }
      return pendiente;
    } on ErrorLaravel {
      rethrow;
    } catch (_) {
      throw const ErrorLaravel(
        'No se pudo recuperar el intento guardado. No confirmes una acción nueva; reintenta la carga.',
        codigo: 'ALMACEN_LOCAL',
      );
    }
  }

  Future<void> _eliminar(SolicitudNota solicitud) async {
    final identidad = _identidad();
    if (solicitud.cuentaId != identidad.cuenta ||
        solicitud.token != identidad.token) {
      throw const ErrorLaravel(
        'Tu sesión cambió. Vuelve a abrir la nota.',
        estado: 401,
      );
    }
    try {
      await almacen.eliminar(
        _clave(solicitud.notaId, solicitud.accion, identidad),
      );
    } catch (_) {
      throw const ErrorLaravel(
        'No se pudo limpiar el intento guardado. Reintenta la carga para comprobar el resultado.',
        codigo: 'LIMPIEZA_PENDIENTE',
      );
    }
    _comprobar(identidad);
  }

  Future<bool> confirmarSiAplicado(NotaInterna nota, SolicitudNota solicitud) =>
      _exclusiva(nota.id, () async {
        if (nota.id != solicitud.notaId || nota.version <= solicitud.version) {
          return false;
        }
        final aplicada = solicitud.accion == AccionNota.primeraRecepcion
            ? nota.documentoId != null && nota.hojaId != null
            : (nota.datos['movimientos_nota'] as List? ?? []).any(
                (m) =>
                    m is Map &&
                    '${m['accion']}'.toLowerCase() == 'conformidad' &&
                    m['actor'] is Map &&
                    '${m['actor']['id']}' == solicitud.cuentaId,
              );
        if (!aplicada) return false;
        await _eliminar(solicitud);
        return true;
      });

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

  Future<NotaInterna> ejecutar(SolicitudNota solicitud) => _exclusiva(
    solicitud.notaId,
    () async {
      final anterior = await pendientePara(solicitud.notaId);
      if (anterior != null && anterior.clave != solicitud.clave) {
        throw const ErrorLaravel(
          'Comprueba el intento pendiente antes de realizar otra acción.',
          codigo: 'INTENTO_EXISTENTE',
          estado: 409,
        );
      }
      if (api.token != solicitud.token || api.cuentaId != solicitud.cuentaId) {
        throw const ErrorLaravel(
          'Tu sesión cambió. Vuelve a abrir la nota.',
          estado: 401,
        );
      }
      final identidad = _identidad();
      try {
        await almacen.guardar(
          _clave(solicitud.notaId, solicitud.accion, identidad),
          jsonEncode({
            'schema': 1,
            'origen': identidad.origen,
            'cuenta': identidad.cuenta,
            'nota': solicitud.notaId,
            'accion': solicitud.accion.name,
            'clave': solicitud.clave,
            'version': solicitud.version,
          }),
        );
      } catch (_) {
        throw const ErrorLaravel(
          'No se pudo guardar el intento en el dispositivo. No se envió la acción.',
          codigo: 'ALMACEN_LOCAL',
        );
      }
      _comprobar(identidad);
      try {
        final nota = await _enviar(solicitud);
        await _eliminar(solicitud);
        return nota;
      } on ErrorLaravel catch (e) {
        if (rechazoDefinitivo(e) && !{401, 403, 404}.contains(e.estado)) {
          await _eliminar(solicitud);
        }
        rethrow;
      }
    },
  );

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
