class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static Uri consulta(String guia, {String base = baseUrl}) => Uri.parse(base)
      .replace(
        pathSegments: ['api', 'correspondencia', 'guia', guia],
        query: null,
        fragment: null,
      );
}
