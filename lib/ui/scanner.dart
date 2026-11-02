import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final controller = MobileScannerController();
  bool done = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escanear código')),
    body: MobileScanner(
      controller: controller,
      errorBuilder: (_, _) => const Center(
        child: Text(
          'No se pudo acceder a la cámara. Revisa el permiso o ingresa el código manualmente.',
        ),
      ),
      onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          final value = barcode.rawValue?.trim();
          if (!done && value != null && value.isNotEmpty) {
            done = true;
            Navigator.pop(context, value);
            break;
          }
        }
      },
    ),
  );
}

Future<String?> scan(BuildContext context) => Navigator.push<String>(
  context,
  MaterialPageRoute(builder: (_) => const ScannerScreen()),
);
