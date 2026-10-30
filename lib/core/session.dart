import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';

class Session extends ChangeNotifier {
  final FlutterAppAuth auth;
  final FlutterSecureStorage storage;
  Session({
    this.auth = const FlutterAppAuth(),
    this.storage = const FlutterSecureStorage(),
  });
  String? _access;
  bool get signedIn => _access != null;
  String? get accessToken => _access;
  Future<void> signIn() async {
    if (!AppConfig.ready) throw StateError('Falta configurar API y OAuth');
    final result = await auth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        AppConfig.clientId,
        AppConfig.redirect,
        issuer: AppConfig.issuer,
        scopes: ['openid', 'profile', 'offline_access'],
      ),
    );
    if (result.accessToken == null) throw StateError('No se recibió un token');
    await storage.delete(key: 'refresh_token');
    if (result.refreshToken != null) {
      await storage.write(key: 'refresh_token', value: result.refreshToken);
    }
    _access = result.accessToken;
    notifyListeners();
  }

  Future<void> restore() async {
    if (!AppConfig.ready) return;
    try {
      final refresh = await storage.read(key: 'refresh_token');
      if (refresh == null) return;
      final result = await auth.token(
        TokenRequest(
          AppConfig.clientId,
          AppConfig.redirect,
          issuer: AppConfig.issuer,
          refreshToken: refresh,
        ),
      );
      if (result.accessToken == null) throw StateError('Sesión inválida');
      if (result.refreshToken != null) {
        await storage.write(key: 'refresh_token', value: result.refreshToken);
      }
      _access = result.accessToken;
      notifyListeners();
    } catch (_) {
      try {
        await signOut();
      } catch (_) {
        /* Keep the login screen available. */
      }
    }
  }

  Future<void> signOut() async {
    _access = null;
    notifyListeners();
    await storage.delete(key: 'refresh_token');
  }
}
