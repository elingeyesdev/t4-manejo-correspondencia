import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../compartido/api/laravel_api.dart';
import '../iniciar_sesion/sesion_controller.dart';
import 'avisos_api.dart';
import 'transporte_push.dart';

class AvisosController extends ChangeNotifier {
  AvisosController({
    required this.sesion,
    required this.push,
    this.storage = const FlutterSecureStorage(),
  });
  final SesionController sesion;
  final TransportePush push;
  final FlutterSecureStorage storage;
  final _subs = <StreamSubscription<String>>[];
  final _vistos = <String>{};
  final _abiertosPush = <String>{};
  String? pendiente, avisoVisible, mensaje, _identidad;
  bool disponible = false, _cerrado = false, _registrando = false;
  bool _saliendo = false;
  String? _ultimoRegistro;
  Future<void> _cola = Future.value();
  Future<void>? _registroEnServidor;
  static const _esperaLimpieza = Duration(seconds: 2);
  int _generacion = 0;
  PaginaAvisos? pagina;
  String? get _actual => sesion.autenticada
      ? '${sesion.api.baseUrl}|${sesion.api.cuentaId}|${sesion.api.token}'
      : null;
  @override
  void notifyListeners() {
    if (!_cerrado) super.notifyListeners();
  }

  Future<void> iniciar() async {
    sesion.addListener(_sesionCambio);
    sesion.antesDeSalir = desvincular;
    _subs.add(push.abiertos.listen(_desdePush));
    _subs.add(
      push.recibidos.listen((id) {
        if (_actual == null ||
            _saliendo ||
            !idAvisoValido(id) ||
            !_vistos.add(id)) {
          return;
        }
        if (_vistos.length > 200) _vistos.remove(_vistos.first);
        avisoVisible = id;
        notifyListeners();
        unawaited(refrescar());
      }),
    );
    _subs.add(
      push.tokens.listen((_) {
        _ultimoRegistro = null;
        _encolarRegistro();
      }),
    );
    try {
      disponible = await push.iniciar();
      if (disponible) {
        final id = await push.inicial();
        if (id != null) _desdePush(id);
      }
    } catch (_) {
      disponible = false;
    }
    if (_cerrado) return;
    _sesionCambio();
    _encolarRegistro();
    if (_actual != null) unawaited(refrescar());
    notifyListeners();
  }

  void abrir(String id) {
    if (_cerrado || !idAvisoValido(id)) return;
    pendiente = id;
    avisoVisible = null;
    notifyListeners();
  }

  void _desdePush(String id) {
    if (!idAvisoValido(id) || !_abiertosPush.add(id)) return;
    if (_abiertosPush.length > 200) _abiertosPush.remove(_abiertosPush.first);
    abrir(id);
  }

  void consumido(String id) {
    if (pendiente == id) pendiente = null;
  }

  void _sesionCambio() {
    if (_actual == _identidad) return;
    final anterior = _identidad;
    _identidad = _actual;
    _generacion++;
    // Un permiso de Firebase pendiente no debe bloquear a la siguiente cuenta.
    _cola = _registroEnServidor?.catchError((Object _) {}) ?? Future.value();
    _registrando = false;
    _ultimoRegistro = null;
    pagina = null;
    mensaje = null;
    avisoVisible = null;
    _vistos.clear();
    // Conserva el arranque desde push al autenticar; una cuenta ya abierta no transfiere su aviso.
    if (anterior != null) pendiente = null;
    if (_actual != null) {
      _saliendo = false;
      _encolarRegistro();
    }
    notifyListeners();
  }

  Future<String> _instalacion() async {
    const key = 'correspondencia.notificaciones.instalacion';
    final existente = await storage.read(key: key);
    if (existente != null && RegExp(r'^[0-9a-f-]{36}$').hasMatch(existente)) {
      return existente;
    }
    final nuevo = nuevaClaveSolicitud();
    await storage.write(key: key, value: nuevo);
    return nuevo;
  }

  void _encolarRegistro() {
    final generacion = _generacion;
    _cola = _cola
        .then((_) async {
          if (generacion == _generacion) await _registrar();
        })
        .catchError((Object _) {});
  }

