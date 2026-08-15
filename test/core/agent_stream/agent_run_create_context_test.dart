import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_run_create_context.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';

void main() {
  test(
    'loads an IANA timezone and a local RFC 3339 message timestamp',
    () async {
      var calls = 0;
      final now = DateTime(2026, 7, 26, 16, 30);
      final provider = PlatformAgentRunCreateContextProvider(
        timezoneLoader: () async {
          calls += 1;
          return 'Asia/Shanghai';
        },
        now: () => now,
      );

      final first = await provider.load();
      final second = await provider.load();

      expect(first.timezone, 'Asia/Shanghai');
      expect(first.messageSentAt, formatRfc3339WithOffset(now));
      expect(
        first.messageSentAt,
        matches(RegExp(r'T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$')),
      );
      expect(second.timezone, 'Asia/Shanghai');
      expect(calls, 2);
    },
  );

  test('rejects a timezone abbreviation at the Agent boundary', () async {
    final provider = PlatformAgentRunCreateContextProvider(
      timezoneLoader: () async => 'CST',
    );

    await expectLater(
      provider.load(),
      throwsA(isA<AgentStreamPayloadException>()),
    );
  });
}
