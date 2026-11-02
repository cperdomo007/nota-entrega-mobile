class Money {
  static const scale = 1000000;
  static BigInt parse(String value, {int decimals = 6}) {
    if (!RegExp(r'^\d{1,15}([.,]\d{0,6})?$').hasMatch(value)) {
      throw const FormatException(
        'Ingresa un monto positivo con hasta seis decimales',
      );
    }
    final parts = value.replaceAll(',', '.').split('.');
    final fraction = parts.length == 2 ? parts[1] : '';
    if (fraction.length > decimals) {
      throw const FormatException('Demasiados decimales');
    }
    return BigInt.parse(parts[0]) * BigInt.from(10).pow(decimals) +
        BigInt.parse(fraction.padRight(decimals, '0'));
  }

  static String format(BigInt cents) {
    final digits = (cents ~/ BigInt.from(100)).toString();
    final grouped = digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '$grouped,${(cents % BigInt.from(100)).toString().padLeft(2, '0')}';
  }

  static BigInt convert(
    String input,
    ExchangeRateModel rate, {
    bool toBolivares = true,
  }) {
    final amount = parse(input);
    final divisor = toBolivares
        ? BigInt.from(scale) * BigInt.from(scale)
        : rate.units;
    final numerator = toBolivares
        ? amount * rate.units * BigInt.from(100)
        : amount * BigInt.from(100);
    if (rate.units <= BigInt.zero) {
      throw const FormatException('Tasa no disponible');
    }
    return (numerator + divisor ~/ BigInt.two) ~/ divisor;
  }
}

class ExchangeRateModel {
  final String id, baseRate, rate;
  final DateTime updatedAt;
  final bool stale;
  final String? paymentMethod, methodology, source, effectiveAt;
  ExchangeRateModel({
    required this.id,
    required this.baseRate,
    required this.rate,
    required this.updatedAt,
    this.stale = false,
    this.paymentMethod,
    this.methodology,
    this.source,
    this.effectiveAt,
  }) {
    if (!['bcv', 'binance'].contains(id) ||
        units <= BigInt.zero ||
        units !=
            Money.parse(baseRate) +
                (id == 'binance' ? BigInt.from(6000000) : BigInt.zero)) {
      throw const FormatException('Tasa de cambio inválida');
    }
  }
  BigInt get units => Money.parse(rate);
  String get name => id == 'bcv' ? 'Dólar BCV' : 'USDT Binance';
  String get currency => id == 'bcv' ? 'USD' : 'USDT';
  String get formatted =>
      Money.format((units + BigInt.from(5000)) ~/ BigInt.from(10000));
  factory ExchangeRateModel.fromJson(
    Map<String, dynamic> j, {
    bool offline = false,
  }) => ExchangeRateModel(
    id: j['id'] as String,
    baseRate: j['baseRate'] as String,
    rate: j['rate'] as String,
    updatedAt: DateTime.parse(j['updatedAt'] as String),
    stale: offline || j['stale'] == true,
    paymentMethod: j['paymentMethod'] as String?,
    methodology: j['methodology'] as String?,
    source: j['source'] as String?,
    effectiveAt: j['effectiveAt'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'baseRate': baseRate,
    'rate': rate,
    'updatedAt': updatedAt.toIso8601String(),
    'stale': stale,
    'paymentMethod': paymentMethod,
    'methodology': methodology,
    'source': source,
    'effectiveAt': effectiveAt,
  };
  // Immutable snapshot ready for a future document contract; no existing totals change.
}