  Future<void> _registrar() async {
    if (!disponible || _actual == null || _saliendo || _cerrado) return;
    final identidad = _actual;
    final generacion = _generacion;
    _registrando = true;
    try {
      if (!await push.pedirPermiso() ||
          !_registroVigente(generacion, identidad)) {
        return;
      }
      final token = await push.token();
      if (!_registroVigente(generacion, identidad)) return;
      final instalacion = await _instalacion();
      if (token == null ||
          token.isEmpty ||
          !_registroVigente(generacion, identidad)) {
        return;
      }
      if (_ultimoRegistro == '$identidad|$token') return;
      final registro = AvisosApi(sesion.api).registrar(instalacion, token);
      _registroEnServidor = registro;
      try {
        await registro;
      } finally {
        if (identical(_registroEnServidor, registro)) {
          _registroEnServidor = null;
        }
      }
      if (generacion == _generacion) {
        _ultimoRegistro = '$identidad|$token';
        mensaje = null;
      }
    } catch (_) {
      if (generacion == _generacion) mensaje = 'No se pudieron activar los avisos del teléfono. Puedes consultar el centro de avisos.';
    } finally {
      if (generacion == _generacion) _registrando = false;
      notifyListeners();
    }
  }

  bool _registroVigente(int generacion, String? identidad) =>
      !_cerrado &&
      !_saliendo &&
      generacion == _generacion &&
      _actual == identidad;

  Future<void> refrescar({int numero = 1}) async {
    if (_actual == null || _saliendo) return;
    final generacion = _generacion;
    try {
      final nueva = await AvisosApi(sesion.api).listar(pagina: numero);
      if (_cerrado || generacion != _generacion) return;
      pagina = nueva;
      mensaje = null;
    } on ErrorLaravel catch (e) {
      if (_cerrado || generacion != _generacion) return;
      mensaje = e.estado == 404
          ? 'El centro de avisos todavía no está disponible en este servidor.'
          : e.mensaje;
    }
    notifyListeners();
  }

  void reanudar() {
    unawaited(refrescar());
    _encolarRegistro();
  }

  Future<void> desvincular() async {
    _saliendo = true;
    final generacion = ++_generacion;
    final identidad = _actual;
    final registro = _registroEnServidor;
    _cola = Future.value();
    _registrando = false;
    pendiente = null;
    avisoVisible = null;
    pagina = null;
    _ultimoRegistro = null;
    notifyListeners();
    // Solo espera el PUT ya enviado, con el límite HTTP de ApiLaravel.
    // La cola también puede contener un permiso o token de Firebase sin respuesta.
    try {
      await registro;
    } catch (_) {}
    bool vigente() =>
        !_cerrado && generacion == _generacion && _actual == identidad;
    if (!vigente()) return;
    try {
      if (disponible && sesion.autenticada) {
        final instalacion = await _instalacion().timeout(_esperaLimpieza);
        if (!vigente()) return;
        await AvisosApi(sesion.api).desvincular(instalacion);
      }
    } catch (_) {
      /* El token local también se invalida si no hay red. */
    }
    if (!vigente()) return;
    await Future.wait([_borrarToken(generacion), _cancelarVisibles()]);
  }

  Future<void> _borrarToken(int generacion) async {
    try {
      final borrado = push.borrarToken();
      // Si Firebase termina después de otro ingreso, recupera el registro actual.
      unawaited(
        borrado
            .then((_) {
              if (!_cerrado &&
                  generacion != _generacion &&
                  _actual != null &&
                  !_saliendo) {
                _ultimoRegistro = null;
                _encolarRegistro();
              }
            })
            .catchError((Object _) {}),
      );
      await borrado.timeout(_esperaLimpieza);
    } catch (_) {}
  }

  Future<void> _cancelarVisibles() async {
    try {
      await push.cancelarVisibles().timeout(_esperaLimpieza);
    } catch (_) {}
  }

  bool get registrando => _registrando;
  @override
  void dispose() {
    _cerrado = true;
    _generacion++;
    sesion.removeListener(_sesionCambio);
    sesion.antesDeSalir = null;
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    unawaited(push.cerrar());
    super.dispose();
  }
}
