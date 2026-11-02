import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nota_entrega_mobile/main.dart';
import 'package:nota_entrega_mobile/core/session.dart';
import 'package:nota_entrega_mobile/data/api.dart';
import 'package:nota_entrega_mobile/domain/models.dart';

class SignedSession extends Session {
  @override
  bool get signedIn => true;
}

class MemoryApi extends Api {
  MemoryApi() : super(SignedSession());
  Json? submitted;
  final product = <String, dynamic>{
    'id': 1,
    'name': 'Router',
    'price': '100.00',
    'barcode': '123',
    'unit': 'UN',
    'hasSerial': true,
  };
  @override
  Future<Json> get(String path, [Json? query]) async => switch (path) {
    'dashboard' => {'clients': 1, 'products': 1, 'notes': 1},
    'config' => {'ivaRate': '16.00'},
    'notes/next-number' => {'noteNumber': 'NE-1'},
    _ => throw StateError(path),
  };
  @override
  Future<List<Json>> list(String path, String search, int offset) async =>
      path == 'clients'
      ? [
          {'id': 1, 'name': 'Cliente Uno', 'rif': 'J-1'},
        ]
      : [product];
  @override
  Future<int> create(Json draft, String idempotencyKey) async {
    submitted = draft;
    return 1;
  }

  @override
  Future<DeliveryNote> note(int id) async => DeliveryNote({
    'id': 1,
    'noteNumber': 'NE-1',
    'clientName': 'Cliente Uno',
    'noteDate': '2026-10-30',
    'subtotal': '100.00',
    'ivaAmount': '16.00',
    'total': '116.00',
    'lines': [
      {
        'productId': 1,
        'productName': 'Router',
        'quantity': 1,
        'unitPrice': '100.00',
        'lineTotal': '100.00',
        'serials': ['ABC'],
      },
    ],
  });
}

void main() {
  testWidgets(
    'crea una nota con cliente, producto y serial y abre el detalle',
    (tester) async {
      final api = MemoryApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWithValue(SignedSession()),
            apiProvider.overrideWithValue(api),
          ],
          child: const NotaEntregaApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear nota de entrega'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seleccionar cliente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cliente Uno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar producto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Router'));
      await tester.pumpAndSettle();
      final serial = find.widgetWithText(TextField, 'Serial');
      await tester.enterText(serial, 'ABC');
      await tester.tap(find.byTooltip('Agregar serial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Crear nota'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Crear nota'));
      await tester.pumpAndSettle();
      expect(api.submitted!['clientName'], 'Cliente Uno');
      expect((api.submitted!['lines'] as List).single['serials'], ['ABC']);
      expect(find.text('Detalle de nota'), findsOneWidget);
      expect(find.text('Total: 116.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
