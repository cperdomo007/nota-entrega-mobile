import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/exchange_rate.dart';
import 'api.dart';

class ExchangeRateService extends ChangeNotifier {
  final Api api;
  final FlutterSecureStorage storage;
  ExchangeRateService(this.api, {this.storage = const FlutterSecureStorage()});
  final Map<String, ExchangeRateModel> rates = {};
  bool busy = false;
  String? error;
  DateTime? _attempt;
  bool _disposed = false, _loaded = false;
  String get _key =>
      'exchange_rates_v1_${Uri.encodeComponent(api.dio.options.baseUrl)}';
  Future<void> refresh() async {
    if (busy ||
        (_attempt != null &&
            DateTime.now().difference(_attempt!) <
                const Duration(seconds: 30))) {
      return;
    }
    _attempt = DateTime.now();
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (!_loaded) {
        _loaded = true;
        try {
          final saved = await storage
              .read(key: _key)
              .timeout(const Duration(seconds: 3));
          if (saved != null) {
            final decoded = jsonDecode(saved) as Map<String, dynamic>;
            for (final entry in decoded.entries) {
              try {
                rates[entry.key] = ExchangeRateModel.fromJson(
                  Map<String, dynamic>.from(entry.value),
                  offline: true,
                );
              } catch (_) {
                /* Ignore invalid saved quote. */
              }
            }
          }
        } catch (_) {
          /* Storage unavailable: continue with network. */
        }
        if (!_disposed) notifyListeners();
      }
      final result = await api.get('exchange-rates');
      final fetched = result['rates'] as Map<String, dynamic>;
      for (final id in ['bcv', 'binance']) {
        if (fetched[id] != null) {
          rates[id] = ExchangeRateModel.fromJson(
            Map<String, dynamic>.from(fetched[id]),
          );
        } else if (rates[id] != null) {
          rates[id] = ExchangeRateModel.fromJson(
            rates[id]!.toJson(),
            offline: true,
          );
        }
      }
      if (rates.length < 2 || rates.values.any((r) => r.stale)) error = 'Algunas tasas no pudieron actualizarse. Se conserva la última cotización válida.';
      try {
        await storage.write(
          key: _key,
          value: jsonEncode(rates.map((k, v) => MapEntry(k, v.toJson()))),
        );
      } catch (_) {
        /* Keep valid quote in memory. */
      }
    } catch (_) {
      for (final id in rates.keys.toList()) {
        rates[id] = ExchangeRateModel.fromJson(
          rates[id]!.toJson(),
          offline: true,
        );
      }
      error = 'Sin conexión con el servicio de tasas. Se conserva la última cotización válida.';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
