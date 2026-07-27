import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/storage/user_scoped_storage_key.dart';

void main() {
  test('builds a stable encoded account-scoped storage key', () {
    expect(
      userScopedStorageKey('user/a', 'preferences.volumeUnit'),
      'momcozy.storageMigration.v1.user.user%2Fa.preferences.volumeUnit',
    );
  });
}
