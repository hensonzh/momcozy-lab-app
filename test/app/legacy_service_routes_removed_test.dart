import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/mom_module_routes.dart';

void main() {
  test('retired package, booking and consultation routes are absent', () {
    expect(
      momModuleRoutes.where((route) => route.path.startsWith('/services')),
      isEmpty,
    );
  });
}
