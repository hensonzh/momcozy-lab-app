import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/shared/zoned_time.dart';

void main() {
  test('appointment zone labels read as places without changing zone IDs', () {
    expect(displayTimeZone('America/Los_Angeles'), 'Los Angeles time');
    expect(
      displayTimeZone('America/Indiana/Indianapolis'),
      'Indianapolis time',
    );
    expect(displayTimeZone('Asia/Shanghai'), 'Shanghai time');
    expect(displayTimeZone('UTC'), 'UTC');
    expect(displayTimeZone('Etc/GMT+5'), 'Etc/GMT+5');
  });
}
