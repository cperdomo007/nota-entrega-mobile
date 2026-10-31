import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nota_entrega_mobile/core/session.dart';
import 'package:nota_entrega_mobile/data/api.dart';
import 'package:nota_entrega_mobile/domain/models.dart';
import 'package:nota_entrega_mobile/main.dart';

class _SignedSession extends Session {
  @override
  bool get signedIn => true;
}

class _BudgetApi extends Api {
  _BudgetApi() : super(_SignedSession());
  String? searched;
  final data = <String, dynamic>{
    'id': 2,
    'budgetNumber': 'PRE-2',
    'budgetDate': '2026-10-28',
    'clientName': 'Cliente de prueba',
    'subtotal': '10.00',
    'applyIVA': false,
    'ivaAmount': '0.00',
    'total': '10.00',
    'lines': [
      {
        'productId': 987654321,
        'barcode': 'SKU-NEVER-PRINT',
        'description': 'Servicio histórico',
        'quantity': 1,
        'unitPrice': '10.00',
        'lineTotal': '10.00',
      },
    ],
  };
  @override
  Future<Json> get(String path, [Json? query]) async => switch (path) {
    'dashboard' => {'clients': 0, 'products': 0, 'notes': 0},
    'budgets/2' => data,
    _ => throw StateError(path),
  };
  @override
  Future<List<Json>> list(String path, String search, int offset) async {
    expect(path, 'budgets');
    expect(offset, 0);
    searched = search;
    return [data];
  }
}

void main() {
  testWidgets(
    'busca un presupuesto web y muestra el detalle sin códigos ni acciones de edición',
    (tester) async {
      final api = _BudgetApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWithValue(_SignedSession()),
            apiProvider.overrideWithValue(api),
          ],
          child: const NotaEntregaApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Presupuestos'));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.enterText(find.byType(TextField), 'PRE-2');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(api.searched, 'PRE-2');
      await tester.tap(find.widgetWithText(ListTile, 'PRE-2'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle de presupuesto'), findsOneWidget);
      expect(find.text('Servicio histórico × 1'), findsOneWidget);
      expect(find.text('Total: 10.00'), findsOneWidget);
      expect(find.text('IVA: 0.00'), findsNothing);
      expect(find.textContaining('987654321'), findsNothing);
      expect(find.textContaining('SKU-NEVER-PRINT'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Generar y compartir PDF'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Generar y compartir PDF'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
