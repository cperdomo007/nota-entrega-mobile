import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nota_entrega_mobile/core/session.dart';
import 'package:nota_entrega_mobile/data/api.dart';
import 'package:nota_entrega_mobile/domain/models.dart';
import 'package:nota_entrega_mobile/main.dart';

class _Session extends Session {
  @override
  bool get signedIn => true;
}

class _Api extends Api {
  _Api() : super(_Session());
  final records = <String, List<Json>>{
    'clients': [],
    'products': [],
    'budgets': [],
  };
  Json? budgetPayload;
  @override
  Future<Json> get(String path, [Json? query]) async => switch (path) {
    'dashboard' => {'clients': 0, 'products': 0, 'notes': 0},
    'config' => {'ivaRate': '16.00'},
    'budgets/next-number' => {'budgetNumber': '301020261710'},
    _ => throw StateError(path),
  };
  @override
  Future<List<Json>> list(String path, String search, int offset) async =>
      records[path]!;
  @override
  Future<int> createEntity(String kind, Json data, String key) async {
    expect(key.length, greaterThanOrEqualTo(24));
    if (kind == 'budgets') {
      budgetPayload = data;
      return 1;
    }
    records[kind]!.add({...data, 'id': 1});
    return 1;
  }

  @override
  Future<Budget> budget(int id) async => Budget({
    ...budgetPayload!,
    'id': 1,
    'budgetNumber': '301020261710',
    'subtotal': '20.25',
    'ivaAmount': '3.24',
    'total': '23.49',
    'lines': [
      {
        ...(budgetPayload!['lines'] as List).first as Json,
        'lineTotal': '20.25',
      },
    ],
  });
}

Future<void> _boot(WidgetTester tester, _Api api) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWithValue(_Session()),
        apiProvider.overrideWithValue(api),
      ],
      child: const NotaEntregaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _saveForm(WidgetTester tester, String label) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text(label),
    250,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('agrega un cliente desde el listado y actualiza los datos', (
    tester,
  ) async {
    final api = _Api();
    await _boot(tester, api);
    await tester.tap(find.text('Clientes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre o razón social'),
      'Cliente nuevo',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'RIF'),
      'J-00000000-0',
    );
    await _saveForm(tester, 'Guardar cliente');
    expect(api.records['clients']!.single['name'], 'Cliente nuevo');
    expect(find.text('Cliente nuevo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'agrega producto con código, precio, unidad y control de serial',
    (tester) async {
      final api = _Api();
      await _boot(tester, api);
      await tester.tap(find.text('Productos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre del producto'),
        'Router nuevo',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Código de producto (opcional)'),
        'SKU-1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Precio'),
        '20,25',
      );
      await tester.scrollUntilVisible(
        find.text('Requiere serial por unidad'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await _saveForm(tester, 'Guardar producto');
      expect(api.records['products']!.single, containsPair('price', '20.25'));
      expect(api.records['products']!.single['hasSerial'], true);
      expect(find.text('Router nuevo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'crea presupuesto sin seriales físicos y usa descripción histórica',
    (tester) async {
      final api = _Api();
      api.records['clients']!.add({
        'id': 1,
        'name': 'Cliente Uno',
        'rif': 'J-1',
      });
      api.records['products']!.add({
        'id': 1,
        'name': 'Router',
        'price': '20.25',
        'hasSerial': true,
        'unit': 'UN',
      });
      await _boot(tester, api);
      await tester.tap(find.text('Presupuestos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo presupuesto'), findsOneWidget);
      final number = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Número (DDMMAAAAHHMM)'),
      );
      expect(number.readOnly, true);
      expect(number.controller!.text, '301020261710');
      await tester.tap(find.text('Seleccionar cliente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cliente Uno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar producto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Router'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Serial'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Descripción del presupuesto'),
        'Router con instalación',
      );
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      await _saveForm(tester, 'Crear presupuesto');
      expect(api.budgetPayload!.containsKey('budgetNumber'), false);
      expect(
        (api.budgetPayload!['lines'] as List).single['description'],
        'Router con instalación',
      );
      expect(find.text('Detalle de presupuesto'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
