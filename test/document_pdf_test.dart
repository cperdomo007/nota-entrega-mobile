import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nota_entrega_mobile/data/note_pdf.dart';
import 'package:nota_entrega_mobile/domain/models.dart';

// Fictitious examples only. Do not copy customer documents into this fixture.
Json sampleDocument({bool budget = false}) => {
  'id': 1,
  'noteNumber': '301020260001',
  'budgetNumber': '281020260001',
  'noteDate': '2026-10-30',
  'budgetDate': '2026-10-28',
  'company': {
    'businessName': 'SUMISISTEMAS, C.A.',
    'rif': 'J-00000000-0',
    'address': 'Calle Principal, Edificio Comercial, Barquisimeto, Lara.',
    'phone1': '0251-0000000',
    'phone2': '0412-0000000',
    'email': 'ventas@example.com',
    'website': 'https://example.com',
  },
  'clientName': 'CLIENTE DE EJEMPLO, C.A.',
  'clientRif': 'J-11111111-1',
  'clientAddress': 'Avenida Principal, Local 12, Barquisimeto, Lara.',
  'clientContact': 'Departamento de compras',
  'clientPhone': '0414-0000000',
  'subtotal': '317.50',
  'applyIVA': true,
  'ivaAmount': '50.80',
  'total': '368.30',
  'observations': 'Equipos con garantía de 1 año. Tasa BCV.',
  'deliveredBy': '',
  'receivedBy': '',
  'lines': [
    {
      'productId': 987654321,
      'barcode': 'SKU-NEVER-PRINT',
      'productName': 'Router de red empresarial',
      'description': 'Router de red empresarial',
      'quantity': 1,
      'unitPrice': '250.00',
      'lineTotal': '250.00',
      'serials': budget ? <String>[] : ['SERIAL-EJEMPLO-001'],
    },
    {
      'productId': 987654322,
      'barcode': 'SKU-NEVER-PRINT',
      'productName': 'Cable de red categoría 6',
      'description': 'Cable de red categoría 6',
      'quantity': 30,
      'unitPrice': '2.25',
      'lineTotal': '67.50',
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'exporta ambas plantillas y casos de paginación sin perder seriales',
    () async {
      final folder = Directory('build/pdf-preview');
      await folder.create(recursive: true);
      final note = sampleDocument();
      final budget = sampleDocument(budget: true);
      for (final entry in {
        'nota-entrega': await buildNotePdf(DeliveryNote(note)),
        'presupuesto': await buildBudgetPdf(Budget(budget)),
        'sin-iva': await buildBudgetPdf(
          Budget({
            ...budget,
            'applyIVA': false,
            'ivaAmount': '0.00',
            'total': '317.50',
          }),
        ),
        'sin-descripcion': await buildNotePdf(
          DeliveryNote({
            ...note,
            'lines': [
              {
                'productId': 987654321,
                'barcode': 'SKU-NEVER-PRINT',
                'quantity': 1,
                'unitPrice': '1.00',
                'lineTotal': '1.00',
              },
            ],
          }),
        ),
        'multipagina': await buildNotePdf(
          DeliveryNote({
            ...note,
            'lines': List.generate(
              80,
              (i) => {
                'productId': 987654321,
                'barcode': 'SKU-NEVER-PRINT',
                'productName': 'Producto de prueba ${i + 1}',
                'quantity': 1,
                'unitPrice': '1.00',
                'lineTotal': '1.00',
                'serials': ['SERIAL-PRUEBA-${i + 1}'],
              },
            ),
          }),
        ),
        'seriales-largos': await buildNotePdf(
          DeliveryNote({
            ...note,
            'lines': [
              {
                ...(note['lines'] as List).first as Json,
                'serials': List.generate(500, (i) => 'SERIAL-LARGO-${i + 1}'),
              },
            ],
            'observations': List.filled(70, 'Condiciones de prueba.').join(' '),
          }),
        ),
      }.entries) {
        expect(String.fromCharCodes(entry.value.take(5)), '%PDF-');
        await File('${folder.path}/${entry.key}.pdf').writeAsBytes(entry.value);
      }
    },
  );
}
