import 'package:flutter/foundation.dart';
import '../../../domain/care/care_order.dart';
import '../../../domain/care/service_package.dart';
import '../../../domain/shared/product_failure.dart';

class CareOverviewController extends ChangeNotifier {
  CareOverviewController(this.repository);
  final CareRepository repository;
  ServiceCatalog? catalog;
  CareOverview? overview;
  bool loading = true;
  ProductFailure? failure;
  bool _disposed = false;
  int _generation = 0;
  Future<void> load() async {
    final generation = ++_generation;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      final result = await Future.wait<Object>([
        repository.catalog(),
        repository.overview(),
      ]);
      if (_disposed || generation != _generation) return;
      catalog = result[0] as ServiceCatalog;
      overview = result[1] as CareOverview;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      failure = error is ProductFailure
          ? error
          : const ProductFailure(ProductFailureKind.unavailable);
    }
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
