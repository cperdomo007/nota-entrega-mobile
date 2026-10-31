import 'package:dio/dio.dart';

String saveError(Object error, String fallback) {
  final data = error is DioException ? error.response?.data : null;
  final code = data is Map ? data['code'] : null;
  return switch (code) {
    'DOCUMENT_NUMBER_EXISTS' => 'Ya existe un documento de este tipo en este minuto. Espera al siguiente minuto y vuelve a guardar.',
    'CATALOG_DUPLICATE' => 'Ya existe un cliente con ese RIF o un producto con ese código. Revisa el listado.',
    _ => fallback,
  };
}
