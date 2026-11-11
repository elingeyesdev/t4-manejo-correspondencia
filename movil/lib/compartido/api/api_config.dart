class ApiConfig {
  // Compatibilidad con el formulario histórico; producción utiliza POST /api/documentos.
  static const registroUrl = String.fromEnvironment('REGISTRO_API_URL');
  static Uri? get registroEndpoint {
    final uri = Uri.tryParse(registroUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri;
  }

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static Uri consulta(String guia, {String base = baseUrl}) => Uri.parse(base)
      .replace(
        pathSegments: ['api', 'correspondencia', 'guia', guia],
        query: null,
        fragment: null,
      );
}
