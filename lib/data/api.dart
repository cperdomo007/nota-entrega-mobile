import 'package:dio/dio.dart';

import '../core/config.dart';
import '../core/session.dart';
import '../domain/models.dart';

class Api {
  final Dio dio;
  Api(Session session, {Dio? client, String baseUrl = AppConfig.apiUrl})
    : dio =
          client ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              followRedirects: false,
            ),
          ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (!AppConfig.isHttps(options.uri.toString().split('?').first) ||
              options.uri.origin != Uri.parse(baseUrl).origin ||
              session.accessToken == null) {
            return handler.reject(
              DioException(
                requestOptions: options,
                error: 'Configuración o sesión inválida',
              ),
            );
          }
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            try {
              await session.signOut();
            } catch (_) {
              /* Session already cleared in memory. */
            }
          }
          handler.next(error);
        },
      ),
    );
  }
  Future<Json> get(String path, [Json? query]) async =>
      (await dio.get<Json>(path, queryParameters: query)).data!;
  Future<List<Json>> list(String path, String search, int offset) async =>
      ((await get(path, {'q': search, 'limit': 50, 'offset': offset}))['items']
              as List)
          .cast<Json>();
  Future<DeliveryNote> note(int id) async =>
      DeliveryNote(await get('notes/$id'));
  Future<Budget> budget(int id) async => Budget(await get('budgets/$id'));
  Future<int> create(Json draft, String idempotencyKey) async =>
      (await dio.post<Json>(
            'notes',
            data: draft,
            options: Options(headers: {'Idempotency-Key': idempotencyKey}),
          )).data!['id']
          as int;
}
