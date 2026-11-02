import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nota_entrega_mobile/core/session.dart';
import 'package:nota_entrega_mobile/data/api.dart';

class FakeSession extends Session {
  bool active = true;
  @override
  String? get accessToken => active ? 'test-token' : null;
  @override
  Future<void> signOut() async {
    active = false;
  }
}

class Adapter implements HttpClientAdapter {
  RequestOptions? request;
  int status = 200;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      '{"items":[]}',
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
  late FakeSession session;
  late Adapter adapter;
  late Api api;
  setUp(() {
    session = FakeSession();
    adapter = Adapter();
    api = Api(session, baseUrl: 'https://api.example.com/v1/');
    api.dio.httpClientAdapter = adapter;
  });
  test('adjunta Bearer y parámetros de búsqueda/paginación', () async {
    await api.list('clients', 'José', 50);
    expect(adapter.request!.headers['Authorization'], 'Bearer test-token');
    expect(adapter.request!.queryParameters, {
      'q': 'José',
      'limit': 50,
      'offset': 50,
    });
  });
  test('rechaza otro host antes de transmitir credenciales', () async {
    await expectLater(
      api.get('https://evil.example.com/steal'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.request, isNull);
  });
  test('rechaza HTTP antes de enviar', () async {
    await expectLater(
      api.get('http://api.example.com/v1/clients'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.request, isNull);
  });
  test('401 invalida sesión sin repetir la petición', () async {
    adapter.status = 401;
    await expectLater(api.list('notes', '', 0), throwsA(isA<DioException>()));
    expect(session.active, isFalse);
  });
  test('sesión ausente impide consultas', () async {
    session.active = false;
    await expectLater(api.list('clients', '', 0), throwsA(isA<DioException>()));
    expect(adapter.request, isNull);
  });
}
