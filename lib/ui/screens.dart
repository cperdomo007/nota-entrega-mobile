import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../main.dart';
import '../data/note_pdf.dart';
import '../domain/models.dart';
import 'scanner.dart';

void showError(BuildContext context, [String? message]) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message ?? 'No se pudo completar la operación. Revisa la conexión y vuelve a intentar.',
        ),
      ),
    );

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false, visible = false;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy ||
        !ref.read(sessionProvider).configured ||
        !form.currentState!.validate()) {
      return;
    }
    setState(() => busy = true);
    try {
      await ref.read(sessionProvider).signIn(email.text, password.text);
    } catch (_) {
      if (mounted) {
        showError(
          context,
          'No se pudo acceder. Revisa correo, contraseña y conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: form,
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.receipt_long, size: 72),
                    const SizedBox(height: 24),
                    Text(
                      'Nota Entrega Mobile',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ingresa con tu cuenta para gestionar las notas de entrega.',
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: email,
                      enabled: !busy,
                      autofillHints: const [AutofillHints.username],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value != null &&
                              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(value.trim())
                          ? null
                          : 'Ingresa un correo válido',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: password,
                      enabled: !busy,
                      obscureText: !visible,
                      autofillHints: const [AutofillHints.password],
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => submit(),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: visible
                              ? 'Ocultar contraseña'
                              : 'Mostrar contraseña',
                          onPressed: () => setState(() => visible = !visible),
                          icon: Icon(
                            visible ? Icons.visibility_off : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Ingresa tu contraseña'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    if (!ref.read(sessionProvider).configured)
                      const Text(
                        'La conexión al servidor aún no está configurada.',
                      ),
                    FilledButton.icon(
                      onPressed: busy || !ref.read(sessionProvider).configured
                          ? null
                          : submit,
                      icon: const Icon(Icons.login),
                      label: Text(busy ? 'Accediendo…' : 'Iniciar sesión'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Solicita tu cuenta al administrador. No hay registro público.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late Future<Json> future;
  @override
  void initState() {
    super.initState();
    future = ref.read(apiProvider).get('dashboard');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Nota Entrega'),
      actions: [
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout),
          onPressed: () async {
            try {
              await ref.read(sessionProvider).signOut();
            } catch (_) {
              if (context.mounted) {
                showError(
                  context,
                  'La sesión se cerró. No se pudo limpiar el almacenamiento seguro.',
                );
              }
            }
          },
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Panel general',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        FutureBuilder<Json>(
          future: future,
          builder: (_, snapshot) {
            if (snapshot.hasError) {
              return ListTile(
                title: const Text('No se pudo cargar el resumen'),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => setState(
                    () => future = ref.read(apiProvider).get('dashboard'),
                  ),
                ),
              );
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final data = snapshot.data!;
            return Wrap(
              spacing: 8,
              children: [
                for (final entry in {
                  'Clientes': data['clients'],
                  'Productos': data['products'],
                  'Notas': data['notes'],
                }.entries)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('${entry.key}\n${entry.value}'),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        for (final entry in {
          'clients': 'Clientes',
          'products': 'Productos',
          'notes': 'Notas de entrega',
        }.entries)
          Card(
            child: ListTile(
              title: Text(entry.value),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/${entry.key}'),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.push('/notes/new'),
          icon: const Icon(Icons.add),
          label: const Text('Crear nota de entrega'),
        ),
      ],
    ),
  );
}

class CatalogScreen extends ConsumerStatefulWidget {
  final String kind;
  const CatalogScreen({super.key, required this.kind});
  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final search = TextEditingController();
  List<Json> items = [];
  bool busy = false, more = true;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool reset = false}) async {
    final request = ++generation;
    final offset = reset ? 0 : items.length;
    setState(() {
      busy = true;
      error = null;
      if (reset) items = [];
    });
    try {
      final page = await ref
          .read(apiProvider)
          .list(widget.kind, search.text.trim(), offset);
      if (!mounted || request != generation) return;
      setState(() {
        items = [...items, ...page];
        more = page.length == 50;
      });
    } catch (_) {
      if (mounted && request == generation) {
        setState(() => error = 'No se pudo cargar el listado');
      }
    } finally {
      if (mounted && request == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        {
          'clients': 'Clientes',
          'products': 'Productos',
          'notes': 'Notas de entrega',
        }[widget.kind]!,
      ),
    ),
    floatingActionButton: widget.kind == 'notes'
        ? FloatingActionButton(
            onPressed: () async {
              await context.push('/notes/new');
              if (mounted) load(reset: true);
            },
            child: const Icon(Icons.add),
          )
        : null,
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => load(reset: true),
            decoration: InputDecoration(
              labelText: 'Buscar',
              border: const OutlineInputBorder(),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.kind == 'products')
                    IconButton(
                      tooltip: 'Escanear código',
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () async {
                        final code = await scan(context);
                        if (code != null && mounted) {
                          search.text = code;
                          load(reset: true);
                        }
                      },
                    ),
                  IconButton(
                    tooltip: 'Buscar',
                    icon: const Icon(Icons.search),
                    onPressed: () => load(reset: true),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          ListTile(
            title: Text(error!),
            trailing: TextButton(
              onPressed: () => load(reset: items.isEmpty),
              child: const Text('Reintentar'),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => load(reset: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (!busy && error == null && items.isEmpty)
                  const ListTile(title: Text('Sin resultados')),
                for (final item in items)
                  ListTile(
                    title: Text('${item['name'] ?? item['noteNumber']}'),
                    subtitle: Text(
                      widget.kind == 'notes'
                          ? '${item['clientName']} · ${item['noteDate']} · ${item['total']}'
                          : widget.kind == 'clients'
                          ? '${item['rif'] ?? ''} · ${item['phone'] ?? ''}'
                          : '${item['barcode'] ?? ''} · ${item['price']} / ${item['unit'] ?? 'UN'}',
                    ),
                    onTap: widget.kind == 'notes'
                        ? () async {
                            await context.push('/notes/${item['id']}');
                            if (mounted) load(reset: true);
                          }
                        : null,
                  ),
                if (more && items.isNotEmpty)
                  TextButton(
                    onPressed: busy ? null : load,
                    child: const Text('Cargar más'),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class NoteScreen extends ConsumerStatefulWidget {
  final int id;
  const NoteScreen({super.key, required this.id});
  @override
  ConsumerState<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends ConsumerState<NoteScreen> {
  late Future<DeliveryNote> future;
  bool sharing = false;
  @override
  void initState() {
    super.initState();
    future = ref.read(apiProvider).note(widget.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalle de nota')),
    body: FutureBuilder<DeliveryNote>(
      future: future,
      builder: (_, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(
                () => future = ref.read(apiProvider).note(widget.id),
              ),
              child: const Text('No se pudo cargar. Reintentar'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final note = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              note.number,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(note.client),
            Text('${note.data['noteDate']}'),
            Text('${note.data['clientRif'] ?? ''}'),
            Text('${note.data['clientAddress'] ?? ''}'),
            const Divider(),
            for (final line in note.lines)
              ListTile(
                title: Text(
                  '${line['productName'] ?? line['productId']} × ${line['quantity']}',
                ),
                subtitle: Text(
                  'Precio: ${line['unitPrice']}\nSeriales: ${(line['serials'] as List? ?? []).join(', ')}',
                ),
                trailing: Text('${line['lineTotal']}'),
              ),
            Text('Subtotal: ${note.data['subtotal']}'),
            Text('IVA: ${note.data['ivaAmount']}'),
            Text(
              'Total: ${note.data['total']}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('Observaciones: ${note.data['observations'] ?? ''}'),
            Text('Entregado por: ${note.data['deliveredBy'] ?? ''}'),
            Text('Recibido por: ${note.data['receivedBy'] ?? ''}'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: sharing
                  ? null
                  : () async {
                      setState(() => sharing = true);
                      try {
                        await Printing.sharePdf(
                          bytes: await buildNotePdf(note),
                          filename: 'nota-${note.id}.pdf',
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

class CreateNoteScreen extends ConsumerStatefulWidget {
  const CreateNoteScreen({super.key});
  @override
  ConsumerState<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends ConsumerState<CreateNoteScreen> {
  final number = TextEditingController(),
      observations = TextEditingController();
  final delivered = TextEditingController(), received = TextEditingController();
  final lines = <DraftLine>[];
  Client? client;
  DateTime date = DateTime.now();
  bool applyIva = true, busy = false;
  int rateBps = 1600;
  late Future<void> setup;
  final key = List.generate(
    24,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  @override
  void initState() {
    super.initState();
    setup = initialize();
  }

  Future<void> initialize() async {
    final api = ref.read(apiProvider);
    final config = await api.get('config');
    final next = await api.get('notes/next-number');
    rateBps = cents(config['ivaRate'] ?? '16.00');
    number.text = next['noteNumber'] as String;
  }

  @override
  void dispose() {
    for (final c in [number, observations, delivered, received]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> addLine() async {
    final raw = await pickEntity(context, ref, 'products');
    if (raw == null || !mounted) return;
    final product = Product.fromJson(raw);
    final line = await showDialog<DraftLine>(
      context: context,
      builder: (_) => LineDialog(product: product),
    );
    if (line != null && mounted) setState(() => lines.add(line));
  }

  Future<void> save() async {
    final error = validateLines(lines);
    if (client == null || number.text.trim().isEmpty || error != null) {
      showError(context, error ?? 'Selecciona un cliente y un número de nota');
      return;
    }
    setState(() => busy = true);
    try {
      final c = client!;
      final id = await ref.read(apiProvider).create({
        'noteNumber': number.text.trim(),
        'noteDate': date.toIso8601String().substring(0, 10),
        'clientName': c.name,
        'clientRif': c.rif,
        'clientAddress': c.address,
        'clientPhone': c.phone,
        'clientContact': c.contact,
        'applyIVA': applyIva,
        'ivaRate': money(rateBps),
        'observations': observations.text.trim(),
        'deliveredBy': delivered.text.trim(),
        'receivedBy': received.text.trim(),
        'lines': lines.map((l) => l.toJson()).toList(),
      }, key);
      if (mounted) context.pushReplacement('/notes/$id');
    } catch (_) {
      if (mounted) {
        showError(
          context,
          'No se pudo confirmar la nota. Reintenta sin cambiar el formulario; no se enviará duplicada.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nueva nota')),
    body: FutureBuilder<void>(
      future: setup,
      builder: (_, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => setup = initialize()),
              child: const Text(
                'No se pudo cargar la configuración. Reintentar',
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final subtotal = lines.fold(0, (sum, line) => sum + line.total);
        final iva = applyIva ? (subtotal * rateBps / 10000).round() : 0;
        return AbsorbPointer(
          absorbing: busy,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: number,
                decoration: const InputDecoration(labelText: 'Número de nota'),
              ),
              ListTile(
                title: Text(
                  'Fecha: ${date.toIso8601String().substring(0, 10)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (selected != null && mounted) {
                    setState(() => date = selected);
                  }
                },
              ),
              ListTile(
                title: Text(client?.name ?? 'Seleccionar cliente'),
                subtitle: Text(client?.rif ?? ''),
                trailing: const Icon(Icons.person_search),
                onTap: () async {
                  final raw = await pickEntity(context, ref, 'clients');
                  if (raw != null && mounted) {
                    setState(() => client = Client.fromJson(raw));
                  }
                },
              ),
              const Divider(),
              for (var i = 0; i < lines.length; i++)
                ListTile(
                  title: Text(
                    '${lines[i].product.name} × ${lines[i].quantity}',
                  ),
                  subtitle: Text(
                    '${money(lines[i].total)} · ${lines[i].serials.join(', ')}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Quitar producto',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => lines.removeAt(i)),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: addLine,
                icon: const Icon(Icons.add),
                label: const Text('Agregar producto'),
              ),
              SwitchListTile(
                title: Text('Aplicar IVA (${money(rateBps)} %)'),
                value: applyIva,
                onChanged: (value) => setState(() => applyIva = value),
              ),
              Text(
                'Subtotal: ${money(subtotal)}\nIVA: ${money(iva)}\nTotal estimado: ${money(subtotal + iva)}',
              ),
              TextField(
                controller: observations,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Observaciones'),
              ),
              TextField(
                controller: delivered,
                decoration: const InputDecoration(labelText: 'Entregado por'),
              ),
              TextField(
                controller: received,
                decoration: const InputDecoration(labelText: 'Recibido por'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: save,
                child: Text(busy ? 'Guardando…' : 'Crear nota'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<Json?> pickEntity(BuildContext context, WidgetRef ref, String kind) =>
    Navigator.push<Json>(
      context,
      MaterialPageRoute(builder: (_) => EntityPicker(kind: kind)),
    );

class EntityPicker extends ConsumerStatefulWidget {
  final String kind;
  const EntityPicker({super.key, required this.kind});
  @override
  ConsumerState<EntityPicker> createState() => _EntityPickerState();
}

class _EntityPickerState extends ConsumerState<EntityPicker> {
  final query = TextEditingController();
  List<Json> items = [];
  bool busy = false, more = true;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load(true);
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> load(bool reset) async {
    final request = ++generation;
    setState(() {
      busy = true;
      error = null;
      if (reset) items = [];
    });
    try {
      final result = await ref
          .read(apiProvider)
          .list(widget.kind, query.text.trim(), items.length);
      if (mounted && request == generation) {
        setState(() {
          items.addAll(result);
          more = result.length == 50;
        });
      }
    } catch (_) {
      if (mounted && request == generation) {
        setState(() => error = 'No se pudo cargar. Reintenta la búsqueda.');
      }
    } finally {
      if (mounted && request == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Seleccionar')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: query,
            onSubmitted: (_) => load(true),
            decoration: InputDecoration(
              labelText: 'Buscar por nombre o código',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.kind == 'products')
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: 'Escanear producto',
                      onPressed: () async {
                        final code = await scan(context);
                        if (code != null && mounted) {
                          query.text = code;
                          load(true);
                        }
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Buscar',
                    onPressed: () => load(true),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null) Text(error!),
        Expanded(
          child: ListView(
            children: [
              if (!busy && error == null && items.isEmpty)
                const ListTile(title: Text('Sin resultados')),
              for (final item in items)
                ListTile(
                  title: Text('${item['name']}'),
                  subtitle: Text('${item['rif'] ?? item['barcode'] ?? ''}'),
                  onTap: () => Navigator.pop(context, item),
                ),
              if (more && items.isNotEmpty)
                TextButton(
                  onPressed: busy ? null : () => load(false),
                  child: const Text('Cargar más'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class LineDialog extends StatefulWidget {
  final Product product;
  const LineDialog({super.key, required this.product});
  @override
  State<LineDialog> createState() => _LineDialogState();
}

class _LineDialogState extends State<LineDialog> {
  final quantity = TextEditingController(text: '1'),
      serial = TextEditingController();
  late final price = TextEditingController(
    text: money(widget.product.priceCents),
  );
  final serials = <String>[];
  String? error;
  @override
  void dispose() {
    quantity.dispose();
    serial.dispose();
    price.dispose();
    super.dispose();
  }

  void addSerial(String value) {
    value = value.trim();
    if (value.isEmpty || value.length > 255 || serials.contains(value)) {
      setState(() => error = 'Serial vacío, demasiado largo o duplicado');
      return;
    }
    setState(() {
      serials.add(value);
      serial.clear();
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.product.name),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad entera'),
            ),
            TextField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Precio unitario'),
            ),
            TextField(
              controller: serial,
              onSubmitted: addSerial,
              decoration: InputDecoration(
                labelText: 'Serial',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Agregar serial',
                  onPressed: () => addSerial(serial.text),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final value = await scan(context);
                if (value != null && mounted) addSerial(value);
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear serial'),
            ),
            for (final value in serials.toList())
              InputChip(
                label: Text(value),
                onDeleted: () => setState(() => serials.remove(value)),
              ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          try {
            final q = int.tryParse(quantity.text) ?? 0;
            final line = DraftLine(
              widget.product,
              q,
              cents(price.text.trim().replaceAll(',', '.')),
              serials,
            );
            final message = validateLines([line]);
            if (message != null) {
              setState(() => error = message);
              return;
            }
            if (serial.text.trim().isNotEmpty) {
              setState(() => error = 'Agrega el serial pendiente con +');
              return;
            }
            Navigator.pop(context, line);
          } catch (_) {
            setState(() => error = 'Precio inválido (máximo dos decimales)');
          }
        },
        child: const Text('Agregar'),
      ),
    ],
  );
}
