import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';

class Session extends ChangeNotifier {
  final FlutterSecureStorage storage;
  final Dio dio;
  final String baseUrl;
  Session({
    this.storage = const FlutterSecureStorage(),
    Dio? client,
    this.baseUrl = AppConfig.apiUrl,
  }) : dio =
           client ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
               followRedirects: false,
             ),
           );
  String? _access;
  bool get signedIn => _access != null;
  String? get accessToken => _access;
  Map<String, dynamic>? user;
  String get _storageKey => 'mobile_refresh_v1_${Uri.encodeComponent(baseUrl)}';
  bool get configured => AppConfig.isHttps(baseUrl) && baseUrl.endsWith('/');
  Future<void> _accept(Map<String, dynamic> result) async {
    final access = result['accessToken'], refresh = result['refreshToken'];
    if (access is! String ||
        refresh is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(access) ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(refresh)) {
      throw const FormatException('Respuesta de sesión inválida');
    }
    final account = result['user'];
    if (account is! Map ||
        account['id'] is! int ||
        account['email'] is! String) {
      throw const FormatException('Usuario de sesión inválido');
    }
    await storage.write(key: _storageKey, value: refresh);
    _access = access;
    user = Map<String, dynamic>.from(account);
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    if (!configured) throw StateError('Falta configurar una API HTTPS');
    final result = await dio.post<Map<String, dynamic>>(
      'auth/login',
      data: {'email': email.trim().toLowerCase(), 'password': password},
    );
    await _accept(result.data!);
  }

  Future<void> restore() async {
    if (!configured) return;
    try {
      // Discard credentials from the previous OAuth prototype.
      await storage.delete(key: 'refresh_token');
      final refresh = await storage.read(key: _storageKey);
      if (refresh == null) return;
      final result = await dio.post<Map<String, dynamic>>(
        'auth/refresh',
        data: {'refreshToken': refresh},
      );
      await _accept(result.data!);
    } catch (_) {
      _access = null;
      user = null;
      try {
        await storage.delete(key: _storageKey);
      } catch (_) {
        /* Login remains available. */
      }
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _access = null;
    user = null;
    notifyListeners();
    final refresh = await storage.read(key: _storageKey);
    await storage.delete(key: _storageKey);
    if (refresh != null && configured) {
      try {
        await dio.post<void>('auth/logout', data: {'refreshToken': refresh});
      } catch (_) {
        /* Local credentials are already removed; server sessions expire. */
      }
    }
  }
}
