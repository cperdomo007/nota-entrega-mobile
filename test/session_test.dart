import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nota_entrega_mobile/core/session.dart';
import 'package:nota_entrega_mobile/main.dart';
import 'package:nota_entrega_mobile/ui/screens.dart';

class AuthAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  String access = 'A' * 43, refresh = 'R' * 43;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'accessToken': access,
        'refreshToken': refresh,
        'user': {
          'id': 1,
          'email': 'admin@example.com',
          'name': 'Admin',
          'role': 'admin',
        },
      }),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AuthAdapter adapter;
  late Session session;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    adapter = AuthAdapter();
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.example.com/api/mobile/v1/',
        followRedirects: false,
      ),
    );
    dio.httpClientAdapter = adapter;
    session = Session(client: dio, baseUrl: dio.options.baseUrl);
  });
  test('login usa correo normalizado y guarda solo refresh token', () async {
    await session.signIn(' ADMIN@EXAMPLE.COM ', 'private-test-password');
    expect(session.signedIn, isTrue);
    expect(session.user!['role'], 'admin');
    expect((adapter.requests.single.data as Map)['email'], 'admin@example.com');
    final saved = await session.storage.readAll();
    expect(saved.values, [adapter.refresh]);
    expect(saved.values.contains(adapter.access), isFalse);
    expect(saved.values.contains('private-test-password'), isFalse);
  });
  test('restore rota credenciales y logout revoca la sesión', () async {
    await session.signIn('admin@example.com', 'test-password');
    adapter.refresh = 'S' * 43;
    await session.restore();
    expect(adapter.requests.last.path, 'auth/refresh');
    expect((adapter.requests.last.data as Map)['refreshToken'], 'R' * 43);
    expect((await session.storage.readAll()).values, ['S' * 43]);
    await session.signOut();
    expect(session.signedIn, isFalse);
    expect(adapter.requests.last.path, 'auth/logout');
    expect((adapter.requests.last.data as Map)['refreshToken'], 'S' * 43);
    expect(await session.storage.readAll(), isEmpty);
  });
  test('fallo de refresh elimina la sesión persistida', () async {
    await session.signIn('admin@example.com', 'test-password');
    adapter.status = 401;
    await session.restore();
    expect(session.signedIn, isFalse);
    expect(await session.storage.readAll(), isEmpty);
  });
  test('rechaza una respuesta de autenticación inválida', () async {
    adapter.access = 'invalid';
    await expectLater(
      session.signIn('admin@example.com', 'test-password'),
      throwsFormatException,
    );
    expect(session.signedIn, isFalse);
    expect(await session.storage.readAll(), isEmpty);
  });
  testWidgets('formulario valida correo y oculta contraseña', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWithValue(session)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa un correo válido'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
    expect(adapter.requests, isEmpty);
    final editor = tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Contraseña'),
        matching: find.byType(EditableText),
      ),
    );
    expect(editor.obscureText, isTrue);
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
  });
  testWidgets(
    'credenciales rechazadas vacían ambos campos y ocultan la contraseña',
    (tester) async {
      adapter.status = 401;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionProvider.overrideWithValue(session)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo electrónico'),
        'wrong@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'wrong-password',
      );
      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Correo electrónico'),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Contraseña'),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(
        find.text('Usuario o contraseña incorrectos. Vuelve a intentarlo.'),
        findsOneWidget,
      );
      expect(find.byTooltip('Mostrar contraseña'), findsOneWidget);
      expect(session.signedIn, false);
    },
  );
  testWidgets(
    'fallo de conexión no se presenta como credenciales incorrectas',
    (tester) async {
      adapter.status = 503;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionProvider.overrideWithValue(session)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo electrónico'),
        'user@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'test-password',
      );
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Correo electrónico'),
            )
            .controller!
            .text,
        'user@example.com',
      );
      expect(
        find.text(
          'No se pudo acceder. Revisa la conexión y vuelve a intentarlo.',
        ),
        findsOneWidget,
      );
    },
  );
}
