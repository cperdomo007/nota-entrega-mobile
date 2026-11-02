import 'package:dio/dio.dart';

String saveError(Object error, String fallback) {
  final data = error is DioException ? error.response?.data : null;
  final code = data is Map ? data['code'] : null;
  return switch (code) {
    'EDIT_CONFLICT' => 'Este registro cambió desde que lo abriste. Vuelve al listado y ábrelo de nuevo antes de editar.',
    'IVA_CHANGED' =>
      'La tasa de IVA cambió. Vuelve a abrir el documento antes de guardar.',
    'INVALID_LINES' => 'Revisa los productos, cantidades y seriales. Sustituye los productos que ya no existan.',
    'DOCUMENT_NUMBER_EXISTS' => 'Ya existe un documento de este tipo en este minuto. Espera al siguiente minuto y vuelve a guardar.',
    'CATALOG_DUPLICATE' => 'Ya existe un cliente con ese RIF o un producto con ese código. Revisa el listado.',
    _ => fallback,
  };
}
