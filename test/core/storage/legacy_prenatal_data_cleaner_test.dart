import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/storage/legacy_prenatal_data_cleaner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final values = <String, String>{};

  setUp(() {
    values
      ..clear()
      ..addAll({
        'momcozy.hospital-bag-cart.v1.user.alice.cart': '{"old":true}',
        'momcozy.hospital-bag-cart.v1.user.bob.cart': '{"old":true}',
        'momcozy.session.v1': '{"access":"keep"}',
      });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final arguments = Map<String, Object?>.from(call.arguments as Map);
          return switch (call.method) {
            'readAll' => Map<String, String>.of(values),
            'delete' => values.remove(arguments['key']),
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('deletes only obsolete prenatal keys and is idempotent', () async {
    const cleaner = LegacyPrenatalDataCleaner();

    expect(await cleaner.clean(), 2);
    expect(values, {'momcozy.session.v1': '{"access":"keep"}'});
    expect(await cleaner.clean(), 0);
  });
}
