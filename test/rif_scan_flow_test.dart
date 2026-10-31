import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nota_entrega_mobile/ui/entity_create_screen.dart';
import 'package:nota_entrega_mobile/ui/rif_scan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var calls = <String>[];
  Future<Object?> Function(MethodCall)? handler;
  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(rifScannerChannel, (call) async {
          calls.add(call.method);
          return handler?.call(call);
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(rifScannerChannel, null);
  });
  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: EntityCreateScreen(kind: 'clients')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, String source) async {
    await tester.tap(find.text('Leer datos desde RIF'));
    // The form deliberately shows an indeterminate progress indicator until
    // the picker/review flow ends, so do not wait for all animations to settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(source));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  String value(WidgetTester tester, String label) => tester
      .widget<TextFormField>(find.widgetWithText(TextFormField, label))
      .controller!
      .text;

  testWidgets(
    'camera suggestions require review, can be corrected, never auto-save',
    (tester) async {
      handler = (_) async => 'RIF: J123456789\nEMPRESA DEMO\nDOMICILIO FISCAL: AV DEMO\nFECHA DE VENCIMIENTO: 2030';
      await boot(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre o razón social'),
        'Nombre anterior',
      );
      await open(tester, 'Escanear con cámara');
      expect(calls, ['camera']);
      expect(find.text('Revisar datos del RIF'), findsOneWidget);
      expect(value(tester, 'Nombre o razón social'), 'Nombre anterior');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre o razón social detectado'),
        'Nombre corregido',
      );
      await tester.tap(find.text('Aplicar al formulario'));
      await tester.pumpAndSettle();
      expect(value(tester, 'Nombre o razón social'), 'Nombre corregido');
      expect(value(tester, 'RIF'), 'J123456789');
      expect(value(tester, 'Dirección'), 'AV DEMO');
      expect(find.text('Nuevo cliente'), findsOneWidget);
    },
  );
  testWidgets('cancel review and cancel picker preserve current fields', (
    tester,
  ) async {
    handler = (_) async => 'J123456789 EMPRESA DEMO\nDOMICILIO FISCAL AV DEMO';
    await boot(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre o razón social'),
      'Sin cambios',
    );
    await open(tester, 'Elegir imagen o PDF');
    expect(calls, ['file']);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(value(tester, 'Nombre o razón social'), 'Sin cambios');
    handler = (_) async => null;
    await open(tester, 'Elegir imagen o PDF');
    expect(find.text('Revisar datos del RIF'), findsNothing);
    expect(value(tester, 'Nombre o razón social'), 'Sin cambios');
  });
  testWidgets('read failure preserves fields and allows another attempt', (
    tester,
  ) async {
    handler = (_) async => throw PlatformException(code: 'FILE_TOO_LARGE');
    await boot(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre o razón social'),
      'Conservado',
    );
    await open(tester, 'Elegir imagen o PDF');
    expect(
      find.text('El archivo supera 20 MB. Elige un archivo más pequeño.'),
      findsOneWidget,
    );
    expect(value(tester, 'Nombre o razón social'), 'Conservado');
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Leer datos desde RIF'),
          )
          .onPressed,
      isNotNull,
    );
  });
}
