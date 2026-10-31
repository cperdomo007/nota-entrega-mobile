import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_errors.dart';
import '../domain/models.dart';
import '../main.dart';

String creationKey() => List.generate(
  24,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

class EntityCreateScreen extends ConsumerStatefulWidget {
  final String kind;
  const EntityCreateScreen({super.key, required this.kind});
  @override
  ConsumerState<EntityCreateScreen> createState() => _EntityCreateScreenState();
}

class _EntityCreateScreenState extends ConsumerState<EntityCreateScreen> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  final key = creationKey();
  bool serial = false, busy = false;
  String? error;
  bool get product => widget.kind == 'products';
  TextEditingController field(String name) => fields.putIfAbsent(
    name,
    () => TextEditingController(
      text: name == 'unit'
          ? 'UN'
          : name == 'stock'
          ? '0'
          : '',
    ),
  );
  String value(String name) => field(name).text.trim();
  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final data = <String, dynamic>{
      'name': value('name'),
      if (product) ...{
        'barcode': value('barcode'),
        'description': value('description'),
        'category': value('category'),
        'price': money(cents(value('price').replaceAll(',', '.'))),
        'unit': value('unit'),
        'stock': int.parse(value('stock')),
        'hasSerial': serial,
      } else ...{
        'rif': value('rif'),
        'address': value('address'),
        'phone': value('phone'),
        'email': value('email'),
        'contact': value('contact'),
      },
    };
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final id = await ref
          .read(apiProvider)
          .createEntity(widget.kind, data, key);
      if (mounted) Navigator.pop(context, {...data, 'id': id});
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = saveError(
            failure,
            'No se pudo confirmar. Reintenta sin cambiar los datos; no se enviará duplicado.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget input(
    String name,
    String label,
    int max, {
    bool required = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: field(name),
      maxLength: max,
      maxLines: lines,
      keyboardType: ['price', 'stock'].contains(name)
          ? const TextInputType.numberWithOptions(decimal: true)
          : name == 'email'
          ? TextInputType.emailAddress
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (raw) {
        final text = raw?.trim() ?? '';
        if (required && text.isEmpty) return 'Campo obligatorio';
        if (name == 'price') {
          try {
            final amount = cents(text.replaceAll(',', '.'));
            if (amount <= 0 || amount > 9999999999) {
              return 'Precio mayor que cero, máximo 99999999.99';
            }
          } catch (_) {
            return 'Precio inválido; máximo dos decimales';
          }
        }
        if (name == 'stock' &&
            (int.tryParse(text) == null ||
                int.parse(text) < 0 ||
                int.parse(text) > 2147483647)) {
          return 'Existencia entera no negativa';
        }
        if (name == 'email' &&
            text.isNotEmpty &&
            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
          return 'Correo inválido';
        }
        return null;
      },
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(product ? 'Nuevo producto' : 'Nuevo cliente')),
    body: AbsorbPointer(
      absorbing: busy,
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            input(
              'name',
              product ? 'Nombre del producto' : 'Nombre o razón social',
              500,
              required: true,
            ),
            if (product) ...[
              input('barcode', 'Código de producto (opcional)', 255),
              input('description', 'Descripción', 4000, lines: 3),
              input('category', 'Categoría', 100),
              input('price', 'Precio', 11, required: true),
              input('unit', 'Unidad', 50, required: true),
              input('stock', 'Existencia inicial', 10, required: true),
              SwitchListTile(
                title: const Text('Requiere serial por unidad'),
                value: serial,
                onChanged: (value) => setState(() => serial = value),
              ),
            ] else ...[
              input('rif', 'RIF', 50),
              input('address', 'Dirección', 2000, lines: 3),
              input('phone', 'Teléfono', 20),
              input('email', 'Correo', 255),
              input('contact', 'Contacto', 100),
            ],
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(
                busy
                    ? 'Guardando…'
                    : product
                    ? 'Guardar producto'
                    : 'Guardar cliente',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
