class AppConfig {
  static const apiUrl = String.fromEnvironment('API_BASE_URL');
  static bool get ready => isHttps(apiUrl) && apiUrl.endsWith('/');
  static bool isHttps(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }
}
