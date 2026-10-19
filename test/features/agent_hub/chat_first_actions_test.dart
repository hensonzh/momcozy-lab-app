import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_document_input.dart';
import 'package:momcozy_flutter_app/features/media/domain/media_upload.dart';

void main() {
  for (final scenario in <String, String>{
    'photo': '图片上传失败，请重试。',
    'file': '文件上传失败，请重试。',
    'too-large': '文件不能超过 10 MB。',
    'unsupported': '目前仅支持 PDF 文件。',
  }.entries) {
    testWidgets('chat-first ${scenario.key} failure keeps honest copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentHubPage(
              chatFirstExperience: true,
              mediaRepository: _NoUploadMedia(),
              pickImage: (_) async => throw StateError('private picker detail'),
              pickDocument: () async => switch (scenario.key) {
                'too-large' => throw const AgentDocumentInputException(
                  'file_too_large',
                ),
                'unsupported' => throw const AgentDocumentInputException(
                  'unsupported_file_type',
                ),
                _ => throw StateError('private picker detail'),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (scenario.key == 'photo') {
        await tester.enterText(
          find.byKey(const ValueKey('agent-composer-input')),
          '保留的草稿',
        );
        await tester.tap(find.byKey(const ValueKey('chat-first-camera')));
      } else {
        await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('agent-attachment-menu')),
          findsOneWidget,
        );
        final audio = find.byKey(
          const ValueKey('agent-attachment-audio-button'),
        );
        expect(audio, findsOneWidget);
        expect(tester.widget<MenuItemButton>(audio).onPressed, isNull);
        await tester.tap(
          find.byKey(const ValueKey('agent-attachment-file-button')),
        );
      }
      await tester.pumpAndSettle();
      expect(find.text(scenario.value), findsOneWidget);
      expect(find.textContaining('private picker detail'), findsNothing);
      if (scenario.key == 'photo') {
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('agent-composer-input')),
              )
              .controller!
              .text,
          '保留的草稿',
        );
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'Demo four-slot attachment sheet stays usable on compact screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentHubPage(
              chatFirstExperience: true,
              mediaRepository: _NoUploadMedia(),
              pickImage: (_) async => null,
              pickDocument: () async => null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
      await tester.pumpAndSettle();
      final keys = ['camera', 'photo', 'file', 'audio']
          .map((kind) => find.byKey(ValueKey('agent-attachment-$kind-button')))
          .toList();
      for (final button in keys) {
        expect(button, findsOneWidget);
        final bounds = tester.getRect(button);
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(320));
      }
      expect(
        tester.getRect(keys.first).right,
        lessThan(tester.getRect(keys.last).left),
      );
      expect(tester.widget<MenuItemButton>(keys.last).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opening another record clears feedback covering the picker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentHubPage(
            chatFirstExperience: true,
            onChatFirstRecord: (context, kind) async {
              selected.add(kind.name);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('${kind.label} · 已同步')));
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-record')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('record-type-nursing')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('亲喂 · 已同步'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-first-action-record')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('亲喂 · 已同步'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('record-type-formula')));
    await tester.pump();
    expect(selected, ['nursing', 'formula']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('narrow large-text composer remains usable with a long draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AgentHubPage(chatFirstExperience: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      '想请你一起回顾上一次记录的奶量，并结合这几天的变化，讨论下一步要观察什么。',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('chat-first-camera')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-send-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('chat-first-action-record')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('chat-first-record-picker')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('three truthful chat actions replace generated suggestions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AgentHubPage(chatFirstExperience: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Restoring conversation…'), findsNothing);
    expect(
      find.byKey(const ValueKey('chat-first-action-record')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('chat-first-action-cry')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-first-action-poop')),
      findsOneWidget,
    );
    expect(find.text("Today's milk"), findsNothing);
    expect(find.text('7-day schedule'), findsNothing);
    expect(find.byKey(const ValueKey('agent-welcome-card')), findsNothing);
    expect(find.byKey(const ValueKey('chat-first-camera')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-first-voice-input')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-attachment-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('agent-send-button')), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer-input')))
          .decoration!
          .hintText,
      '和 Momcozy AI 聊聊…',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer-input')))
          .decoration!
          .enabledBorder,
      InputBorder.none,
    );

    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      '保留这条草稿',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('chat-first-camera')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-first-voice-input')), findsNothing);
    expect(find.byKey(const ValueKey('agent-attachment-button')), findsNothing);
    expect(find.byKey(const ValueKey('agent-send-button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-first-action-record')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('chat-first-record-picker')),
      findsOneWidget,
    );
    for (final name in ['亲喂', '配方奶', '瓶喂母乳', '换尿布']) {
      expect(find.text(name), findsOneWidget);
    }
    await tester.drag(
      find.descendant(
        of: find.byKey(const ValueKey('chat-first-record-picker')),
        matching: find.byType(ListView),
      ),
      const Offset(-470, 0),
    );
    await tester.pumpAndSettle();
    for (final name in ['吸奶', '睡眠', '生长']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('agent-composer-input')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('chat-first-record-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agent-composer-input')), findsOneWidget);
    expect(find.text('保留这条草稿'), findsOneWidget);
  });

  testWidgets('voice entry is honest about unavailable recording', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AgentHubPage(chatFirstExperience: true)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-voice-input')));
    await tester.pump();
    expect(find.textContaining('语音输入暂不可用'), findsWidgets);
    expect(find.text('按住说话'), findsNothing);
  });

  testWidgets('real welcome run never archives the legacy English greeting', (
    tester,
  ) async {
    final client = _ImmediateClient();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentHubPage(
            chatFirstExperience: true,
            runner: AgentStreamRunner(client),
            initialAutoRunRequest: const AgentHubAutoRunRequest(
              requestMessage: '请依据真实资料欢迎我。',
              idempotencyKey: 'chat-first-welcome:test-owner',
              metadata: {'source': 'chat_first_welcome'},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(client.requests, hasLength(1));
    expect(find.textContaining("Hi, I'm Momcozy AI"), findsNothing);
    expect(find.textContaining('AI companion from Momcozy'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'chat-first run progress and failures use truthful Chinese copy',
    (tester) async {
      Widget page(AgentStreamRunState state) => MaterialApp(
        home: Scaffold(
          body: AgentHubPage(chatFirstExperience: true, state: state),
        ),
      );
      await tester.pumpWidget(page(const AgentStreamRunState()));
      await tester.pump();
      await tester.pumpWidget(
        page(const AgentStreamRunState(phase: AgentStreamRunPhase.streaming)),
      );
      await tester.pump();
      expect(find.text('正在思考…'), findsOneWidget);
      expect(find.text('Thinking ...'), findsNothing);
      await tester.pumpWidget(
        page(
          const AgentStreamRunState(
            phase: AgentStreamRunPhase.error,
            errorMessage: 'SocketException: unavailable',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('这次没有收到回复。'), findsOneWidget);
      expect(find.textContaining('请检查网络'), findsOneWidget);
      expect(find.text('No response this time.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'chat-first upgrade omits cached legacy greeting, keeps real turns',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AgentHubPage(
              chatFirstExperience: true,
              historyMessages: [
                AgentHubHistoryMessage(
                  id: 'local:welcome',
                  role: AgentHubHistoryRole.assistant,
                  content: "Hi, I'm Momcozy AI. It's lovely to meet you.",
                ),
                AgentHubHistoryMessage(
                  id: 'real-user-turn',
                  role: AgentHubHistoryRole.user,
                  content: '真实提问',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining("Hi, I'm Momcozy AI"), findsNothing);
      expect(find.text('真实提问'), findsOneWidget);
    },
  );

  testWidgets('attachment menu is real and closing it preserves draft', (
    tester,
  ) async {
    final draft = TextEditingController();
    Widget composer({List<AgentStreamFileInput> files = const []}) =>
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: AgentComposerBar(
                chatFirstExperience: true,
                controller: draft,
                canSend: true,
                isRunning: false,
                isInputLocked: false,
                images: const [],
                files: files,
                canAttachImage: true,
                canAttachFile: true,
                isAttachmentPending: false,
                onChanged: (_) {},
                onSend: () {},
                onCancel: () {},
                onTakePhoto: () {},
                onPickPhoto: () {},
                onPickFile: () {},
                onRemoveImage: (_) {},
                onRemoveFile: (_) {},
              ),
            ),
          ),
        );
    await tester.pumpWidget(composer());
    await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
    await tester.pumpAndSettle();
    expect(find.text('相机'), findsOneWidget);
    expect(find.text('照片'), findsOneWidget);
    expect(find.text('文件'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('agent-composer-input')),
      '草稿不会丢',
    );
    await tester.pump();
    expect(draft.text, '草稿不会丢');
    expect(find.byKey(const ValueKey('agent-send-button')), findsOneWidget);
    draft.clear();
    await tester.pumpWidget(
      composer(
        files: const [
          AgentStreamFileInput(fileId: 'owned-file', name: '观察记录.pdf'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agent-send-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-first-voice-input')), findsNothing);
    expect(find.byKey(const ValueKey('agent-attachment-button')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    draft.dispose();
  });

  testWidgets('cry and poop topics do not fabricate recognition', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AgentHubPage(chatFirstExperience: true)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-first-topic-cry')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-first-cry-start')), findsOneWidget);
    expect(find.textContaining('上传并分析暂不可用'), findsNothing);
    expect(find.textContaining('分析结果'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-first-topic-poop')), findsOneWidget);
    expect(find.textContaining('识别结果'), findsNothing);
    expect(find.text('拍一张清晰的便便照片'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-first-poop-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-first-poop-submit')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-first-topic-poop')), findsOneWidget);
  });
}

class _ImmediateClient implements AgentStreamClient {
  final requests = <AgentStreamRequest>[];

  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) {
    requests.add(request);
    return const Stream<AgentStreamEvent>.empty();
  }
}

class _NoUploadMedia implements MediaRepository {
  @override
  Future<UploadedMediaFile> uploadFile({
    required ApiUploadFile file,
    String? idempotencyKey,
  }) => throw StateError('The picker must fail before upload.');

  @override
  Future<void> deleteFile({
    required String fileId,
    String? idempotencyKey,
  }) async {}
}
