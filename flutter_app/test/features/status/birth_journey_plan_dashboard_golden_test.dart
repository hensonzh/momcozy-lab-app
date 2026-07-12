import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/features/status/domain/birth_journey_plan.dart';
import 'package:momcozy_flutter_app/features/status/presentation/birth_journey_plan_dashboard.dart';
import 'package:momcozy_flutter_app/features/status/presentation/status_dashboard_controller.dart';

import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  for (final viewport in _viewports) {
    for (final state in _states) {
      testWidgets('${state.label} matches ${viewport.label}', (tester) async {
        await _setViewport(tester, viewport.size);
        final plan = ValueNotifier<StatusResource<BirthJourneyPlan?>>(
          state.resource(),
        );
        final mutation = ValueNotifier<StatusMutationState>(
          const StatusMutationState.idle(),
        );
        addTearDown(plan.dispose);
        addTearDown(mutation.dispose);

        await tester.pumpWidget(
          RepaintBoundary(
            key: _surfaceKey,
            child: ColoredBox(
              color: const Color(0xfffffbf8),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: momCozyTheme(),
                home: Scaffold(
                  backgroundColor: const Color(0xfffffbf8),
                  body: SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: BirthJourneyPlanDashboard(
                        plan: plan,
                        mutation: mutation,
                        onDeletePlan: () async => true,
                        onToggleTodo: (itemId, completed) async => true,
                        onRetryPlan: () async {},
                        onAgentPrompt: (_, {autoSend = false}) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (state.openDetails) {
          await tester.tap(
            find.byKey(
              const ValueKey('status-birth-journey-detail-button'),
            ),
          );
          await tester.pumpAndSettle();
        }

        expect(find.text('孕期计划'), findsAtLeastNWidgets(1));
        expect(find.text(state.expectedText), findsAtLeastNWidgets(1));
        if (state.hasNoCreateAction) {
          expect(find.text('制定孕期计划'), findsNothing);
        }
        if (state.hasNoDetailAction) {
          expect(
            find.byKey(
              const ValueKey('status-birth-journey-detail-button'),
            ),
            findsNothing,
          );
        }
        await expectLater(
          find.byKey(_surfaceKey),
          matchesGoldenFile(viewport.goldenPath(state.fileName)),
        );
      });
    }
  }
}

const _surfaceKey = ValueKey('status-pregnancy-plan-ready-golden');

final _states = [
  _GoldenState(
    label: 'cold pregnancy plan skeleton',
    fileName: 'status_pregnancy_plan_cold_skeleton.png',
    expectedText: '正在加载孕期计划',
    resource: () => const StatusResource.loading(),
    hasNoCreateAction: true,
    hasNoDetailAction: true,
  ),
  _GoldenState(
    label: 'ready pregnancy plan card',
    fileName: 'status_pregnancy_plan_ready_card.png',
    expectedText: '准备产检资料',
    resource: () => StatusResource.data(_readyPlan()),
    hasNoCreateAction: true,
  ),
  _GoldenState(
    label: 'stale pregnancy plan card',
    fileName: 'status_pregnancy_plan_stale_card.png',
    expectedText: '计划可能不是最新内容',
    resource: () => StatusResource.error(
      StateError('refresh unavailable'),
      previous: _readyPlan(),
    ),
    hasNoCreateAction: true,
  ),
  _GoldenState(
    label: 'pregnancy plan error without cache',
    fileName: 'status_pregnancy_plan_error_card.png',
    expectedText: '孕期计划暂时无法同步，请稍后重试',
    resource: () => StatusResource.error(StateError('unavailable')),
    hasNoCreateAction: true,
    hasNoDetailAction: true,
  ),
  _GoldenState(
    label: 'pregnancy plan detail sheet',
    fileName: 'status_pregnancy_plan_detail_sheet.png',
    expectedText: '删除计划',
    resource: () => StatusResource.data(_readyPlan()),
    openDetails: true,
    hasNoCreateAction: true,
  ),
];

class _GoldenState {
  const _GoldenState({
    required this.label,
    required this.fileName,
    required this.expectedText,
    required this.resource,
    this.openDetails = false,
    this.hasNoCreateAction = false,
    this.hasNoDetailAction = false,
  });

  final String label;
  final String fileName;
  final String expectedText;
  final StatusResource<BirthJourneyPlan?> Function() resource;
  final bool openDetails;
  final bool hasNoCreateAction;
  final bool hasNoDetailAction;
}

const _viewports = [
  _GoldenViewport(
    label: '360x800',
    size: Size(360, 800),
    directory: 'narrow_360x800',
  ),
  _GoldenViewport(label: '390x844', size: Size(390, 844)),
  _GoldenViewport(
    label: '430x932',
    size: Size(430, 932),
    directory: 'large_430x932',
  ),
];

class _GoldenViewport {
  const _GoldenViewport({
    required this.label,
    required this.size,
    this.directory,
  });

  final String label;
  final Size size;
  final String? directory;

  String goldenPath(String fileName) {
    final value = directory;
    if (value == null) return '../../goldens/status_states/$fileName';
    return '../../goldens/status_states/$value/$fileName';
  }
}

BirthJourneyPlan _readyPlan() {
  return const BirthJourneyPlan(
    id: 'plan-ready',
    version: 4,
    title: '孕期计划',
    summary: '围绕产检、待产和入院做准备',
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
            authoritativeItemId: 'todo-current',
            title: '准备产检资料',
            priorityLabel: '重要',
            reason: '下次产检时集中确认近期检查变化',
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

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
