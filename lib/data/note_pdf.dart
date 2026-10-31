import 'package:flutter/services.dart';

import '../domain/models.dart';
import 'commercial_pdf.dart';

Future<Uint8List> buildNotePdf(DeliveryNote note) =>
    buildCommercialPdf(note.data, budget: false);

Future<Uint8List> buildBudgetPdf(Budget budget) =>
    buildCommercialPdf(budget.data, budget: true);
