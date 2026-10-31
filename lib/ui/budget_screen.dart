import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../data/commercial_pdf.dart';
import '../data/note_pdf.dart';
import '../domain/models.dart';
import '../main.dart';
import 'screens.dart' show showError;

class BudgetScreen extends ConsumerStatefulWidget {
  final int id;
  const BudgetScreen({super.key, required this.id});
  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  late Future<Budget> future;
  bool sharing = false;
  @override
  void initState() {
    super.initState();
    future = ref.read(apiProvider).budget(widget.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalle de presupuesto')),
    body: FutureBuilder<Budget>(
      future: future,
      builder: (_, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(
                () => future = ref.read(apiProvider).budget(widget.id),
              ),
              child: const Text('No se pudo cargar. Reintentar'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final budget = snapshot.data!;
        final data = budget.data;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              budget.number,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(budget.client),
            Text('${data['budgetDate']}'),
            Text('${data['clientRif'] ?? ''}'),
            Text('${data['clientAddress'] ?? ''}'),
            Text('Atención: ${data['clientContact'] ?? ''}'),
            const Divider(),
            for (final line in budget.lines)
              ListTile(
                title: Text(
                  '${documentLineDescription(line, budget: true)} × ${line['quantity']}',
                ),
                subtitle: Text('Precio: ${line['unitPrice']}'),
                trailing: Text('${line['lineTotal']}'),
              ),
            Text('Subtotal: ${data['subtotal']}'),
            if (data['applyIVA'] == true) Text('IVA: ${data['ivaAmount']}'),
            Text(
              'Total: ${data['total']}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('Observaciones: ${data['observations'] ?? ''}'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: sharing
                  ? null
                  : () async {
                      setState(() => sharing = true);
                      try {
                        await Printing.sharePdf(
                          bytes: await buildBudgetPdf(budget),
                          filename: 'presupuesto-${budget.id}.pdf',
                        );
                      } catch (_) {
                        if (context.mounted) {
                          showError(
                            context,
                            'No se pudo generar o compartir el PDF.',
                          );
                        }
                      } finally {
                        if (mounted) setState(() => sharing = false);
                      }
                    },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Generar y compartir PDF'),
            ),
          ],
        );
      },
    ),
  );
}
