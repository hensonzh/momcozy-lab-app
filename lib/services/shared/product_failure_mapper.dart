import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../../core/network/api_json_transport.dart';
import '../../domain/shared/product_failure.dart';

Future<T> withProductFailure<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } catch (error) {
    throw productFailure(error);
  }
}

ProductFailure productFailure(Object error) {
  if (error is ProductFailure) return error;
  if (error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException ||
      error is ApiRequestTimeoutException) {
    return const ProductFailure(ProductFailureKind.offline);
  }
  if (error is ApiHttpException) {
    return ProductFailure(switch (error.statusCode) {
      401 => ProductFailureKind.unauthenticated,
      403 => ProductFailureKind.forbidden,
      409 => ProductFailureKind.conflict,
      422 => ProductFailureKind.invalid,
      _ => ProductFailureKind.unavailable,
    }, code: error.errorCode);
  }
  return const ProductFailure(ProductFailureKind.unavailable);
}
