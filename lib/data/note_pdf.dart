import 'package:flutter/services.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/models.dart';

Future<Uint8List> buildNotePdf(DeliveryNote note) async {
  final d = note.data;
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
  );
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        pw.Header(level: 0, child: pw.Text('Nota de entrega ${note.number}')),
        pw.Text('${d['companyName'] ?? ''}'),
        pw.Text('Fecha: ${d['noteDate']}'),
        pw.Text('Cliente: ${note.client}'),
        pw.Text('RIF: ${d['clientRif'] ?? ''}'),
        pw.Text('${d['clientAddress'] ?? ''}'),
        pw.Text('Teléfono: ${d['clientPhone'] ?? ''}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['Producto', 'Cant.', 'Precio', 'Importe'],
          data: note.lines
              .map(
                (l) => [
                  l['productName'] ?? l['productId'],
                  l['quantity'],
                  l['unitPrice'],
                  l['lineTotal'],
                ],
              )
              .toList(),
        ),
        for (final l in note.lines)
          if ((l['serials'] as List? ?? []).isNotEmpty)
            pw.Paragraph(
              text:
                  '${l['productName'] ?? l['productId']} - Seriales: ${(l['serials'] as List).join(', ')}',
            ),
        pw.Text('Subtotal: ${d['subtotal']}'),
        pw.Text('IVA: ${d['ivaAmount']}'),
        pw.Text(
          'Total: ${d['total']}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.Paragraph(text: 'Observaciones: ${d['observations'] ?? ''}'),
        pw.Paragraph(text: 'Entregado por: ${d['deliveredBy'] ?? ''}'),
        pw.Paragraph(text: 'Recibido por: ${d['receivedBy'] ?? ''}'),
      ],
    ),
  );
  return pdf.save();
}
