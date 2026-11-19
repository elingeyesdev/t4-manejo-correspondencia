import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AlmacenIntentosNota {
  Future<String?> leer(String clave);
  Future<void> guardar(String clave, String valor);
  Future<void> eliminar(String clave);
}

class AlmacenSeguroIntentosNota implements AlmacenIntentosNota {
  const AlmacenSeguroIntentosNota();
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> leer(String clave) => _storage.read(key: clave);
  @override
  Future<void> guardar(String clave, String valor) =>
      _storage.write(key: clave, value: valor);
  @override
  Future<void> eliminar(String clave) => _storage.delete(key: clave);
}
