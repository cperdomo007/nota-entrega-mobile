import 'package:flutter/services.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nota_entrega_mobile/main.dart';
import 'package:nota_entrega_mobile/core/session.dart';
import 'package:nota_entrega_mobile/data/api.dart';
import 'package:nota_entrega_mobile/ui/screens.dart';

class PreviewApi extends Api {
  PreviewApi()
    : super(Session(), baseUrl: 'https://preview.example.com/api/mobile/v1/');
  @override
  Future<Map<String, dynamic>> get(
    String path, [
    Map<String, dynamic>? query,
  ]) async {
    if (path == 'dashboard') {
      return {'clients': 29, 'products': 117, 'notes': 30};
    }
    return {
      'rates': {
        'bcv': {
          'id': 'bcv',
          'baseRate': '889.580000',
          'rate': '889.580000',
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
          'stale': false,
        },
        'binance': {
          'id': 'binance',
          'baseRate': '893.200000',
          'rate': '899.200000',
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
          'stale': false,
        },
      },
    };
  }
}

void main() {
  testWidgets(
    'dashboard retains navigation and renders complete exchange panel',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final fonts = FontLoader('Roboto')
        ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
      await fonts.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = PreviewApi(), key = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(api)],
          child: MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color(0xff176b61),
              fontFamily: 'Roboto',
            ),
            home: RepaintBoundary(key: key, child: const DashboardScreen()),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/branding/sumisistemas.jpg'),
          tester.element(find.byType(DashboardScreen)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Crear nota de entrega'), findsOneWidget);
      expect(find.text('Presupuestos'), findsOneWidget);
      expect(find.text('Tasas de cambio'), findsOneWidget);
      expect(find.text('89.920,00 Bs'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build').create(recursive: true);
        await File('build/exchange-preview.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      api.dio.close();
    },
  );
}
