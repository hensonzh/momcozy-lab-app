import 'package:flutter_test/flutter_test.dart';

void goldenTest(String description, WidgetTesterCallback callback) {
  testWidgets(description, callback, tags: const ['golden']);
}
