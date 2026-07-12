import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/features/status/domain/birth_journey_plan.dart';
import 'package:momcozy_flutter_app/features/status/presentation/birth_journey_plan_dashboard.dart';
import 'package:momcozy_flutter_app/features/status/presentation/status_dashboard_controller.dart';

void main() {
  group('BirthJourneyPlanDashboard', () {
    testWidgets(
      'renders loading and empty creation states with legacy prompt',
      (tester) async {
        await _setViewport(tester);
        final hostKey = GlobalKey<_PlanHostState>();
        await tester.pumpWidget(_PlanHost(key: hostKey));

        expect(find.text('正在加载孕期计划'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('status-birth-journey-skeleton')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('status-pregnancy-plan-agent-button')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('status-birth-journey-detail-button')),
          findsNothing,
        );

        hostKey.currentState!.publish(null);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('status-pregnancy-plan-agent-button')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('status-pregnancy-plan-agent-button')),
        );
        expect(hostKey.currentState!.prompts, [
          (prompt: '帮我生成孕期计划', autoSend: false),
        ]);
      },
    );

    testWidgets('does not show the creation CTA for an unknown failed load', (
      tester,
    ) async {
      await _setViewport(tester);
      final hostKey = GlobalKey<_PlanHostState>();
      await tester.pumpWidget(_PlanHost(key: hostKey));

      hostKey.currentState!.publishError();
      await tester.pump();

      expect(find.text('孕期计划暂时无法同步，请稍后重试'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('status-birth-journey-retry-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-pregnancy-plan-agent-button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('status-birth-journey-detail-button')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('status-birth-journey-retry-button')),
      );
      await tester.pump();
      expect(hostKey.currentState!.retryCalls, 1);
    });

    testWidgets('keeps a stale plan visible when its refresh fails', (
      tester,
    ) async {
      await _setViewport(tester);
      final hostKey = GlobalKey<_PlanHostState>();
      await tester.pumpWidget(
        _PlanHost(key: hostKey, initial: StatusResource.data(_plan())),
      );

      hostKey.currentState!.publishStaleError();
      await tester.pump();

      expect(find.text('准备产检资料'), findsOneWidget);
      expect(find.text('计划可能不是最新内容'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('status-birth-journey-retry-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-pregnancy-plan-agent-button')),
        findsNothing,
      );
    });

    testWidgets('expands future stages and blocks locked todo changes', (
      tester,
    ) async {
      await _setViewport(tester);
      final hostKey = GlobalKey<_PlanHostState>();
      await tester.pumpWidget(
        _PlanHost(key: hostKey, initial: StatusResource.data(_plan())),
      );

      expect(find.text('准备产检资料'), findsOneWidget);
      expect(find.text('1 个事项'), findsNWidgets(2));
      expect(find.text('整理待产包').hitTestable(), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('status-birth-journey-period-upcoming')),
      );
      await tester.pumpAndSettle();
      expect(find.text('整理待产包').hitTestable(), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('status-birth-journey-todo-todo-upcoming')),
      );
      await tester.pump();

      expect(hostKey.currentState!.prompts, isEmpty);
      expect(find.text('当前还未到该阶段，暂不适合进行该事项'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('status-birth-journey-todo-error')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 2400));
      expect(find.text('当前还未到该阶段，暂不适合进行该事项'), findsNothing);
    });

    testWidgets(
      'writes a stable completion then asks once before notifying the Agent',
      (tester) async {
        await _setViewport(tester);
        final hostKey = GlobalKey<_PlanHostState>();
        await tester.pumpWidget(
          _PlanHost(key: hostKey, initial: StatusResource.data(_plan())),
        );

        await tester.tap(
          find.byKey(const ValueKey('status-birth-journey-todo-todo-current')),
        );
        await tester.pump();

        expect(hostKey.currentState!.toggleCalls, [
          (itemId: 'todo-current', completed: true),
        ]);
        expect(
          tester
              .widget<Checkbox>(
                find.byKey(
                  const ValueKey('status-birth-journey-todo-todo-current'),
                ),
              )
              .value,
          isTrue,
        );
        expect(hostKey.currentState!.prompts, isEmpty);
        expect(
          find.byKey(const ValueKey('completed-todo-current')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const ValueKey('status-birth-journey-completion-sparks'),
          ),
          findsOneWidget,
        );

        await tester.pump(const Duration(milliseconds: 1050));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('status-birth-journey-sync-dialog')),
          findsOneWidget,
        );
        expect(find.text('要不要将完成的消息立刻告诉 CozyMate？'), findsOneWidget);
        await tester.tap(find.text('好的'));
        await tester.pumpAndSettle();
        expect(hostKey.currentState!.prompts, [
          (
            prompt: '我已完成【准备产检资料】，请基于这个事项继续追问需要补充的执行细节，并在需要时同步更新我的孕期日记',
            autoSend: true,
          ),
        ]);
      },
    );

    testWidgets('keeps legacy todos read-only and hands them to the Agent', (
      tester,
    ) async {
      await _setViewport(tester);
      final hostKey = GlobalKey<_PlanHostState>();
      await tester.pumpWidget(
        _PlanHost(
          key: hostKey,
          initial: StatusResource.data(_plan(legacyCurrentTodo: true)),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('status-birth-journey-todo-todo-current')),
      );
      await tester.pumpAndSettle();

      expect(hostKey.currentState!.toggleCalls, isEmpty);
      expect(hostKey.currentState!.prompts.single.autoSend, isTrue);
    });

    testWidgets('does not celebrate or prompt after a failed todo write', (
      tester,
    ) async {
      await _setViewport(tester);
      final hostKey = GlobalKey<_PlanHostState>();
      await tester.pumpWidget(
        _PlanHost(
          key: hostKey,
          toggleSucceeds: false,
          initial: StatusResource.data(_plan()),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('status-birth-journey-todo-todo-current')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));

      expect(find.text('同步计划完成状态失败，已恢复最新计划'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('status-birth-journey-sync-dialog')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('status-birth-journey-completion-sparks'),
        ),
        findsNothing,
      );
      expect(hostKey.currentState!.prompts, isEmpty);
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(
                const ValueKey('status-birth-journey-todo-todo-current'),
              ),
            )
            .value,
        isFalse,
      );
    });

    testWidgets('keeps completion feedback static when motion is disabled', (
      tester,
    ) async {
      await _setViewport(tester);
      final semantics = tester.ensureSemantics();
      final hostKey = GlobalKey<_PlanHostState>();
      await tester.pumpWidget(
        _PlanHost(
          key: hostKey,
          disableAnimations: true,
          initial: StatusResource.data(_plan()),
        ),
      );

      expect(find.bySemanticsLabel('标记完成：准备产检资料'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('status-birth-journey-todo-todo-current')),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('completed-todo-current')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('status-birth-journey-completion-sparks'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('lays out long plan content at 360px with large text', (
      tester,
    ) async {
      await _setViewport(tester, size: const Size(360, 800));
      await tester.pumpWidget(
        _PlanHost(
          textScaler: const TextScaler.linear(1.3),
          initial: StatusResource.data(_plan(longText: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_longCurrentTodoTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('supports detail deletion confirmation, failure and retry', (
      tester,
    ) async {
      await _setViewport(tester);
      final hostKey = GlobalKey<_PlanHostState>();
      await tester.pumpWidget(
        _PlanHost(
          key: hostKey,
          deleteSucceeds: false,
          initial: StatusResource.data(_plan()),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('status-birth-journey-detail-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-detail-birth-journey')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('status-detail-birth-journey')),
          matching: find.text('临产住院'),
        ),
        findsOneWidget,
      );

      final deleteButton = find.byKey(
        const ValueKey('status-birth-journey-delete-button'),
      );
      final detailSheet = find.byKey(
        const ValueKey('status-detail-birth-journey'),
      );
      final detailScroll = find.descendant(
        of: detailSheet,
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(detailScroll, const Offset(0, -360));
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pump();
      expect(find.text('确认删除孕期计划？'), findsOneWidget);
      await tester.tap(
        find.byKey(
          const ValueKey('status-birth-journey-delete-confirm-button'),
        ),
      );
      await tester.pumpAndSettle();

      expect(hostKey.currentState!.deleteCalls, 1);
      expect(find.text('删除孕期计划失败'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('status-detail-birth-journey')),
        findsOneWidget,
      );

      hostKey.currentState!.allowDelete();
      await tester.tap(
        find.byKey(
          const ValueKey('status-birth-journey-delete-confirm-button'),
        ),
      );
      await tester.pumpAndSettle();

      expect(hostKey.currentState!.deleteCalls, 2);
      expect(
        find.byKey(const ValueKey('status-detail-birth-journey')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('status-pregnancy-plan-agent-button')),
        findsOneWidget,
      );
    });
  });
}

class _PlanHost extends StatefulWidget {
  const _PlanHost({
    super.key,
    this.initial = const StatusResource.loading(),
    this.deleteSucceeds = true,
    this.toggleSucceeds = true,
    this.disableAnimations = false,
    this.textScaler = TextScaler.noScaling,
  });

  final StatusResource<BirthJourneyPlan?> initial;
  final bool deleteSucceeds;
  final bool toggleSucceeds;
  final bool disableAnimations;
  final TextScaler textScaler;

  @override
  State<_PlanHost> createState() => _PlanHostState();
}

class _PlanHostState extends State<_PlanHost> {
  late final ValueNotifier<StatusResource<BirthJourneyPlan?>> plan;
  final mutation = ValueNotifier<StatusMutationState>(
    const StatusMutationState.idle(),
  );
  final prompts = <({String prompt, bool autoSend})>[];
  final toggleCalls = <({String itemId, bool completed})>[];
  var deleteCalls = 0;
  var retryCalls = 0;
  var _allowDelete = false;

  @override
  void initState() {
    super.initState();
    plan = ValueNotifier(widget.initial);
  }

  void publish(BirthJourneyPlan? value) {
    plan.value = StatusResource.data(value);
  }

  void publishError() {
    plan.value = StatusResource.error(StateError('unavailable'));
  }

  void publishStaleError() {
    plan.value = StatusResource.error(
      StateError('refresh unavailable'),
      previous: plan.value.data,
    );
  }

  Future<bool> delete() async {
    deleteCalls += 1;
    mutation.value = const StatusMutationState.saving();
    if (!widget.deleteSucceeds && !_allowDelete) {
      mutation.value = const StatusMutationState.error('删除孕期计划失败');
      return false;
    }
    plan.value = const StatusResource.data(null);
    mutation.value = const StatusMutationState.success('孕期计划已删除');
    return true;
  }

  Future<bool> toggle(String itemId, bool completed) async {
    toggleCalls.add((itemId: itemId, completed: completed));
    if (!widget.toggleSucceeds) {
      mutation.value = const StatusMutationState.error(
        '同步计划完成状态失败，已恢复最新计划',
      );
      return false;
    }
    final current = plan.value.data;
    if (current == null) return false;
    plan.value = StatusResource.data(
      current.withTodoCompletion(itemId, completed),
    );
    mutation.value = const StatusMutationState.success('事项已完成');
    return true;
  }

  Future<void> retry() async {
    retryCalls += 1;
  }

  void allowDelete() => _allowDelete = true;

  @override
  void dispose() {
    plan.dispose();
    mutation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: momCozyTheme(),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            disableAnimations: widget.disableAnimations,
            textScaler: widget.textScaler,
          ),
          child: child!,
        );
      },
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: BirthJourneyPlanDashboard(
            plan: plan,
            mutation: mutation,
            onDeletePlan: delete,
            onToggleTodo: toggle,
            onRetryPlan: retry,
            onAgentPrompt: (prompt, {autoSend = false}) {
              prompts.add((prompt: prompt, autoSend: autoSend));
            },
          ),
        ),
      ),
    );
  }
}

const _longCurrentTodoTitle =
    '准备下一次高危产检需要携带的全部报告并提前记录所有想咨询医生的问题';

BirthJourneyPlan _plan({
  bool legacyCurrentTodo = false,
  bool longText = false,
}) {
  return BirthJourneyPlan(
    id: 'birth-plan',
    version: 1,
    title: '孕期计划',
    summary: '围绕产检和待产做准备',
    status: 'active',
    periods: [
      BirthJourneyPeriod(
        id: 'current',
        title: '当前阶段',
        subtitle: '孕 32-34 周',
        displayMode: 'expanded',
        status: 'current',
        items: [
          BirthJourneyTodo(
            id: 'todo-current',
            authoritativeItemId: legacyCurrentTodo ? '' : 'todo-current',
            title: longText ? _longCurrentTodoTitle : '准备产检资料',
            priorityLabel: '重要',
            reason: longText
                ? '因为需要和医生逐项确认最近的检查变化以及接下来的观察节奏，所以提前整理会更安心'
                : '下次产检时集中确认',
            steps: ['整理检查报告', '记下想问医生的问题'],
            completed: false,
          ),
        ],
      ),
      BirthJourneyPeriod(
        id: 'upcoming',
        title: '后续阶段',
        subtitle: '孕 35-37 周',
        displayMode: 'collapsed',
        status: 'upcoming',
        items: [
          BirthJourneyTodo(
            id: 'todo-upcoming',
            title: '整理待产包',
            priorityLabel: '建议',
            reason: '提前确认住院物品',
            steps: [],
            completed: false,
          ),
        ],
      ),
      BirthJourneyPeriod(
        id: 'terminal',
        title: '临产住院',
        subtitle: '出现临产信号时',
        displayMode: 'terminal',
        status: 'terminal',
        items: [
          BirthJourneyTodo(
            id: 'todo-terminal',
            title: '联系医院',
            priorityLabel: '重要',
            reason: '',
            steps: [],
            completed: false,
          ),
        ],
      ),
    ],
  );
}

Future<void> _setViewport(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
