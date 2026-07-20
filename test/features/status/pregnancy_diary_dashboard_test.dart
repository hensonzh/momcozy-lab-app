import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/features/pregnancy_diary/domain/pregnancy_diary_entry.dart';
import 'package:momcozy_flutter_app/features/status/presentation/pregnancy_diary_dashboard.dart';
import 'package:momcozy_flutter_app/features/status/presentation/status_dashboard_controller.dart';

void main() {
  group('PregnancyDiaryDashboard', () {
    testWidgets('renders loading and measured diary summaries locally', (
      tester,
    ) async {
      await _setViewport(tester);
      final hostKey = GlobalKey<_DiaryHostState>();

      await tester.pumpWidget(_DiaryHost(key: hostKey));
      expect(find.text('正在加载孕期日记…'), findsOneWidget);

      hostKey.currentState!.publish([
        _entry(
          id: 'today',
          date: DateTime(2026, 7, 11),
          content: '今天散步了半小时',
          appointmentNote: '下次需要做什么检查？',
        ),
        _entry(id: 'yesterday', date: DateTime(2026, 7, 10)),
      ]);
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('今天散步了半小时'), findsOneWidget);
      expect(find.text('下次需要做什么检查？'), findsOneWidget);
    });

    testWidgets('disables empty editing while diary authority is unknown', (
      tester,
    ) async {
      await _setViewport(tester);
      final hostKey = GlobalKey<_DiaryHostState>();
      await tester.pumpWidget(_DiaryHost(key: hostKey));

      final recordButton = find.byKey(
        const ValueKey('status-pregnancy-diary-record-button'),
      );
      final filledButton = find.descendant(
        of: recordButton,
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(filledButton).onPressed, isNull);

      hostKey.currentState!.publishError();
      await tester.pump();
      expect(find.text('孕期日记暂时无法同步，请稍后重试。'), findsOneWidget);
      expect(tester.widget<FilledButton>(filledButton).onPressed, isNull);
      expect(
        find.byKey(const ValueKey('status-pregnancy-diary-editor-dialog')),
        findsNothing,
      );
    });

    testWidgets('validates, saves a complete draft and opens saved detail', (
      tester,
    ) async {
      await _setViewport(tester);
      final hostKey = GlobalKey<_DiaryHostState>();
      await tester.pumpWidget(
        _DiaryHost(
          key: hostKey,
          initial: const StatusResource.data(<PregnancyDiaryEntry>[]),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('status-pregnancy-diary-record-button')),
      );
      await tester.pumpAndSettle();

      final saveButton = find.byKey(
        const ValueKey('status-pregnancy-diary-save-button'),
      );
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();
      expect(find.text('至少写下一项今天的状态或记录'), findsOneWidget);
      expect(hostKey.currentState!.saveCalls, 0);

      await tester.tap(
        find.byKey(const ValueKey('status-pregnancy-diary-choice-平稳')),
      );
      await tester.tap(
        find.byKey(const ValueKey('status-pregnancy-diary-choice-不错')),
      );
      await tester.pump();

      final weekInput = find.byKey(
        const ValueKey('status-pregnancy-diary-gestational-week-input'),
      );
      await tester.ensureVisible(weekInput);
      await tester.pumpAndSettle();
      await tester.enterText(weekInput, '孕 32 周');
      await tester.pump();

      final symptom = find.byKey(
        const ValueKey('status-pregnancy-diary-symptom-腰酸'),
      );
      await tester.ensureVisible(symptom);
      await tester.pumpAndSettle();
      await tester.tap(symptom);
      await tester.enterText(
        find.byKey(
          const ValueKey('status-pregnancy-diary-other-symptoms-input'),
        ),
        '腿麻、腰酸',
      );
      await tester.enterText(
        find.byKey(const ValueKey('status-pregnancy-diary-appointment-input')),
        '下次需要做什么检查？',
      );
      final noteInput = find.byKey(
        const ValueKey('status-pregnancy-diary-note-input'),
      );
      await tester.ensureVisible(noteInput);
      await tester.pumpAndSettle();
      await tester.enterText(noteInput, '今天散步了半小时');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(hostKey.currentState!.saveCalls, 1);
      final draft = hostKey.currentState!.lastDraft!;
      expect(draft.gestationalWeek, '孕 32 周');
      expect(draft.mood, '平稳');
      expect(draft.energyLevel, '不错');
      expect(draft.symptomTags, containsAll(['腰酸', '腿麻']));
      expect(draft.symptomTags.where((tag) => tag == '腰酸'), hasLength(1));
      expect(draft.appointmentNote, '下次需要做什么检查？');
      expect(draft.content, '今天散步了半小时');
      expect(
        find.byKey(const ValueKey('status-pregnancy-diary-editor-dialog')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('status-detail-pregnancy-diary')),
        findsOneWidget,
      );
      expect(find.text('今天的记录已保存，我可以继续帮你整理产检问题或回顾最近几天的状态变化。'), findsOneWidget);
      expect(find.text('整理产检问题'), findsOneWidget);
    });

    testWidgets('keeps the editor open with a retryable save failure', (
      tester,
    ) async {
      await _setViewport(tester);
      final hostKey = GlobalKey<_DiaryHostState>();
      await tester.pumpWidget(
        _DiaryHost(
          key: hostKey,
          saveSucceeds: false,
          initial: const StatusResource.data(<PregnancyDiaryEntry>[]),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('status-pregnancy-diary-record-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('status-pregnancy-diary-choice-开心')),
      );
      final saveButton = find.byKey(
        const ValueKey('status-pregnancy-diary-save-button'),
      );
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(hostKey.currentState!.saveCalls, 1);
      expect(
        find.byKey(const ValueKey('status-pregnancy-diary-editor-dialog')),
        findsOneWidget,
      );
      expect(find.text('保存失败，请稍后重试'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '保存今天的日记'), findsOneWidget);
    });

    testWidgets('blocks every close path while a save is in flight', (
      tester,
    ) async {
      await _setViewport(tester);
      final hostKey = GlobalKey<_DiaryHostState>();
      await tester.pumpWidget(
        _DiaryHost(
          key: hostKey,
          deferSave: true,
          initial: const StatusResource.data(<PregnancyDiaryEntry>[]),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('status-pregnancy-diary-record-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('status-pregnancy-diary-choice-平稳')),
      );
      await tester.tap(
        find.byKey(const ValueKey('status-pregnancy-diary-save-button')),
      );
      await tester.pump();

      expect(find.text('保存中…'), findsOneWidget);
      expect(find.byTooltip('关闭编辑'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('status-pregnancy-diary-editor-dialog')),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(4, 4));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('status-pregnancy-diary-editor-dialog')),
        findsOneWidget,
      );

      hostKey.currentState!.completeSave();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-detail-pregnancy-diary')),
        findsOneWidget,
      );
    });

    testWidgets('sends the legacy prioritized Agent prompt from detail', (
      tester,
    ) async {
      await _setViewport(tester);
      final hostKey = GlobalKey<_DiaryHostState>();
      await tester.pumpWidget(
        _DiaryHost(
          key: hostKey,
          initial: StatusResource.data([
            _entry(
              id: 'today',
              date: DateTime(2026, 7, 11),
              appointmentNote: '胎动少需要检查吗？药还能吃吗？',
            ),
          ]),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('status-pregnancy-diary-view-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('从日记里整理 2 个问题'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('status-pregnancy-diary-agent-action')),
      );
      await tester.pumpAndSettle();

      expect(hostKey.currentState!.prompts, ['帮我整理孕期日记里的产检问题清单']);
      expect(
        find.byKey(const ValueKey('status-detail-pregnancy-diary')),
        findsNothing,
      );
    });
  });
}

class _DiaryHost extends StatefulWidget {
  const _DiaryHost({
    super.key,
    this.initial = const StatusResource.loading(),
    this.saveSucceeds = true,
    this.deferSave = false,
  });

  final StatusResource<List<PregnancyDiaryEntry>> initial;
  final bool saveSucceeds;
  final bool deferSave;

  @override
  State<_DiaryHost> createState() => _DiaryHostState();
}

class _DiaryHostState extends State<_DiaryHost> {
  late final ValueNotifier<StatusResource<List<PregnancyDiaryEntry>>> entries;
  final mutation = ValueNotifier<StatusMutationState>(
    const StatusMutationState.idle(),
  );
  final prompts = <String>[];
  PregnancyDiaryDraft? lastDraft;
  var saveCalls = 0;
  Completer<void>? _saveCompleter;

  @override
  void initState() {
    super.initState();
    entries = ValueNotifier(widget.initial);
  }

  void publish(List<PregnancyDiaryEntry> value) {
    entries.value = StatusResource.data(value);
  }

  void publishError() {
    entries.value = StatusResource.error(StateError('unavailable'));
  }

  Future<bool> save(DateTime entryDate, PregnancyDiaryDraft draft) async {
    saveCalls += 1;
    lastDraft = draft;
    mutation.value = const StatusMutationState.saving();
    if (widget.deferSave) {
      _saveCompleter = Completer<void>();
      await _saveCompleter!.future;
    }
    if (!widget.saveSucceeds) {
      mutation.value = const StatusMutationState.error('保存失败，请稍后重试');
      return false;
    }
    final saved = PregnancyDiaryEntry(
      id: 'saved',
      entryDate: entryDate,
      gestationalWeek: draft.gestationalWeek,
      mood: draft.mood,
      energyLevel: draft.energyLevel,
      sleepSummary: draft.sleepSummary,
      fetalMovement: draft.fetalMovement,
      symptomTags: draft.symptomTags,
      appointmentNote: draft.appointmentNote,
      nutritionNote: draft.nutritionNote,
      content: draft.content,
    );
    entries.value = StatusResource.data([saved]);
    mutation.value = const StatusMutationState.success('今天的记录已保存');
    return true;
  }

  void completeSave() => _saveCompleter?.complete();

  @override
  void dispose() {
    entries.dispose();
    mutation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: momCozyTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: PregnancyDiaryDashboard(
            entries: entries,
            mutation: mutation,
            now: () => DateTime(2026, 7, 11, 10),
            onSave: save,
            onAgentPrompt: prompts.add,
          ),
        ),
      ),
    );
  }
}

PregnancyDiaryEntry _entry({
  required String id,
  required DateTime date,
  String content = '',
  String appointmentNote = '',
}) {
  return PregnancyDiaryEntry(
    id: id,
    entryDate: date,
    content: content,
    appointmentNote: appointmentNote,
  );
}

Future<void> _setViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
