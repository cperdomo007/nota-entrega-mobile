import 'package:flutter_test/flutter_test.dart';
import 'package:nota_entrega_mobile/domain/models.dart';
import 'package:nota_entrega_mobile/core/config.dart';
import 'package:nota_entrega_mobile/data/note_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const product = Product(1, 'Router', 10025, '123', 'UN', true);
  test('importes decimales exactos en centavos', () {
    expect(cents('100.25'), 10025);
    expect(cents('0.1'), 10);
    expect(() => cents('NaN'), throwsFormatException);
    expect(() => cents('-1'), throwsFormatException);
    expect(() => cents('1.001'), throwsFormatException);
  });
  test('valida cantidades y seriales requeridos', () {
    expect(validateLines([]), isNotNull);
    expect(validateLines([DraftLine(product, 0, 100, [])]), isNotNull);
    expect(
      validateLines([
        DraftLine(product, 2, 100, [' A ']),
      ]),
      isNotNull,
    );
    expect(
      validateLines([
        DraftLine(product, 1, 100, [' A ']),
      ]),
      isNull,
    );
  });
  test('rechaza serial duplicado entre líneas', () {
    expect(
      validateLines([
        DraftLine(product, 1, 100, ['A']),
        DraftLine(product, 1, 100, [' A ']),
      ]),
      contains('duplicado'),
    );
  });
  test('seriales se normalizan y payload no contiene totales confiables', () {
    final line = DraftLine(product, 2, 10025, [' A ', 'B']);
    expect(line.total, 20050);
    expect(line.toJson(), {
      'productId': 1,
      'quantity': 2,
      'unitPrice': '100.25',
      'serials': ['A', 'B'],
    });
  });
  test('configuración requiere HTTPS y sin credenciales', () {
    expect(AppConfig.isHttps('http://example.com'), isFalse);
    expect(AppConfig.isHttps('https://user:pass@example.com'), isFalse);
    expect(AppConfig.isHttps('https://example.com/api/mobile/v1/'), isTrue);
  });
  test('genera un documento PDF multipágina', () async {
    final note = DeliveryNote({
      'id': 1,
      'noteNumber': 'NE-1',
      'noteDate': '2026-10-30',
      'clientName': 'José Muñoz',
      'subtotal': '100.00',
      'ivaAmount': '16.00',
      'total': '116.00',
      'lines': List.generate(
        80,
        (i) => {
          'productId': i,
          'productName': 'Producto $i',
          'quantity': 1,
          'unitPrice': '1.25',
          'lineTotal': '1.25',
          'serials': ['S$i'],
        },
      ),
    });
    final bytes = await buildNotePdf(note);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
}
