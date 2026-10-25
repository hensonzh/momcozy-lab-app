import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_interaction_store.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/chat_first_poop_task.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/stool_photo_review.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/stool_analysis.dart';

void main() {
  test(
    'accepted specialty task keeps resumable cursor without photo bytes',
    () {
      final task =
          ChatFirstPoopTask(
            id: 'local:poop:synthetic',
            createdAt: DateTime.utc(2026, 10, 22),
            threadId: 'thread',
          ).submitted(
            const StoolCardState(
              analysisId: 'analysis',
              sequence: 1,
              visible: true,
            ),
          );
      final persisted = task.toMap();
      expect(persisted.toString(), isNot(contains('dataUrl')));
      final restored = ChatFirstPoopTask.fromMap(persisted);
      expect(restored?.analysisState?.analysisId, 'analysis');
      expect(restored?.analysisState?.sequence, 1);
      expect(() => restored?.withThread('new-thread'), throwsStateError);
      expect(
        ChatFirstPoopTask.fromMap({...persisted}..remove('threadId')),
        isNull,
      );
      expect(
        ChatFirstPoopTask.fromMap({
          ...persisted,
          'analysis': {
            'analysisId': 'analysis',
            'sequence': 1,
            'visible': true,
            'status': 'completed',
          },
        }),
        isNull,
      );
    },
  );

  testWidgets(
    'uploads originals on selection; no legacy Agent Run or medical submit',
    (tester) async {
      _smallViewport(tester);
      final reviews = _Reviews();
      final client = _Client();
      await tester.pumpWidget(_page(reviews, client));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('chat-first-poop-photo')));
        await tester.pump();
      }
      expect(reviews.uploaded.length, 3);
      expect(
        reviews.uploaded.every((bytes) => identical(bytes, _photo)),
        isTrue,
      );
      expect(reviews.keys.toSet().length, 3);
      expect(find.text('已选 3/3 张'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-first-poop-photo')), findsNothing);
      expect(find.textContaining('正在审核照片'), findsNWidgets(3));
      expect(_submit(tester).onPressed, isNull);
      expect(client.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'approved photo submits only to specialty; card shell precedes replayed terminal',
    (tester) async {
      _largeViewport(tester);
      final reviews = _Reviews();
      final client = _Client();
      final specialty = _Analysis();
      await tester.pumpWidget(
        _page(
          reviews,
          client,
          analysis: specialty,
          threadId: '123e4567-e89b-12d3-a456-426614174002',
          babyId: '123e4567-e89b-12d3-a456-426614174001',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-photo')));
      await tester.pump();
      reviews.results['photo-1'] = const StoolPhotoReview(
        photoId: 'photo-1',
        status: StoolPhotoReviewStatus.passed,
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(_submit(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-submit')));
      await tester.pump();
      expect(specialty.submissions, 1);
      expect(specialty.photoIds, ['photo-1']);
      expect(specialty.threadId, '123e4567-e89b-12d3-a456-426614174002');
      expect(find.textContaining('正在等待分析'), findsOneWidget);
      expect(client.requests, isEmpty);
      expect(reviews.deleted, isEmpty);
      await tester.pump(const Duration(seconds: 2));
      specialty.release.complete();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(specialty.lastCursor, 1);
      expect(find.text('专项分析未完成，请稍后重试。'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(reviews.deleted, isEmpty);
    },
  );

  testWidgets(
    'nonmedical progress continues polling from its committed cursor',
    (tester) async {
      _largeViewport(tester);
      final specialty = _Analysis()
        ..streamProgress = true
        ..historyItems = [
          StoolAnalysisHistoryItem(
            analysisId: 'analysis-synthetic',
            status: StoolAnalysisStatus.running,
            babyId: '123e4567-e89b-12d3-a456-426614174001',
            createdAt: DateTime.utc(2026, 10, 22),
          ),
        ];
      specialty.release.complete();
      await tester.pumpWidget(
        _page(
          _Reviews(),
          _Client(),
          analysis: specialty,
          threadId: '123e4567-e89b-12d3-a456-426614174002',
          babyId: '123e4567-e89b-12d3-a456-426614174001',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('专项服务正在处理照片，请稍候…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(specialty.lastCursor, 2);
      specialty.terminalRelease.complete();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('专项分析未完成，请稍后重试。'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'saved history and photos remain readable when new analysis is unavailable',
    (tester) async {
      _largeViewport(tester);
      final specialty = _Analysis()
        ..available = false
        ..streamCompleted = true
        ..historyItems = [
          StoolAnalysisHistoryItem(
            analysisId: 'analysis-synthetic',
            status: StoolAnalysisStatus.completed,
            result: _completedResult,
            babyId: '123e4567-e89b-12d3-a456-426614174001',
            createdAt: DateTime.utc(2026, 10, 22),
          ),
        ];
      specialty.release.complete();
      await tester.pumpWidget(
        _page(
          _Reviews(),
          _Client(),
          analysis: specialty,
          threadId: '123e4567-e89b-12d3-a456-426614174002',
          babyId: '123e4567-e89b-12d3-a456-426614174001',
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(specialty.historyCalls, greaterThan(0));
      expect(
        find.byKey(const ValueKey('chat-first-poop-followup')),
        findsOneWidget,
      );
      final load = find.byKey(const ValueKey('chat-first-poop-load-photos'));
      expect(load, findsOneWidget);
      await tester.ensureVisible(load);
      await tester.tap(load);
      await tester.pumpAndSettle();
      expect(specialty.photoLoads, 1);
      expect(
        find.byKey(const ValueKey('chat-first-poop-sent-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('chat-first-poop-delete-analysis')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'new page recovers accepted card from owner-scoped thread history and replay',
    (tester) async {
      _largeViewport(tester);
      final specialty = _Analysis()
        ..historyItems = [
          StoolAnalysisHistoryItem(
            analysisId: 'analysis-synthetic',
            status: StoolAnalysisStatus.failed,
            babyId: '123e4567-e89b-12d3-a456-426614174001',
            createdAt: DateTime.utc(2026, 10, 22),
          ),
        ];
      specialty.release.complete();
      await tester.pumpWidget(
        _page(
          _Reviews(),
          _Client(),
          analysis: specialty,
          threadId: '123e4567-e89b-12d3-a456-426614174002',
          babyId: '123e4567-e89b-12d3-a456-426614174001',
        ),
      );
      await tester.pumpAndSettle();
      expect(specialty.historyCalls, greaterThan(0));
      expect(find.textContaining('正在等待分析'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('专项分析未完成，请稍后重试。'), findsOneWidget);
      expect(specialty.lastCursor, 1);
      await tester.tap(
        find.byKey(const ValueKey('chat-first-poop-load-photos')),
      );
      await tester.pumpAndSettle();
      expect(specialty.photoLoads, 1);
      expect(
        find.byKey(const ValueKey('chat-first-poop-sent-0')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('chat-first-poop-delete-analysis')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('如果照片也用于其他分析'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(specialty.deletions, 0);
      await tester.tap(
        find.byKey(const ValueKey('chat-first-poop-delete-analysis')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('chat-first-poop-confirm-delete')),
      );
      await tester.pumpAndSettle();
      expect(specialty.deletions, 1);
      expect(
        find.byKey(const ValueKey('chat-first-poop-analysis-card')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('chat-first-poop-sent-0')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'late thumbnail after switching baby never appears on the new card',
    (tester) async {
      _largeViewport(tester);
      final firstBaby = '123e4567-e89b-12d3-a456-426614174001';
      final secondBaby = '123e4567-e89b-12d3-a456-426614174004';
      final thread = '123e4567-e89b-12d3-a456-426614174002';
      final specialty = _Analysis()
        ..historyItems = [
          StoolAnalysisHistoryItem(
            analysisId: 'analysis-synthetic',
            status: StoolAnalysisStatus.failed,
            babyId: firstBaby,
            createdAt: DateTime.utc(2026, 10, 22),
          ),
        ]
        ..photoPending = Completer<Uint8List>();
      specialty.release.complete();
      final key = Object();
      await tester.pumpWidget(
        _page(
          _Reviews(),
          _Client(),
          analysis: specialty,
          cacheKey: key,
          threadId: thread,
          babyId: firstBaby,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('chat-first-poop-load-photos')),
      );
      await tester.pump();
      expect(specialty.photoLoads, 1);
      await tester.pumpWidget(
        _page(
          _Reviews(),
          _Client(),
          analysis: specialty,
          cacheKey: key,
          threadId: thread,
          babyId: secondBaby,
        ),
      );
      specialty.photoPending!.complete(_photo);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chat-first-poop-sent-0')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'explicit deletion stays available when new analysis is disabled',
    (tester) async {
      _largeViewport(tester);
      final thread = '123e4567-e89b-12d3-a456-426614174002';
      final store = _Store()
        ..value = AgentHubInteractionSnapshot(
          runState: AgentStreamRunState(threadId: thread),
          poopTasks: [
            ChatFirstPoopTask(
              id: 'local:poop:prior',
              threadId: thread,
              createdAt: DateTime.utc(2026, 10, 22),
            ).submitted(
              const StoolCardState(
                analysisId: 'analysis-synthetic',
                sequence: 1,
                visible: true,
              ),
            ),
          ],
        );
      final specialty = _Analysis()
        ..available = false
        ..historyItems = [
          StoolAnalysisHistoryItem(
            analysisId: 'analysis-synthetic',
            status: StoolAnalysisStatus.queued,
            babyId: '123e4567-e89b-12d3-a456-426614174001',
            createdAt: DateTime.utc(2026, 10, 22),
          ),
        ];
      await tester.pumpWidget(
        _page(
          _Reviews(),
          _Client(),
          store: store,
          cacheKey: Object(),
          analysis: specialty,
          babyId: '123e4567-e89b-12d3-a456-426614174001',
        ),
      );
      await tester.pumpAndSettle();
      expect(specialty.historyCalls, greaterThan(0));
      await tester.tap(
        find.byKey(const ValueKey('chat-first-poop-delete-analysis')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('chat-first-poop-confirm-delete')),
      );
      await tester.pumpAndSettle();
      expect(specialty.deletions, 1);
      expect(
        find.byKey(const ValueKey('chat-first-poop-analysis-card')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('revoked server analysis is removed from persisted local card', (
    tester,
  ) async {
    _largeViewport(tester);
    final thread = '123e4567-e89b-12d3-a456-426614174002';
    final store = _Store()
      ..value = AgentHubInteractionSnapshot(
        runState: AgentStreamRunState(threadId: thread),
        poopTasks: [
          ChatFirstPoopTask(
            id: 'local:poop:old',
            createdAt: DateTime.utc(2026, 10, 22),
            threadId: thread,
          ).submitted(
            const StoolCardState(
              analysisId: 'revoked-analysis',
              sequence: 1,
              visible: true,
            ),
          ),
        ],
      );
    final specialty = _Analysis(); // Authoritative history is empty.
    await tester.pumpWidget(
      _page(
        _Reviews(),
        _Client(),
        store: store,
        cacheKey: Object(),
        analysis: specialty,
        babyId: '123e4567-e89b-12d3-a456-426614174001',
      ),
    );
    await tester.pumpAndSettle();
    expect(specialty.historyCalls, greaterThan(0));
    expect(
      find.byKey(const ValueKey('chat-first-poop-analysis-card')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late previous-baby history cannot appear after baby switch', (
    tester,
  ) async {
    _largeViewport(tester);
    final specialty = _Analysis()
      ..historyPending = Completer<StoolAnalysisHistoryPage>();
    final cacheKey = Object();
    final thread = '123e4567-e89b-12d3-a456-426614174002';
    final firstBaby = '123e4567-e89b-12d3-a456-426614174001';
    final secondBaby = '123e4567-e89b-12d3-a456-426614174004';
    await tester.pumpWidget(
      _page(
        _Reviews(),
        _Client(),
        analysis: specialty,
        threadId: thread,
        babyId: firstBaby,
        cacheKey: cacheKey,
      ),
    );
    await tester.pump();
    expect(specialty.historyCalls, 1);
    await tester.pumpWidget(
      _page(
        _Reviews(),
        _Client(),
        analysis: specialty,
        threadId: thread,
        babyId: secondBaby,
        cacheKey: cacheKey,
      ),
    );
    await tester.pump();
    specialty.historyPending!.complete(
      StoolAnalysisHistoryPage(
        items: [
          StoolAnalysisHistoryItem(
            analysisId: 'old-baby-analysis',
            status: StoolAnalysisStatus.queued,
            babyId: firstBaby,
            createdAt: DateTime.utc(2026, 10, 22),
          ),
        ],
        nextCursor: null,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('chat-first-poop-analysis-card')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'in-flight submit on leaving never deletes possibly committed originals',
    (tester) async {
      _largeViewport(tester);
      final previous = _Reviews();
      final specialty = _Analysis()
        ..admissionPending = Completer<StoolAnalysisSnapshot>();
      final thread = '123e4567-e89b-12d3-a456-426614174002';
      await tester.pumpWidget(
        _page(
          previous,
          _Client(),
          analysis: specialty,
          threadId: thread,
          babyId: '123e4567-e89b-12d3-a456-426614174001',
          cacheKey: Object(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-photo')));
      await tester.pump();
      previous.results['photo-1'] = const StoolPhotoReview(
        photoId: 'photo-1',
        status: StoolPhotoReviewStatus.passed,
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-submit')));
      await tester.pump();
      expect(specialty.submissions, 1);
      await tester.pumpWidget(const SizedBox());
      expect(previous.deleted, isEmpty);
      specialty.admissionPending!.complete(
        const StoolAnalysisSnapshot(
          analysisId: 'analysis-synthetic',
          status: StoolAnalysisStatus.queued,
        ),
      );
      await tester.pump();
      expect(previous.deleted, isEmpty);
    },
  );

  testWidgets('server review controls each photo; failed one can be removed', (
    tester,
  ) async {
    _largeViewport(tester);
    final reviews = _Reviews();
    final client = _Client();
    await tester.pumpWidget(_page(reviews, client));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-photo')));
      await tester.pump();
    }
    reviews.results['photo-1'] = const StoolPhotoReview(
      photoId: 'photo-1',
      status: StoolPhotoReviewStatus.passed,
    );
    reviews.results['photo-2'] = const StoolPhotoReview(
      photoId: 'photo-2',
      status: StoolPhotoReviewStatus.rejected,
      reasonCodes: ['face_visible'],
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('chat-first-poop-review-0')),
      findsOneWidget,
    );
    expect(find.textContaining('照片含不必要的敏感内容'), findsOneWidget);
    expect(_submit(tester).onPressed, isNull);
    await tester.ensureVisible(
      find.byKey(const ValueKey('chat-first-poop-remove-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-poop-remove-1')));
    await tester.pump();
    expect(reviews.deleted, ['photo-2']);
    expect(find.text('已选 1/3 张'), findsOneWidget);
    expect(find.textContaining('专项分析服务尚未开放'), findsOneWidget);
    expect(client.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'initial card has no abandon action or service implementation copy',
    (tester) async {
      _largeViewport(tester);
      await tester.pumpWidget(_page(_Reviews(), _Client()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chat-first-poop-abandon')),
        findsNothing,
      );
      expect(find.textContaining('照片会上传至专用审核服务'), findsNothing);
      expect(
        find.byKey(const ValueKey('chat-first-topic-poop')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'new poop card follows the latest reply even with an older device clock',
    (tester) async {
      _largeViewport(tester);
      final store = _Store()
        ..value = AgentHubInteractionSnapshot(
          runState: const AgentStreamRunState(threadId: 'thread-poop'),
          historyMessages: [
            AgentHubHistorySnapshot(
              id: 'latest-reply',
              role: 'assistant',
              content: '先前的最后一句回复',
              createdAt: DateTime.utc(2026, 10, 25),
            ),
          ],
        );
      await tester.pumpWidget(
        _page(
          _Reviews(),
          _Client(),
          store: store,
          now: () => DateTime.utc(2026, 10, 1),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('chat-first-topic-poop'));
      expect(card, findsOneWidget);
      expect(
        tester.getTopLeft(card).dy,
        greaterThan(tester.getTopLeft(find.text('先前的最后一句回复')).dy),
      );
      expect(
        store.value?.poopTasks.single.placedAfterMessageId,
        'latest-reply',
      );
    },
  );

  testWidgets('poop card follows a completed reply before history sync', (
    tester,
  ) async {
    _largeViewport(tester);
    final store = _Store()
      ..value = AgentHubInteractionSnapshot(
        runState: const AgentStreamRunState(
          phase: AgentStreamRunPhase.finished,
          threadId: 'thread-poop',
          runId: 'run-before-poop',
          messageId: 'reply-before-poop',
          textContent: '刚完成的回复',
          completedAssistantMessageReceived: true,
        ),
        historyMessages: [
          AgentHubHistorySnapshot(
            id: 'earlier-reply',
            role: 'assistant',
            content: '更早的回复',
            createdAt: DateTime.utc(2026, 10, 25),
          ),
        ],
      );
    await tester.pumpWidget(
      _page(
        _Reviews(),
        _Client(),
        store: store,
        now: () => DateTime.utc(2026, 10, 1),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('chat-first-topic-poop'));
    expect(find.text('刚完成的回复'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('更早的回复')).dy,
      lessThan(tester.getTopLeft(find.text('刚完成的回复')).dy),
    );
    expect(
      tester.getTopLeft(find.text('刚完成的回复')).dy,
      lessThan(tester.getTopLeft(card).dy),
    );
  });

  testWidgets('using an older poop card moves it to the latest reply', (
    tester,
  ) async {
    _largeViewport(tester);
    final store = _Store()
      ..value = AgentHubInteractionSnapshot(
        runState: const AgentStreamRunState(threadId: 'thread-poop'),
        poopTasks: [
          ChatFirstPoopTask(
            id: 'local:poop:old',
            threadId: 'thread-poop',
            createdAt: DateTime.utc(2026, 10, 1),
            placedAfterMessageId: 'old-reply',
          ),
        ],
        historyMessages: [
          AgentHubHistorySnapshot(
            id: 'old-reply',
            role: 'assistant',
            content: '旧回答',
            createdAt: DateTime.utc(2026, 10, 1),
          ),
          AgentHubHistorySnapshot(
            id: 'new-reply',
            role: 'assistant',
            content: '新回答',
            createdAt: DateTime.utc(2026, 10, 2),
          ),
        ],
      );
    final reviews = _Reviews();
    await tester.pumpWidget(_page(reviews, _Client(), store: store));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('chat-first-topic-poop'));
    expect(
      tester.getTopLeft(card).dy,
      lessThan(tester.getTopLeft(find.text('新回答')).dy),
    );
    await tester.tap(find.byKey(const ValueKey('chat-first-poop-photo')));
    await tester.pumpAndSettle();
    expect(reviews.uploaded, hasLength(1));
    expect(card, findsOneWidget);
    expect(
      tester.getTopLeft(card).dy,
      greaterThan(tester.getTopLeft(find.text('新回答')).dy),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(store.value?.poopTasks.single.placedAfterMessageId, 'new-reply');
  });

  testWidgets('a transient review read failure keeps polling the same upload', (
    tester,
  ) async {
    _largeViewport(tester);
    final reviews = _Reviews()..reviewFailures['photo-1'] = 1;
    await tester.pumpWidget(_page(reviews, _Client()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-poop-photo')));
    await tester.pump();

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.textContaining('正在审核照片'), findsOneWidget);

    reviews.results['photo-1'] = const StoolPhotoReview(
      photoId: 'photo-1',
      status: StoolPhotoReviewStatus.passed,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('chat-first-poop-review-0')),
      findsOneWidget,
    );
    expect(reviews.reviewCalls.where((id) => id == 'photo-1').length, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unknown or failed review never enables analysis', (
    tester,
  ) async {
    _smallViewport(tester);
    final reviews = _Reviews();
    final client = _Client();
    await tester.pumpWidget(_page(reviews, client));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-poop-photo')));
    await tester.pump();
    reviews.results['photo-1'] = const StoolPhotoReview(
      photoId: 'photo-1',
      status: StoolPhotoReviewStatus.inconclusive,
      reasonCodes: ['policy_not_calibrated'],
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.textContaining('审核暂不可用'), findsOneWidget);
    expect(_submit(tester).onPressed, isNull);
    expect(client.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late upload after leaving is deleted and never starts a Run', (
    tester,
  ) async {
    _smallViewport(tester);
    final reviews = _Reviews()..pending = Completer<void>();
    final client = _Client();
    await tester.pumpWidget(_page(reviews, client));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-poop-photo')));
    await tester.pump();
    expect(reviews.uploaded, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    reviews.pending!.complete();
    await tester.pump();
    expect(reviews.deleted, ['photo-1']);
    expect(client.requests, isEmpty);
  });

  testWidgets(
    'server unavailable capability blocks capture before private upload',
    (tester) async {
      _smallViewport(tester);
      final reviews = _Reviews()..available = false;
      final client = _Client();
      await tester.pumpWidget(_page(reviews, client));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chat-first-poop-unavailable')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('chat-first-poop-camera')),
            )
            .onPressed,
        isNull,
      );
      expect(reviews.uploaded, isEmpty);
      expect(client.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('stale previous-account capability cannot enable capture', (
    tester,
  ) async {
    _smallViewport(tester);
    final previous = _Reviews()..capabilityPending = Completer<bool>();
    final current = _Reviews()..available = false;
    final client = _Client();
    final oldKey = Object();
    final newKey = Object();
    await tester.pumpWidget(_page(previous, client, cacheKey: oldKey));
    await tester.pump();
    await tester.pumpWidget(_page(current, client, cacheKey: newKey));
    await tester.pumpAndSettle();
    previous.capabilityPending!.complete(true);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('chat-first-poop-unavailable')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('chat-first-poop-camera')),
          )
          .onPressed,
      isNull,
    );
    expect(current.uploaded, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('missing review contract disables capture and analysis', (
    tester,
  ) async {
    _smallViewport(tester);
    final client = _Client();
    await tester.pumpWidget(_page(null, client));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-action-poop')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('chat-first-poop-camera')),
          )
          .onPressed,
      isNull,
    );
    expect(client.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'completed card hides follow-up while the server gate is closed',
    (tester) async {
      _largeViewport(tester);
      final analysis = _Analysis()..followupAvailable = false;
      analysis.historyItems.add(
        StoolAnalysisHistoryItem(
          analysisId: 'analysis-synthetic',
          status: StoolAnalysisStatus.completed,
          result: _completedResult,
          babyId: '123e4567-e89b-12d3-a456-426614174001',
          createdAt: DateTime.utc(2026, 10, 22),
        ),
      );
      analysis.release.complete();
      await tester.pumpWidget(
        _page(
          _Reviews(),
          _Client(),
          analysis: analysis,
          threadId: '123e4567-e89b-12d3-a456-426614174002',
          babyId: '123e4567-e89b-12d3-a456-426614174001',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chat-first-poop-followup')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'completed card selects same-analysis image and result for Agent follow-up',
    (tester) async {
      _largeViewport(tester);
      final analysis = _Analysis()..streamCompleted = true;
      analysis.historyItems.add(
        StoolAnalysisHistoryItem(
          analysisId: 'analysis-synthetic',
          status: StoolAnalysisStatus.completed,
          result: _completedResult,
          babyId: '123e4567-e89b-12d3-a456-426614174001',
          createdAt: DateTime.utc(2026, 10, 22),
        ),
      );
      analysis.release.complete();
      final client = _Client();
      await tester.pumpWidget(
        _page(
          _Reviews(),
          client,
          analysis: analysis,
          threadId: '123e4567-e89b-12d3-a456-426614174002',
          babyId: '123e4567-e89b-12d3-a456-426614174001',
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      final followup = find.byKey(const ValueKey('chat-first-poop-followup'));
      expect(followup, findsOneWidget);
      await tester.ensureVisible(followup);
      await tester.tap(followup);
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('agent-composer-input')),
            )
            .controller
            ?.text,
        contains('这次看便便分析结果'),
      );
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      await tester.pump();
      expect(client.requests, hasLength(1));
      expect(
        client.requests.single.stoolFollowup?.analysisId,
        'analysis-synthetic',
      );
      expect(
        client.requests.single.stoolFollowup?.babyId,
        '123e4567-e89b-12d3-a456-426614174001',
      );
      expect(client.requests.single.images, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'legacy server history remains readable without displaying prompt',
    (tester) async {
      _smallViewport(tester);
      final store = _Store()
        ..value = AgentHubInteractionSnapshot(
          runState: const AgentStreamRunState(threadId: 'thread-poop'),
          poopTasks: [
            ChatFirstPoopTask(
              id: 'local:poop:historical',
              createdAt: DateTime.utc(2026, 10, 17),
              threadId: 'thread-poop',
              runId: 'run-poop',
              status: ChatFirstPoopTaskStatus.completed,
            ),
          ],
          historyMessages: [
            AgentHubHistorySnapshot(
              id: 'server-user',
              runId: 'run-poop',
              role: 'user',
              content: '[momcozy_internal_poop_v1] old request',
              createdAt: DateTime.utc(2026, 10, 17, 12),
              isChatFirstPoopTrigger: true,
            ),
            AgentHubHistorySnapshot(
              id: 'server-answer',
              role: 'assistant',
              content: '这是旧版观察回复。',
              createdAt: DateTime.utc(2026, 10, 17, 12, 1),
            ),
          ],
        );
      await tester.pumpWidget(_page(_Reviews(), _Client(), store: store));
      await tester.pumpAndSettle();
      expect(find.text('已发送便便照片。'), findsOneWidget);
      expect(find.text('这是旧版观察回复。'), findsOneWidget);
      expect(find.textContaining('momcozy_internal_poop_v1'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

FilledButton _submit(WidgetTester tester) => tester.widget<FilledButton>(
  find.byKey(const ValueKey('chat-first-poop-submit')),
);

void _largeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _smallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

final _photo = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg==',
  ),
);

Widget _page(
  _Reviews? reviews,
  _Client client, {
  _Store? store,
  Object? cacheKey,
  _Analysis? analysis,
  String? threadId,
  String? babyId,
  DateTime Function()? now,
}) => MaterialApp(
  home: Scaffold(
    body: AgentHubPage(
      key: const ValueKey('poop-page'),
      stateCacheKey: cacheKey,
      chatFirstExperience: true,
      now: now,
      interactionStateStore: store,
      runner: AgentStreamRunner(client),
      state: AgentStreamRunState(threadId: threadId),
      stoolPhotoReviewRepository: reviews,
      stoolAnalysisRepository: analysis,
      stoolBabyId: babyId,
      pickStoolPhoto: (_) async => AgentStreamImageInput(
        dataUrl: '',
        mimeType: 'image/png',
        name: 'diaper.png',
        size: _photo.length,
        localBytes: _photo,
      ),
    ),
  ),
);

const _completedResult = StoolAnalysisResult(
  assessmentStatus: 'assessed',
  color: 'yellow',
  consistency: 'mushy',
  findings: ['none'],
  riskLevel: 'routine',
  summary: '从照片看为常见黄色糊状外观。',
  careAdvice: '继续观察宝宝整体状态和后续排便变化。',
  uncertainties: [],
);

class _Analysis implements StoolAnalysisRepository {
  final release = Completer<void>();
  final terminalRelease = Completer<void>();
  bool streamProgress = false;
  bool streamCompleted = false;
  Completer<StoolAnalysisSnapshot>? admissionPending;
  Completer<StoolAnalysisHistoryPage>? historyPending;
  int submissions = 0;
  bool available = true;
  bool followupAvailable = true;
  List<String>? photoIds;
  String? threadId;
  int? lastCursor;
  int historyCalls = 0;
  List<StoolAnalysisHistoryItem> historyItems = [];
  int photoLoads = 0;
  int deletions = 0;
  Completer<Uint8List>? photoPending;

  @override
  Future<bool> isAnalysisAvailable() async => available;

  @override
  Future<bool> isFollowupAvailable() async => followupAvailable;

  @override
  Future<StoolAnalysisSnapshot> submit({
    required String babyId,
    required String threadId,
    required List<String> photoIds,
    required String idempotencyKey,
  }) async {
    submissions++;
    this.threadId = threadId;
    this.photoIds = photoIds;
    if (admissionPending != null) return admissionPending!.future;
    historyItems.add(
      StoolAnalysisHistoryItem(
        analysisId: 'analysis-synthetic',
        status: StoolAnalysisStatus.queued,
        babyId: babyId,
        createdAt: DateTime.utc(2026, 10, 22),
      ),
    );
    return const StoolAnalysisSnapshot(
      analysisId: 'analysis-synthetic',
      status: StoolAnalysisStatus.queued,
    );
  }

  @override
  Future<StoolAnalysisSnapshot> getStatus(String analysisId) async =>
      const StoolAnalysisSnapshot(
        analysisId: 'analysis-synthetic',
        status: StoolAnalysisStatus.queued,
      );

  @override
  Future<StoolAnalysisHistoryPage> listForThread({
    required String threadId,
    String? cursor,
    int limit = 50,
  }) async {
    historyCalls++;
    if (historyPending != null) return historyPending!.future;
    return StoolAnalysisHistoryPage(items: historyItems, nextCursor: null);
  }

  @override
  Future<void> deleteAnalysis(String analysisId) async {
    deletions++;
    historyItems.removeWhere((item) => item.analysisId == analysisId);
  }

  @override
  Future<StoolAnalysisPhotos> listPhotos(String analysisId) async =>
      const StoolAnalysisPhotos(
        items: [StoolAnalysisPhotoRef(photoId: 'photo-1', position: 0)],
      );

  @override
  Future<Uint8List> loadThumbnail(String analysisId, String photoId) async {
    photoLoads++;
    return photoPending?.future ?? _photo;
  }

  @override
  Stream<StoolAnalysisEvent> eventsAfter(
    String analysisId,
    int afterSequence,
  ) async* {
    lastCursor = afterSequence;
    await release.future;
    if (streamCompleted) {
      final events = <StoolAnalysisEvent>[
        const StoolAnalysisEvent(
          analysisId: 'analysis-synthetic',
          sequence: 2,
          type: StoolAnalysisEventType.started,
        ),
        const StoolAnalysisEvent(
          analysisId: 'analysis-synthetic',
          sequence: 3,
          type: StoolAnalysisEventType.fieldReady,
          field: 'color',
          value: 'yellow',
        ),
        const StoolAnalysisEvent(
          analysisId: 'analysis-synthetic',
          sequence: 4,
          type: StoolAnalysisEventType.fieldReady,
          field: 'consistency',
          value: 'mushy',
        ),
        const StoolAnalysisEvent(
          analysisId: 'analysis-synthetic',
          sequence: 5,
          type: StoolAnalysisEventType.fieldReady,
          field: 'findings',
          value: ['none'],
        ),
        const StoolAnalysisEvent(
          analysisId: 'analysis-synthetic',
          sequence: 6,
          type: StoolAnalysisEventType.fieldReady,
          field: 'risk_level',
          value: 'routine',
        ),
        const StoolAnalysisEvent(
          analysisId: 'analysis-synthetic',
          sequence: 7,
          type: StoolAnalysisEventType.fieldReady,
          field: 'summary',
          value: '从照片看为常见黄色糊状外观。',
        ),
        const StoolAnalysisEvent(
          analysisId: 'analysis-synthetic',
          sequence: 8,
          type: StoolAnalysisEventType.fieldReady,
          field: 'care_advice',
          value: '继续观察宝宝整体状态和后续排便变化。',
        ),
        const StoolAnalysisEvent(
          analysisId: 'analysis-synthetic',
          sequence: 9,
          type: StoolAnalysisEventType.completed,
          result: _completedResult,
        ),
      ];
      for (final event in events.where(
        (event) => event.sequence > afterSequence,
      )) {
        yield event;
      }
      return;
    }
    if (streamProgress) {
      if (afterSequence == 1) {
        yield const StoolAnalysisEvent(
          analysisId: 'analysis-synthetic',
          sequence: 2,
          type: StoolAnalysisEventType.started,
        );
      } else if (afterSequence == 2) {
        await terminalRelease.future;
        yield const StoolAnalysisEvent(
          analysisId: 'analysis-synthetic',
          sequence: 3,
          type: StoolAnalysisEventType.failed,
        );
      }
      return;
    }
    yield const StoolAnalysisEvent(
      analysisId: 'analysis-synthetic',
      sequence: 2,
      type: StoolAnalysisEventType.failed,
    );
  }
}

class _Reviews implements StoolPhotoReviewRepository {
  @override
  Future<bool> isReviewAvailable() async =>
      capabilityPending?.future ?? available;
  Completer<bool>? capabilityPending;
  bool available = true;
  bool followupAvailable = true;

  final uploaded = <Uint8List>[];
  final keys = <String>[];
  final deleted = <String>[];
  final results = <String, StoolPhotoReview>{};
  final pendingReviews = <String, Completer<StoolPhotoReview>>{};
  final reviewFailures = <String, int>{};
  final reviewCalls = <String>[];
  Completer<void>? pending;

  @override
  Future<StoolPhotoReview> uploadOriginal({
    required Uint8List bytes,
    required String name,
    required String mimeType,
    required String idempotencyKey,
  }) async {
    uploaded.add(bytes);
    keys.add(idempotencyKey);
    await pending?.future;
    final id = 'photo-${uploaded.length}';
    return StoolPhotoReview(
      photoId: id,
      status: StoolPhotoReviewStatus.pending,
    );
  }

  @override
  Future<StoolPhotoReview> getReview(String photoId) async {
    reviewCalls.add(photoId);
    final failures = reviewFailures[photoId] ?? 0;
    if (failures > 0) {
      reviewFailures[photoId] = failures - 1;
      throw StateError('transient review read failure');
    }
    final blocked = pendingReviews[photoId];
    if (blocked != null) return blocked.future;
    return results[photoId] ??
        StoolPhotoReview(
          photoId: photoId,
          status: StoolPhotoReviewStatus.pending,
        );
  }

  @override
  Future<void> deletePhoto(String photoId) async {
    deleted.add(photoId);
  }
}

class _Client implements AgentStreamClient {
  final requests = <AgentStreamRequest>[];
  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) {
    requests.add(request);
    return const Stream<AgentStreamEvent>.empty();
  }
}

class _Store implements AgentHubInteractionStateStore {
  AgentHubInteractionSnapshot? value;
  @override
  Future<AgentHubInteractionSnapshot?> read() async => value;
  @override
  Future<void> write(AgentHubInteractionSnapshot snapshot) async {
    value = snapshot;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}
