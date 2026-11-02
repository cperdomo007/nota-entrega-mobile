import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nota_entrega_mobile/domain/exchange_rate.dart';
import 'package:nota_entrega_mobile/ui/exchange_rates.dart';

void main() {
  for (final width in [320.0, 600.0]) {
    testWidgets('calculator selection and reverse at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final rates = {
        'binance': ExchangeRateModel(
          id: 'binance',
          baseRate: '893.2',
          rate: '899.2',
          updatedAt: DateTime.now(),
        ),
        'bcv': ExchangeRateModel(
          id: 'bcv',
          baseRate: '889.58',
          rate: '889.58',
          updatedAt: DateTime.now(),
        ),
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CurrencyCalculator(rates: rates),
            ),
          ),
        ),
      );
      expect(find.text('89.920,00 Bs'), findsOneWidget);
      await tester.tap(find.text('🇻🇪 Dólar BCV'));
      await tester.pump();
      expect(find.text('88.958,00 Bs'), findsOneWidget);
      await tester.tap(find.byTooltip('Invertir conversión'));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('exchange-amount')), '88958');
      await tester.pump();
      expect(find.text('100,00 USD'), findsOneWidget);
      await tester.tap(find.byTooltip('Limpiar monto'));
      await tester.pump();
      expect(find.text('— USD'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
