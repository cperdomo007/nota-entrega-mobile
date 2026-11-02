import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nota_entrega_mobile/core/session.dart';
import 'package:nota_entrega_mobile/data/api.dart';
import 'package:nota_entrega_mobile/data/exchange_rate_service.dart';

class RateApi extends Api {
  RateApi()
    : super(Session(), baseUrl: 'https://api.example.com/api/mobile/v1/');
  int calls = 0;
  bool fail = false;
  @override
  Future<Map<String, dynamic>> get(
    String path, [
    Map<String, dynamic>? query,
  ]) async {
    calls++;
    if (fail) throw StateError('offline');
    return {
      'rates': {
        for (final id in ['bcv', 'binance'])
          id: {
            'id': id,
            'baseRate': '893.200000',
            'rate': id == 'binance' ? '899.200000' : '893.200000',
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
            'stale': false,
          },
      },
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'cache interval and persistence survive loss of network and restart',
    () async {
      final api = RateApi();
      final first = ExchangeRateService(api);
      await first.refresh();
      expect(first.rates['binance']!.rate, '899.200000');
      await first.refresh();
      expect(api.calls, 1);
      api.fail = true;
      final restarted = ExchangeRateService(api);
      await restarted.refresh();
      expect(restarted.rates['binance']!.rate, '899.200000');
      expect(restarted.rates['binance']!.stale, true);
      expect(restarted.error, isNotNull);
      first.dispose();
      restarted.dispose();
      api.dio.close();
    },
  );
  test('first offline launch never introduces a fictitious rate', () async {
    final api = RateApi()..fail = true;
    final service = ExchangeRateService(api);
    await service.refresh();
    expect(service.rates, isEmpty);
    expect(service.error, isNotNull);
    service.dispose();
    api.dio.close();
  });
}
