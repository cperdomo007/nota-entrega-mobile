import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';
import '../data/exchange_rate_service.dart';
import '../domain/exchange_rate.dart';

final exchangeRateServiceProvider = Provider<ExchangeRateService>((ref) {
  final service = ExchangeRateService(ref.watch(apiProvider));
  ref.onDispose(service.dispose);
  return service;
});

class ExchangeRatesSection extends ConsumerStatefulWidget {
  const ExchangeRatesSection({super.key});
  @override
  ConsumerState<ExchangeRatesSection> createState() =>
      _ExchangeRatesSectionState();
}

class _ExchangeRatesSectionState extends ConsumerState<ExchangeRatesSection> {
  late ExchangeRateService service;
  @override
  void initState() {
    super.initState();
    service = ref.read(exchangeRateServiceProvider);
    service.addListener(changed);
    Future.microtask(service.refresh);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    service.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tasas de cambio',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar tasas',
                    onPressed: service.busy ? null : service.refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              if (service.busy) const LinearProgressIndicator(),
              if (service.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    service.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              LayoutBuilder(
                builder: (context, c) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final id in ['bcv', 'binance'])
                      SizedBox(
                        width: c.maxWidth >= 320
                            ? (c.maxWidth - 8) / 2
                            : c.maxWidth,
                        child: ExchangeRateCard(
                          id: id,
                          rate: service.rates[id],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      CurrencyCalculator(rates: service.rates),
    ],
  );
}

class ExchangeRateCard extends StatelessWidget {
  final String id;
  final ExchangeRateModel? rate;
  const ExchangeRateCard({super.key, required this.id, this.rate});
  @override
  Widget build(BuildContext context) {
    final value = rate;
    final stale =
        value != null &&
        (value.stale ||
            DateTime.now().toUtc().difference(value.updatedAt.toUtc()) >=
                const Duration(minutes: 5));
    String updated = 'Sin cotización disponible';
    if (value != null) {
      final t = value.updatedAt.toUtc().subtract(const Duration(hours: 4));
      String two(int n) => n.toString().padLeft(2, '0');
      updated =
          '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)} (Venezuela)';
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              id == 'bcv' ? '🇻🇪 Dólar BCV' : '◆ USDT Binance',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            SelectableText(
              value == null ? 'No disponible' : 'Bs ${value.formatted}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            if (id == 'binance') ...[
              Text(
                value == null
                    ? 'Ajuste: + Bs 6,00'
                    : 'Base: Bs ${Money.format((Money.parse(value.baseRate) + BigInt.from(5000)) ~/ BigInt.from(10000))} + Bs 6,00',
              ),
              const Text(
                'Compra USDT · Pago Móvil',
                style: TextStyle(fontSize: 12),
              ),
            ],
            if (id == 'bcv')
              Text(
                value?.source == 'https://rates.dolarvzla.com/bcv/current.json'
                    ? 'USD/VES · BCV vía DolarVZLA'
                    : 'USD/VES · Fuente: BCV',
                style: TextStyle(fontSize: 12),
              ),
            if (id == 'bcv' && value?.effectiveAt != null)
              Text(
                'Vigencia: ${value!.effectiveAt!.substring(0, 10)}',
                style: const TextStyle(fontSize: 11),
              ),
            const SizedBox(height: 6),
            Text(updated, style: const TextStyle(fontSize: 11)),
            if (stale)
              const Text(
                'Desactualizada',
                style: TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ExchangeRateSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const ExchangeRateSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final id in ['binance', 'bcv'])
        ChoiceChip(
          label: Text(id == 'bcv' ? '🇻🇪 Dólar BCV' : '◆ USDT Binance'),
          selected: selected == id,
          onSelected: (_) => onChanged(id),
        ),
    ],
  );
}

class CurrencyCalculator extends StatefulWidget {
  final Map<String, ExchangeRateModel> rates;
  const CurrencyCalculator({super.key, required this.rates});
  @override
  State<CurrencyCalculator> createState() => _CurrencyCalculatorState();
}

class _CurrencyCalculatorState extends State<CurrencyCalculator> {
  final input = TextEditingController(text: '100');
  String selected = 'binance';
  bool toBolivares = true;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void key(String key) {
    final old = input.text;
    final value = key == 'C'
        ? ''
        : key == '⌫'
        ? (old.isEmpty ? '' : old.substring(0, old.length - 1))
        : old + key;
    input.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final rate = widget.rates[selected];
    String? result, error;
    if (rate != null && input.text.isNotEmpty) {
      try {
        result = Money.format(
          Money.convert(input.text, rate, toBolivares: toBolivares),
        );
      } on FormatException catch (e) {
        error = e.message;
      }
    }
    final foreign = selected == 'bcv' ? 'USD' : 'USDT';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.calculate_outlined),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Calculadora de cambio',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ExchangeRateSelector(
              selected: selected,
              onChanged: (v) => setState(() => selected = v),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('exchange-amount'),
              controller: input,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Monto (${toBolivares ? foreign : 'Bs'})',
                border: const OutlineInputBorder(),
                errorText: error,
                suffixIcon: IconButton(
                  tooltip: 'Limpiar monto',
                  onPressed: () => key('C'),
                  icon: const Icon(Icons.clear),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: IconButton(
                tooltip: 'Invertir conversión',
                onPressed: () => setState(() => toBolivares = !toBolivares),
                icon: const Icon(Icons.swap_vert),
              ),
            ),
            const Text('Equivalente'),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    '${result ?? '—'} ${toBolivares ? 'Bs' : foreign}',
                    key: const Key('exchange-result'),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar resultado',
                  onPressed: result == null
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: result!));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Resultado copiado'),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
            if (rate == null)
              const Text(
                'La conversión requiere una tasa válida. Actualiza las tasas.',
              ),
            if (rate != null &&
                (rate.stale ||
                    DateTime.now().toUtc().difference(rate.updatedAt.toUtc()) >=
                        const Duration(minutes: 5)))
              const Text(
                'Conversión con la última tasa válida, desactualizada.',
                style: TextStyle(color: Colors.deepOrange),
              ),
            const SizedBox(height: 12),
            for (final row in [
              ['7', '8', '9'],
              ['4', '5', '6'],
              ['1', '2', '3'],
              [',', '0', '⌫'],
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    for (final digit in row)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: FilledButton.tonal(
                            onPressed: () => key(digit),
                            child: Text(
                              digit,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
