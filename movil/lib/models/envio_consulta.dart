/// Datos que la pantalla necesita; no constituye un contrato JSON de la API.
class EnvioConsulta {
  const EnvioConsulta({
    required this.numeroGuia,
    required this.estado,
    required this.fechaUltimoMovimiento,
  });

  final String numeroGuia;
  final String estado;
  final DateTime fechaUltimoMovimiento;
}
