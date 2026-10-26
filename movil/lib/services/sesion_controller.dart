import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'laravel_api.dart';

abstract interface class AlmacenSesion {
  Future<String?> leer();
  Future<void> guardar(String valor);
  Future<void> eliminar();
}

class AlmacenSeguro implements AlmacenSesion {
  final _storage = const FlutterSecureStorage();
  static const _key = 'correspondencia.sesion.laravel';
  @override
  Future<String?> leer() => _storage.read(key: _key);
  @override
  Future<void> guardar(String valor) => _storage.write(key: _key, value: valor);
  @override
  Future<void> eliminar() => _storage.delete(key: _key);
}

class SesionController extends ChangeNotifier {
  SesionController({required this.api, AlmacenSesion? almacen})
    : almacen = almacen ?? AlmacenSeguro() {
    api.alVencerSesion = invalidar;
  }
  bool _cerrada = false;
  @override
  void notifyListeners() {
    if (!_cerrada) super.notifyListeners();
  }

  @override
  void dispose() {
    _cerrada = true;
    super.dispose();
  }

  final ApiLaravel api;
  final AlmacenSesion almacen;
  Map<String, dynamic>? usuario;
  bool inicializada = false;
  bool ocupada = false;
  String? mensaje;
  bool get autenticada => usuario != null && api.token != null;
  bool get puedeRegistrar =>
      ['administrador', 'recepcion'].contains(usuario?['role']);
  String get nombre => usuario?['name'] as String? ?? '';
  String get rol => usuario?['role'] as String? ?? '';

  Future<void> restaurar() async {
    if (inicializada) return;
    try {
      final saved = await almacen.leer();
      if (saved != null) {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        final vence = DateTime.parse(data['vence'] as String);
        if (data['origen'] != api.baseUrl ||
            !vence.isAfter(DateTime.now().toUtc()) ||
            data['token'] is! String ||
            (data['token'] as String).isEmpty ||
            data['usuario'] is! Map) {
          await almacen.eliminar();
        } else {
          api.token = data['token'] as String;
          usuario = Map<String, dynamic>.from(data['usuario'] as Map);
          try {
            await api.enviar('GET', 'documentos');
          } on ErrorLaravel catch (e) {
            if (e.estado == 401 || e.estado == 403) {
              await invalidar();
            } else {
              mensaje = e.mensaje;
            }
          }
        }
      }
    } catch (_) {
      api.token = null;
      usuario = null;
      try {
        await almacen.eliminar();
      } catch (_) {
        /* No se utiliza la sesión ilegible. */
      }
      mensaje = 'No se pudo recuperar la sesión. Vuelve a ingresar.';
    } finally {
      inicializada = true;
      notifyListeners();
    }
  }

  Future<void> ingresar(String email, String password) async {
    if (ocupada) return;
    ocupada = true;
    mensaje = null;
    notifyListeners();
    try {
      final result = await api.enviar(
        'POST',
        'sesiones',
        autenticado: false,
        datos: {
          'email': email.trim(),
          'password': password,
          'device_name': 'Android Correspondencia',
        },
      );
      final token = result['token'];
      final user = result['user'];
      if (token is! String ||
          token.isEmpty ||
          user is! Map<String, dynamic> ||
          user['name'] is! String ||
          ![
            'administrador',
            'recepcion',
            'funcionario',
          ].contains(user['role'])) {
        throw const ErrorLaravel('El servidor devolvió una sesión incompleta.');
      }
      api.token = token;
      try {
        await almacen.guardar(
          jsonEncode({
            'token': token,
            'usuario': user,
            'origen': api.baseUrl,
            'vence': DateTime.now()
                .toUtc()
                .add(const Duration(hours: 8))
                .toIso8601String(),
          }),
        );
      } catch (_) {
        try {
          await api.enviar('DELETE', 'sesiones/actual');
        } catch (_) {
          /* Se invalida localmente. */
        }
        api.token = null;
        throw const ErrorLaravel(
          'No se pudo proteger la sesión en el teléfono. Intenta nuevamente.',
        );
      }
      usuario = user;
      inicializada = true;
    } on ErrorLaravel catch (e) {
      mensaje = e.estado == 422
          ? 'Correo, contraseña o cuenta no válidos.'
          : e.mensaje;
    } catch (_) {
      mensaje = 'No se pudo iniciar sesión. Intenta nuevamente.';
    } finally {
      ocupada = false;
      notifyListeners();
    }
  }

  Future<void> invalidar() async {
    api.token = null;
    usuario = null;
    mensaje = 'Tu sesión venció o ya no está habilitada. Vuelve a ingresar.';
    try {
      await almacen.eliminar();
    } catch (_) {
      mensaje = 'No se pudo borrar la credencial protegida. Revisa el almacenamiento del teléfono.';
    }
    notifyListeners();
  }

  Future<void> salir() async {
    if (ocupada) return;
    ocupada = true;
    notifyListeners();
    String? advertencia;
    try {
      await api.enviar('DELETE', 'sesiones/actual');
    } catch (_) {
      advertencia = 'Se cerró la sesión en este teléfono. No se pudo confirmar la revocación en el servidor.';
    } finally {
      api.token = null;
      usuario = null;
      try {
        await almacen.eliminar();
      } catch (_) {
        advertencia = 'No se pudo borrar la credencial protegida del teléfono.';
      }
      mensaje = advertencia;
      ocupada = false;
      notifyListeners();
    }
  }
}
