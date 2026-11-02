import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/models.dart';

// IDs/barcodes are persistence/search fields, never printable fallbacks.
String documentLineDescription(Json line, {required bool budget}) {
  final value = line[budget ? 'description' : 'productName'];
  return value is String && value.trim().isNotEmpty
      ? value.trim()
      : 'Producto sin descripción';
}

String _text(Object? value) => value?.toString() ?? '';

String _date(Object? value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(_text(value));
  return match == null ? _text(value) : '${match[3]}-${match[2]}-${match[1]}';
}

// Use persisted amounts; these templates do not convert currencies.
String _amount(Object? value, bool budget) =>
    '${budget ? '' : r'$'}${money(cents(value ?? '0'))}';

pw.Widget _label(String label, Object? value) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 2.5),
  child: pw.RichText(
    text: pw.TextSpan(
      children: [
        pw.TextSpan(
          text: '$label ',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.TextSpan(text: _text(value)),
      ],
    ),
  ),
);

pw.Widget _box(String label, Object? value) => pw.Container(
  constraints: const pw.BoxConstraints(minHeight: 34),
  padding: const pw.EdgeInsets.all(6),
  decoration: pw.BoxDecoration(border: pw.Border.all(width: .6)),
  child: pw.Column(
    children: [
      pw.Text(
        label,
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
      ),
      pw.SizedBox(height: 3),
      pw.Text(
        _text(value),
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    ],
  ),
);

pw.Widget _header(Json d, pw.ImageProvider logo, bool budget) {
  final company =
      (d['company'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  final phones = [
    company['phone1'],
    company['phone2'],
  ].map(_text).where((value) => value.isNotEmpty).join(' / ');
  return pw.DefaultTextStyle(
    style: const pw.TextStyle(fontSize: 8),
    child: pw.Column(
      children: [
        pw.Container(
          constraints: pw.BoxConstraints(minHeight: budget ? 72 : 88),
          padding: pw.EdgeInsets.only(bottom: budget ? 12 : 16),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: .6)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: budget ? 150 : 170,
                child: pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Image(
                    logo,
                    width: 125,
                    height: 58,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
              pw.SizedBox(width: 28),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (_text(company['businessName']).isNotEmpty &&
                        company['rif'] == null)
                      pw.Text(_text(company['businessName'])),
                    _label(budget ? 'Rif:' : 'R.I.F:', company['rif']),
                    _label('Dirección Fiscal:', company['address']),
                    _label('Teléfonos:', phones),
                    _label('E-mail:', company['email']),
                    _label('Website:', company['website']),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 18),
        pw.Row(
          children: [
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                budget ? 'PRESUPUESTO' : 'NOTA DE ENTREGA',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 12.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(width: 18),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 5,
                ),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
                child: pw.Text(
                  'N° ${d[budget ? 'budgetNumber' : 'noteNumber']}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Datos del Cliente',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 8),
                  _label('Nombre o Razón Social:', d['clientName']),
                  _label(budget ? 'Rif:' : 'R.I.F:', d['clientRif']),
                  _label('Dirección:', d['clientAddress']),
                ],
              ),
            ),
            pw.SizedBox(width: 24),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: _box(
                          budget ? 'Cliente' : 'Cédula/RIF',
                          d['clientRif'],
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: _box(
                          'Fecha',
                          _date(d[budget ? 'budgetDate' : 'noteDate']),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  _label('Atención:', d['clientContact']),
                  _label('Teléfonos de Contacto:', d['clientPhone']),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 18),
      ],
    ),
  );
}

// Small continuation rows preserve long descriptions/serials across A4 pages
// without repeating quantities or amounts.
List<String> _chunks(String text) {
  final chunks = <String>[];
  while (text.length > 650) {
    final boundary = text.lastIndexOf(RegExp(r'\s'), 650);
    final end = boundary > 325 ? boundary : 650;
    chunks.add(text.substring(0, end));
    text = text.substring(end).trimLeft();
  }
  return [...chunks, text];
}

pw.Widget _table(List<Json> lines, bool budget) {
  final rows = <pw.TableRow>[];
  pw.Widget cell(
    String text,
    int column, {
    bool header = false,
    bool empty = false,
  }) => pw.Container(
    constraints: pw.BoxConstraints(minHeight: empty ? 28 : 22),
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
    alignment: column == 0 || column == 2
        ? pw.Alignment.topCenter
        : column >= 3
        ? pw.Alignment.topRight
        : pw.Alignment.topLeft,
    child: pw.Text(
      text,
      textAlign: column >= 3 ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontSize: 8,
        color: header ? PdfColors.grey600 : PdfColors.black,
        fontWeight: header || column == 4
            ? pw.FontWeight.bold
            : pw.FontWeight.normal,
      ),
    ),
  );
  final headers = [
    budget ? 'Ítem N°' : '#',
    'Descripción',
    'Cant.',
    'Precio Unit.',
    budget ? 'Total Bs' : 'Total.',
  ];
  rows.add(
    pw.TableRow(
      repeat: true,
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: .8)),
      ),
      children: List.generate(5, (i) => cell(headers[i], i, header: true)),
    ),
  );
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final serials = (line['serials'] as List? ?? []).map(_text).join(', ');
    final description = documentLineDescription(line, budget: budget);
    final parts = _chunks(
      '$description${serials.isEmpty ? '' : '\nSeriales: $serials'}',
    );
    for (var part = 0; part < parts.length; part++) {
      final values = [
        part == 0 ? '${i + 1}' : '',
        parts[part],
        part == 0 ? _text(line['quantity']) : '',
        part == 0 ? _amount(line['unitPrice'], budget) : '',
        part == 0 ? _amount(line['lineTotal'], budget) : '',
      ];
      rows.add(
        pw.TableRow(children: List.generate(5, (c) => cell(values[c], c))),
      );
    }
  }
  for (var i = 0; i < math.max(0, 8 - lines.length); i++) {
    rows.add(
      pw.TableRow(children: List.generate(5, (c) => cell('', c, empty: true))),
    );
  }
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey500, width: .5),
    columnWidths: {
      0: pw.FlexColumnWidth(budget ? 8 : 5),
      1: pw.FlexColumnWidth(budget ? 52 : 55),
      2: const pw.FlexColumnWidth(10),
      3: const pw.FlexColumnWidth(15),
      4: const pw.FlexColumnWidth(15),
    },
    children: rows,
  );
}

