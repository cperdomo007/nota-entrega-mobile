import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nota_entrega_mobile/main.dart';
import 'package:nota_entrega_mobile/core/session.dart';

void main() {
  testWidgets('una ruta protegida dirige al inicio de sesión', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWithValue(Session())],
        child: const NotaEntregaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nota Entrega Mobile'), findsOneWidget);
    expect(find.text('Iniciar sesión segura'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
