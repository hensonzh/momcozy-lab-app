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
          find.byKey(const ValueKey('status-pregnancy-plan-agent-button')),
          findsOneWidget,
        );

        hostKey.currentState!.publish(null);
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('status-pregnancy-plan-agent-button')),
        );
        expect(hostKey.currentState!.prompts, [
          (prompt: '帮我制定孕期计划', autoSend: false),
        ]);
      },
    );

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

      expect(hostKey.currentState!.toggleCalls, isEmpty);
      expect(find.text('当前还未到该阶段，暂不适合进行该事项'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('status-birth-journey-todo-error')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 2400));
      expect(find.text('当前还未到该阶段，暂不适合进行该事项'), findsNothing);
    });

    testWidgets(
      'celebrates completion and confirms an auto-sent Agent prompt',
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

        expect(hostKey.currentState!.toggleCalls, [('todo-current', true)]);
        expect(
          find.byKey(const ValueKey('status-birth-journey-celebration')),
          findsOneWidget,
        );
        expect(find.text('准备产检资料'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 1050));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('status-birth-journey-sync-dialog')),
          findsOneWidget,
        );
        expect(find.text('要不要将完成的消息立刻告诉 CozyMate？'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('status-birth-journey-sync-confirm')),
        );
        await tester.pumpAndSettle();

        expect(hostKey.currentState!.prompts, [
          (
            prompt: '我已完成【准备产检资料】，请基于这个事项继续追问需要补充的执行细节，并在需要时同步更新我的孕期日记',
            autoSend: true,
          ),
        ]);
      },
    );

    testWidgets('shows a local error and rollback after todo sync failure', (
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
      await tester.pumpAndSettle();

      expect(hostKey.currentState!.toggleCalls, [('todo-current', true)]);
      expect(find.text('同步计划完成状态失败'), findsOneWidget);
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
      expect(
        find.byKey(const ValueKey('status-birth-journey-sync-dialog')),
        findsNothing,
      );
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
      await tester.ensureVisible(deleteButton);
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
    this.toggleSucceeds = true,
    this.deleteSucceeds = true,
  });

  final StatusResource<BirthJourneyPlan?> initial;
  final bool toggleSucceeds;
  final bool deleteSucceeds;

  @override
  State<_PlanHost> createState() => _PlanHostState();
}

class _PlanHostState extends State<_PlanHost> {
  late final ValueNotifier<StatusResource<BirthJourneyPlan?>> plan;
  final mutation = ValueNotifier<StatusMutationState>(
    const StatusMutationState.idle(),
  );
  final toggleCalls = <(String, bool)>[];
  final prompts = <({String prompt, bool autoSend})>[];
  var deleteCalls = 0;
  var _allowDelete = false;

  @override
  void initState() {
    super.initState();
    plan = ValueNotifier(widget.initial);
  }

  void publish(BirthJourneyPlan? value) {
    plan.value = StatusResource.data(value);
  }

  Future<bool> toggle(String taskId, bool completed) async {
    toggleCalls.add((taskId, completed));
    final original = plan.value.data;
    if (original == null) return false;
    plan.value = StatusResource.data(
      original.withTodoCompletion(taskId, completed),
    );
    mutation.value = const StatusMutationState.saving();
    if (!widget.toggleSucceeds) {
      plan.value = StatusResource.data(original);
      mutation.value = const StatusMutationState.error('同步计划完成状态失败');
      return false;
    }
    mutation.value = const StatusMutationState.success('计划已更新');
    return true;
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
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: BirthJourneyPlanDashboard(
            plan: plan,
            mutation: mutation,
            onToggleTodo: toggle,
            onDeletePlan: delete,
            onAgentPrompt: (prompt, {autoSend = false}) {
              prompts.add((prompt: prompt, autoSend: autoSend));
            },
          ),
        ),
      ),
    );
  }
}

BirthJourneyPlan _plan() {
  return const BirthJourneyPlan(
    id: 'birth-plan',
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
            title: '准备产检资料',
            priorityLabel: '重要',
            reason: '下次产检时集中确认',
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

Future<void> _setViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
