import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/mom_bottom_navigation.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_hub_greeting.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/shared/design_system/mom_home_tokens.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

Future<void> verifyAgentConversation(
  WidgetTester tester, {
  required double scale,
  required Future<void> Function(String) capture,
}) async {
  final client = _ConversationClient();
  addTearDown(client.dispose);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: momCozyTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SafeArea(
          child: AgentHubPage(
            runner: AgentStreamRunner(client),
            greetingProfileLoader: () async =>
                const AgentHubGreetingProfile(displayName: 'Mia', age: 30),
          ),
        ),
        bottomNavigationBar: const MomCozyBottomNavigation(location: '/'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final imageContext = tester.element(find.byType(Scaffold));
  final images = <ImageProvider>{
    const AssetImage(MomCozyAssets.agentAvatar),
    for (final image in tester.widgetList<Image>(find.byType(Image)))
      image.image,
  };
  await tester.runAsync(() async {
    await Future.wait(
      images.map((image) => precacheImage(image, imageContext)),
    );
  });
  await tester.pumpAndSettle();
  expect(client.requests, isEmpty);
  await capture('home');
  final input = find.byKey(const ValueKey('agent-composer-input'));
  final retry = find.byKey(const ValueKey('agent-retry-button'));
  final welcome = agentHubGreetingForProfile(
    const AgentHubGreetingProfile(displayName: 'Mia', age: 30),
  );
  Future<void> captureConversation(String state) async {
    final messages = tester
        .widget<AgentHubHistorySliver>(
          find.byType(AgentHubHistorySliver, skipOffstage: false),
        )
        .messages;
    expect(messages.first.role, AgentHubHistoryRole.assistant);
    expect(messages.first.content, welcome);
    expect(messages.first.runState, isNull);
    expect(
      messages.where((message) => message.content == welcome),
      hasLength(1),
    );
    expect(messages[1].role, AgentHubHistoryRole.user);
    expect(messages[1].content, 'This is a message for visual testing only.');
    await capture(state);
  }

  Future<void> frame() async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  }

  Future<void> send(String text) async {
    await tester.enterText(input, text);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('agent-send-button')));
    await frame();
  }

  Future<void> showRetry() async {
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
  }

  await send('This is a message for visual testing only.');
  expect(client.requests, hasLength(1));
  client.fail(0);
  await tester.pumpAndSettle();
  expect(
    tester.widget<TextField>(input).controller!.text,
    'This is a message for visual testing only.',
  );
  expect(
    find.byKey(const ValueKey('agent-run-failure-fallback')),
    findsOneWidget,
  );
  await showRetry();
  await captureConversation('disconnected-empty');
  await tester.tap(retry);
  await frame();
  expect(client.requests, hasLength(2));
  expect(client.requests[1].idempotencyKey, client.requests[0].idempotencyKey);
  expect(client.requests[1].runId, isNull);
  expect(tester.widget<TextField>(input).controller!.text, isEmpty);
  client.emit(1, 'run.started', 1, {});
  client.emit(1, 'message.delta', 2, {
    'text': 'This is a visual test reply, not a health assessment.',
  });
  await frame();
  await captureConversation('streaming');
  client.emit(1, 'message.completed', 3, {
    'text': 'This is a visual test reply, not a health assessment.',
  });
  client.emit(1, 'run.completed', 4, {});
  await tester.pumpAndSettle();
  expect(retry, findsNothing);
  await captureConversation('reply');
  await send('Check the input again after a failure.');
  expect(client.requests, hasLength(3));
  client.emit(2, 'run.failed', 1, {
    'code': 'runtime_error',
    'message': 'internal fixture secret',
  });
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('agent-run-failure-fallback')),
    findsOneWidget,
  );
  expect(find.textContaining('internal fixture secret'), findsNothing);
  expect(retry, findsNothing);
  expect(tester.widget<TextField>(input).enabled, isNot(false));
  expect(
    tester.widget<TextField>(input).controller!.text,
    'Check the input again after a failure.',
  );
  await captureConversation('terminal-error');
  await send('Continue checking recovery after disconnection.');
  expect(client.requests, hasLength(4));
  expect(client.requests.last.runId, isNull);
  client.emit(3, 'run.started', 1, {});
  client.emit(3, 'message.delta', 2, {
    'text': 'Keep the received reply visible.',
  });
  await frame();
  await tester.tap(input);
  await tester.pumpAndSettle();
  await tester.enterText(input, 'Another draft, not sent yet.');
  await frame();
  expect(
    tester.widget<TextField>(input).controller!.text,
    'Another draft, not sent yet.',
  );
  client.fail(3);
  await tester.pumpAndSettle();
  expect(
    tester.widget<TextField>(input).controller!.text,
    'Another draft, not sent yet.',
  );
  expect(
    find.descendant(
      of: find.byType(AgentRunTranscript).last,
      matching: find.byKey(const ValueKey('agent-run-failure-fallback')),
    ),
    findsNothing,
  );
  final partial = tester.widget<AgentMarkdownText>(
    find
        .descendant(
          of: find.byType(AgentRunTranscript),
          matching: find.byType(AgentMarkdownText),
        )
        .last,
  );
  expect(partial.style?.color, MomHomeTokens.ink);
  await showRetry();
  await captureConversation('disconnected-partial');
  await tester.tap(retry);
  await frame();
  expect(client.requests, hasLength(5));
  expect(client.requests.last.runId, 'conversation-run-3');
  expect(client.requests.last.afterSequence, 2);
  expect(
    tester.widget<TextField>(input).controller!.text,
    'Another draft, not sent yet.',
  );
  client.emit(4, 'message.completed', 3, {
    'text':
        'Keep the received reply visible. Show the full text after recovery.',
  }, run: 3);
  client.emit(4, 'run.completed', 4, {}, run: 3);
  await tester.pumpAndSettle();
  expect(retry, findsNothing);
  await captureConversation('resumed');
  expect(client.requests, hasLength(5));
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

class _ConversationClient implements AgentStreamClient {
  final requests = <AgentStreamRequest>[];
  final streams = <StreamController<AgentStreamEvent>>[];
  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) {
    requests.add(request);
    final stream = StreamController<AgentStreamEvent>();
    streams.add(stream);
    return stream.stream;
  }

  void fail(int index) => streams[index].addError(
    const AgentStreamConnectionException('SocketException: offline'),
  );
  void emit(
    int index,
    String type,
    int sequence,
    Map<String, Object?> payload, {
    int? run,
  }) => streams[index].add(
    AgentStreamEvent({
      'event_id': '$index-$sequence',
      'type': type,
      'thread_id': 'conversation-thread',
      'run_id': 'conversation-run-${run ?? index}',
      'message_id': 'conversation-message-${run ?? index}',
      'sequence': sequence,
      'payload': payload,
    }),
  );
  Future<void> dispose() async {
    for (final stream in streams) {
      await stream.close();
    }
  }
}
