import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/rif_document.dart';

const rifScannerChannel = MethodChannel('nota_entrega/rif_scanner');

Future<RifDocument?> readRif(BuildContext context) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.document_scanner_outlined),
            title: const Text('Escanear con cámara'),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Elegir imagen o PDF'),
            subtitle: const Text('Hasta 20 MB. Se lee la primera página.'),
            onTap: () => Navigator.pop(context, 'file'),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'La lectura se realiza en el dispositivo. El primer uso requiere Internet y Google Play Services para descargar las herramientas.',
            ),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;
  String? text;
  try {
    text = await rifScannerChannel.invokeMethod<String>(source);
  } on PlatformException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'FILE_TOO_LARGE'
                ? 'El archivo supera 20 MB. Elige un archivo más pequeño.'
                : 'No se pudo leer. Revisa Google Play Services y la conexión, o elige una imagen/PDF legible y sin contraseña. Puedes ingresar los datos manualmente.',
          ),
        ),
      );
    }
    return null;
  } on MissingPluginException {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El escaneo de RIF está disponible en Android. Puedes ingresar los datos manualmente.',
          ),
        ),
      );
    }
    return null;
  }
  if (text == null || !context.mounted) return null;
  final suggestion = RifDocument.parse(text);
  return showDialog<RifDocument>(
    context: context,
    builder: (_) => _ReviewRif(suggestion),
  );
}

class _ReviewRif extends StatefulWidget {
  final RifDocument suggestion;
  const _ReviewRif(this.suggestion);
  @override
  State<_ReviewRif> createState() => _ReviewRifState();
}

class _ReviewRifState extends State<_ReviewRif> {
  final form = GlobalKey<FormState>();
  late final rif = TextEditingController(text: widget.suggestion.rif);
  late final name = TextEditingController(text: widget.suggestion.name);
  late final address = TextEditingController(text: widget.suggestion.address);
  @override
  void dispose() {
    rif.dispose();
    name.dispose();
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Revisar datos del RIF'),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.suggestion.isEmpty
                  ? 'No se detectó un RIF completo. Puedes cancelar y volver a escanear, o completar los datos.'
                  : 'Revisa y corrige los datos detectados. Solo se reemplazarán los campos completados; todavía debes guardar el cliente.',
            ),
            TextFormField(
              controller: rif,
              maxLength: 50,
              decoration: const InputDecoration(labelText: 'RIF detectado'),
              validator: (value) =>
                  RegExp(
                    r'^[VEJPGC]-?\d{8}-?\d$',
                    caseSensitive: false,
                  ).hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Revisa el RIF: letra y nueve dígitos',
            ),
            TextFormField(
              controller: name,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Nombre o razón social detectado',
              ),
            ),
            TextFormField(
              controller: address,
              maxLength: 2000,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Dirección detectada',
              ),
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
          if (form.currentState!.validate()) {
            Navigator.pop(
              context,
              RifDocument(
                rif: rif.text.trim().toUpperCase(),
                name: name.text.trim(),
                address: address.text.trim(),
              ),
            );
          }
        },
        child: const Text('Aplicar al formulario'),
      ),
    ],
  );
}
