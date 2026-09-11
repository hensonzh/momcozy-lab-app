import 'product_failure.dart';

final class ResourceState<T> {
  const ResourceState({this.value, this.failure, this.loading = false});
  const ResourceState.loading([this.value]) : loading = true, failure = null;
  final T? value;
  final ProductFailure? failure;
  final bool loading;
  bool get hasValue => value != null;
}
