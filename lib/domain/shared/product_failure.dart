enum ProductFailureKind {
  offline,
  unauthenticated,
  forbidden,
  conflict,
  invalid,
  unavailable,
}

class ProductFailure implements Exception {
  const ProductFailure(this.kind, {this.code});
  final ProductFailureKind kind;
  final String? code;
}
