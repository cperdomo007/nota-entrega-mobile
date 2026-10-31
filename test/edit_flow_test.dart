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

class _EditApi extends Api {
  _EditApi() : super(_Session());
  final objects = <String, Json>{
    'clients': {
      'id': 1,
      'name': 'Cliente inicial',
      'rif': 'J-1',
      'address': 'Dirección',
      'phone': '123',
      'email': 'client@example.com',
      'contact': 'Compras',
      '_version': 'a' * 64,
    },
    'products': {
      'id': 1,
      'name': 'Router',
      'price': '10.00',
      'unit': 'UN',
      'barcode': 'SKU-1',
      'hasSerial': true,
      'stock': 4,
      '_version': 'a' * 64,
    },
    'notes': {
      'id': 1,
      'noteNumber': '301020261710',
      'noteDate': '2026-10-30',
      'clientName': 'Cliente inicial',
      'applyIVA': true,
      'subtotal': '10.00',
      'ivaAmount': '1.60',
      'total': '11.60',
      '_version': 'a' * 64,
      'lines': [
        {
          'productId': 1,
          'productName': 'Router',
          'hasSerial': true,
          'quantity': 1,
          'unitPrice': '10.00',
          'lineTotal': '10.00',
          'serials': ['OLD'],
        },
      ],
    },
    'budgets': {
      'id': 1,
      'budgetNumber': '301020261711',
      'budgetDate': '2026-10-30',
      'clientName': 'Cliente inicial',
      'applyIVA': true,
      'subtotal': '20.00',
      'ivaAmount': '3.20',
      'total': '23.20',
      '_version': 'a' * 64,
      'lines': [
        {
          'productId': null,
          'description': 'Servicio histórico',
          'quantity': 2,
          'unitPrice': '10.00',
          'lineTotal': '20.00',
        },
      ],
    },
  };
  Json? updated;
  @override
  Future<Json> get(String path, [Json? query]) async {
    if (path == 'dashboard') return {'clients': 1, 'products': 1, 'notes': 1};
    if (path == 'config') return {'ivaRate': '16.00'};
    return objects[path.split('/').first]!;
  }

  @override
  Future<List<Json>> list(String path, String search, int offset) async => [
    objects[path]!,
  ];
  @override
  Future<DeliveryNote> note(int id) async => DeliveryNote(objects['notes']!);
  @override
  Future<Budget> budget(int id) async => Budget(objects['budgets']!);
  @override
  Future<void> updateEntity(String kind, int id, Json data, String key) async {
    expect(id, 1);
    expect(data['_version'], 'a' * 64);
    expect(key.length, greaterThanOrEqualTo(24));
    updated = data;
    objects[kind] = {...objects[kind]!, ...data, '_version': 'b' * 64};
  }
}

Future<void> _boot(WidgetTester tester, _EditApi api, String title) async {
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
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester, String label) async {
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
  for (final product in [false, true]) {
    testWidgets(
      product ? 'edita producto existente' : 'edita cliente existente',
      (tester) async {
        final api = _EditApi();
        await _boot(tester, api, product ? 'Productos' : 'Clientes');
        await tester.tap(find.text(product ? 'Router' : 'Cliente inicial'));
        await tester.pumpAndSettle();
        expect(
          find.text(product ? 'Editar producto' : 'Editar cliente'),
          findsOneWidget,
        );
        final name = find.widgetWithText(
          TextFormField,
          product ? 'Nombre del producto' : 'Nombre o razón social',
        );
        expect(
          tester.widget<TextFormField>(name).controller!.text,
          product ? 'Router' : 'Cliente inicial',
        );
        await tester.enterText(name, 'Nombre actualizado');
        await _save(tester, product ? 'Guardar producto' : 'Guardar cliente');
        expect(api.updated!['name'], 'Nombre actualizado');
        expect(api.objects[product ? 'products' : 'clients']!['id'], 1);
        expect(find.text('Nombre actualizado'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'edita nota, mantiene número y permite modificar cantidad y seriales',
    (tester) async {
      final api = _EditApi();
      await _boot(tester, api, 'Notas de entrega');
      await tester.tap(find.text('301020261710'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Editar nota'));
      await tester.pumpAndSettle();
      final number = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Número (DDMMAAAAHHMM)'),
      );
      expect(number.readOnly, true);
      expect(number.controller!.text, '301020261710');
      await tester.tap(find.text('Router × 1'));
      await tester.pumpAndSettle();
      expect(find.text('OLD'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Cantidad entera'),
        '2',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Serial'), 'NEW');
      await tester.tap(find.byTooltip('Agregar serial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      await _save(tester, 'Guardar cambios');
      expect(api.updated!.containsKey('noteNumber'), false);
      expect((api.updated!['lines'] as List).single['serials'], ['OLD', 'NEW']);
      expect((api.updated!['lines'] as List).single['quantity'], 2);
      expect(find.text('Detalle de nota'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('edita presupuesto histórico con producto nulo sin renumerarlo', (
    tester,
  ) async {
    final api = _EditApi();
    await _boot(tester, api, 'Presupuestos');
    await tester.tap(find.text('301020261711'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar presupuesto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Servicio histórico × 2'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Descripción del presupuesto'),
      'Servicio corregido',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Cantidad entera'),
      '3',
    );
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    await _save(tester, 'Guardar cambios');
    expect(api.updated!.containsKey('budgetNumber'), false);
    expect((api.updated!['lines'] as List).single['productId'], isNull);
    expect(
      (api.updated!['lines'] as List).single['description'],
      'Servicio corregido',
    );
    expect(find.text('Detalle de presupuesto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
