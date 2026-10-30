class AppConfig {
  static const apiUrl = String.fromEnvironment('API_BASE_URL');
  static const issuer = String.fromEnvironment('OIDC_ISSUER');
  static const clientId = String.fromEnvironment('OIDC_CLIENT_ID');
  static const redirect = 'com.notaentrega.mobile:/oauthredirect';
  static bool get ready =>
      isHttps(apiUrl) && isHttps(issuer) && clientId.isNotEmpty;
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
