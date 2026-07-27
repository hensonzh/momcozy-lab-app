import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/agent_stream/agent_run_create_context.dart';
import 'package:app/core/agent_stream/agent_stream_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test.momcozy/agent_run_create_context');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('loads the current platform IANA timezone for every new run', () async {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls += 1;
          expect(call.method, 'localTimezone');
          return 'Asia/Shanghai';
        });
    final now = DateTime(2026, 7, 26, 16, 30);
    final provider = PlatformAgentRunCreateContextProvider(
      channel: channel,
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
  });

  test('rejects a platform timezone abbreviation', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => 'CST');
    final provider = PlatformAgentRunCreateContextProvider(channel: channel);

    await expectLater(
      provider.load(),
      throwsA(isA<AgentStreamPayloadException>()),
    );
  });
}
