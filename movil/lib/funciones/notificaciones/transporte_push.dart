import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'avisos_api.dart';

abstract interface class TransportePush {
  Stream<String> get abiertos;
  Stream<String> get recibidos;
  Stream<String> get tokens;
  Future<bool> iniciar();
  Future<bool> pedirPermiso();
  Future<String?> token();
  Future<String?> inicial();
  Future<void> borrarToken();
  Future<void> cancelarVisibles();
  Future<void> cerrar();
}

class FirebasePush implements TransportePush {
  static const _canal = MethodChannel('correspondencia/notificaciones');
  final _abiertos = StreamController<String>.broadcast();
  final _recibidos = StreamController<String>.broadcast();
  final _tokens = StreamController<String>.broadcast();
  final _suscripciones = <StreamSubscription<dynamic>>[];
  bool _lista = false;
  bool _cerrada = false;
  String? _id(RemoteMessage m) => idAvisoValido(m.data['notificacion_id'])
      ? m.data['notificacion_id'] as String
      : null;
  @override
  Stream<String> get abiertos => _abiertos.stream;
  @override
  Stream<String> get recibidos => _recibidos.stream;
  @override
  Stream<String> get tokens => _tokens.stream;
  @override
  Future<bool> iniciar() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      await Firebase.initializeApp();
      await _canal.invokeMethod<void>('crearCanal');
      if (_cerrada) return false;
      _lista = true;
      _suscripciones.add(
        FirebaseMessaging.onMessageOpenedApp.listen((m) {
          final id = _id(m);
          if (id != null) _abiertos.add(id);
        }),
      );
      _suscripciones.add(
        FirebaseMessaging.onMessage.listen((m) {
          final id = _id(m);
          if (id != null) _recibidos.add(id);
        }),
      );
      _suscripciones.add(
        FirebaseMessaging.instance.onTokenRefresh.listen(_tokens.add),
      );
      return true;
    } catch (_) {
      // Sin configuración Firebase, el acceso normal y la bandeja siguen disponibles.
      return false;
    }
  }

  @override
  Future<bool> pedirPermiso() async {
    final r = await FirebaseMessaging.instance.requestPermission();
    return r.authorizationStatus == AuthorizationStatus.authorized ||
        r.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() async {
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    return FirebaseMessaging.instance.getToken();
  }

  @override
  Future<String?> inicial() async {
    final m = await FirebaseMessaging.instance.getInitialMessage();
    return m == null ? null : _id(m);
  }

  @override
  Future<void> borrarToken() async {
    if (_lista) {
      await FirebaseMessaging.instance.setAutoInitEnabled(false);
      await FirebaseMessaging.instance.deleteToken();
    }
  }

  @override
  Future<void> cancelarVisibles() async {
    if (_lista) await _canal.invokeMethod<void>('cancelar');
  }

  @override
  Future<void> cerrar() async {
    _cerrada = true;
    for (final s in _suscripciones) {
      await s.cancel();
    }
    await _abiertos.close();
    await _recibidos.close();
    await _tokens.close();
  }
}
