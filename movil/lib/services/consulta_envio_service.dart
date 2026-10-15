import '../config/api_config.dart';
import '../models/envio_consulta.dart';

abstract interface class ConsultaEnvioService {
  Future<EnvioConsulta?> consultar(String numeroGuia);
}

class ConsultaEnvioException implements Exception {
  const ConsultaEnvioException(this.mensaje);
  final String mensaje;
}

class ErrorConexion extends ConsultaEnvioException {
  const ErrorConexion()
    : super('No se pudo conectar con el servidor. Intente nuevamente.');
}

class ConsultaNoDisponible extends ConsultaEnvioException {
  const ConsultaNoDisponible()
    : super(
        'La consulta aún no está disponible. El servicio está pendiente de conexión.',
      );
}

class ConsultaEnvioApi implements ConsultaEnvioService {
  const ConsultaEnvioApi({this.baseUrl = ApiConfig.baseUrl});
  final String baseUrl;

  @override
  Future<EnvioConsulta?> consultar(String numeroGuia) async {
    // La API publicada solo registra y lista; falta consulta por guía y estados.
    // Conectar aquí cuando se acuerden método, ruta y formato de respuesta.
    throw const ConsultaNoDisponible();
  }
}