pw.Widget _observations(String value, {required bool budget}) => pw.Container(
  width: double.infinity,
  constraints: const pw.BoxConstraints(minHeight: 42),
  padding: const pw.EdgeInsets.all(7),
  decoration: pw.BoxDecoration(border: pw.Border.all(width: .7)),
  child: budget
      ? _label('Observaciones:', value)
      : pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Observaciones:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(value),
          ],
        ),
);

pw.Widget _totals(Json d, bool budget) {
  pw.Widget row(String label, Object? value, {bool total = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                label,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontWeight: total ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Text(
              _amount(value, budget),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );
  return pw.Column(
    children: [
      row(budget ? 'Sub-Total' : 'SUB-TOTAL', d['subtotal']),
      if (d['applyIVA'] != false) row('IVA', d['ivaAmount']),
      pw.Divider(thickness: 1),
      row(budget ? 'TOTAL NETO Bs.' : 'TOTAL NETO', d['total'], total: true),
    ],
  );
}

pw.Widget _signatures(Json d) {
  pw.Widget signature(String label, Object? name) => pw.Expanded(
    child: pw.Column(
      children: [
        pw.Container(
          constraints: const pw.BoxConstraints(minHeight: 18),
          child: pw.Text(_text(name)),
        ),
        pw.Divider(thickness: .6),
        pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
  return pw.Column(
    children: [
      pw.SizedBox(height: 24),
      pw.Row(
        children: [
          signature('Entregado por', d['deliveredBy']),
          pw.SizedBox(width: 24),
          signature('Recibido conforme', d['receivedBy']),
        ],
      ),
    ],
  );
}

Future<Uint8List> buildCommercialPdf(Json d, {required bool budget}) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
  );
  final logo = pw.MemoryImage(
    (await rootBundle.load('assets/branding/sumisistemas.jpg')).buffer
        .asUint8List(),
  );
  final pdf = pw.Document(
    title:
        '${budget ? 'Presupuesto' : 'Nota de entrega'} ${d[budget ? 'budgetNumber' : 'noteNumber']}',
    theme: pw.ThemeData.withFont(
      base: regular,
      bold: bold,
    ).copyWith(defaultTextStyle: const pw.TextStyle(fontSize: 8)),
  );
  final observations = _chunks(_text(d['observations']));
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: budget
          ? const pw.EdgeInsets.fromLTRB(54, 54, 54, 40)
          : const pw.EdgeInsets.fromLTRB(26, 9, 26, 36),
      maxPages: 200,
      header: (_) => _header(d, logo, budget),
      footer: (context) => context.pagesCount > 1
          ? pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
            )
          : pw.SizedBox(),
      build: (_) => [
        _table((d['lines'] as List? ?? []).cast<Json>(), budget),
        pw.SizedBox(height: 14),
        if (budget && observations.length == 1)
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: _observations(observations.first, budget: true),
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(flex: 2, child: _totals(d, budget)),
            ],
          )
        else ...[
          for (final part in observations) _observations(part, budget: budget),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: budget ? 190 : 186,
              child: _totals(d, budget),
            ),
          ),
        ],
        if (!budget) _signatures(d),
      ],
    ),
  );
  return pdf.save();
}
