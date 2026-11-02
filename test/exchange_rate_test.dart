import 'package:flutter_test/flutter_test.dart';
import 'package:nota_entrega_mobile/domain/exchange_rate.dart';

ExchangeRateModel quote(String id, String base, String rate) =>
    ExchangeRateModel(
      id: id,
      baseRate: base,
      rate: rate,
      updatedAt: DateTime.utc(2026, 11, 2),
    );
void main() {
  test('decimal conversions, reverse, rounding, formatting and bounds', () {
    final b = quote('binance', '893.200000', '899.200000');
    final c = quote('bcv', '889.580000', '889.580000');
    expect(Money.format(Money.convert('100', b)), '89.920,00');
    expect(
      Money.format(Money.convert('89920', b, toBolivares: false)),
      '100,00',
    );
    expect(Money.format(Money.convert('100', c)), '88.958,00');
    expect(
      Money.format(Money.convert('88958', c, toBolivares: false)),
      '100,00',
    );
    expect(Money.format(Money.convert('0,01', b)), '8,99');
    for (final input in ['-1', '1,2,3', 'NaN', '1e20', '']) {
      expect(() => Money.convert(input, b), throwsFormatException);
    }
  });
  test('never add adjustment twice and never to BCV', () {
    expect(() => quote('binance', '893.2', '905.2'), throwsFormatException);
    expect(() => quote('bcv', '889.58', '895.58'), throwsFormatException);
    expect(() => quote('bcv', '0', '0'), throwsFormatException);
  });
  test('snapshot preserves exact rate and offline status', () {
    final b = quote('binance', '893.2', '899.2');
    final restored = ExchangeRateModel.fromJson(b.toJson(), offline: true);
    expect(restored.rate, b.rate);
    expect(restored.stale, true);
  });
}
