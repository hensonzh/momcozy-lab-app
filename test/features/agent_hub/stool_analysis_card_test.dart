import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/chat_first_poop_task.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/stool_analysis.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/chat_first_poop_task.dart';

void main() {
  testWidgets('committed progress restores before a terminal failure', (
    tester,
  ) async {
    final created = const StoolCardState(analysisId: 'synthetic').apply(
      const StoolAnalysisEvent(
        analysisId: 'synthetic',
        sequence: 1,
        type: StoolAnalysisEventType.cardCreated,
      ),
    );
    final progress = created.apply(
      const StoolAnalysisEvent(
        analysisId: 'synthetic',
        sequence: 2,
        type: StoolAnalysisEventType.started,
      ),
    );
    expect(
      StoolCardState.fromMap(progress.toMap())!.status,
      StoolAnalysisStatus.running,
    );
    await tester.pumpWidget(_card(progress));
    expect(find.text('专项服务正在处理照片，请稍候…'), findsOneWidget);
    expect(find.textContaining('风险'), findsNothing);
    final terminal = progress.apply(
      const StoolAnalysisEvent(
        analysisId: 'synthetic',
        sequence: 3,
        type: StoolAnalysisEventType.failed,
      ),
    );
    await tester.pumpWidget(_card(terminal));
    expect(find.text('专项分析未完成，请稍后重试。'), findsOneWidget);
    expect(
      () => terminal.apply(
        const StoolAnalysisEvent(
          analysisId: 'synthetic',
          sequence: 4,
          type: StoolAnalysisEventType.started,
        ),
      ),
      throwsFormatException,
    );
  });

  testWidgets('committed card shell appears before any clinical conclusion', (
    tester,
  ) async {
    final created = const StoolCardState(analysisId: 'synthetic').apply(
      const StoolAnalysisEvent(
        analysisId: 'synthetic',
        sequence: 1,
        type: StoolAnalysisEventType.cardCreated,
      ),
    );
    await tester.pumpWidget(_card(created));
    expect(
      find.byKey(const ValueKey('chat-first-poop-analysis-card')),
      findsOneWidget,
    );
    expect(find.textContaining('正在等待分析'), findsOneWidget);
    expect(find.textContaining('风险'), findsNothing);
    expect(find.textContaining('医学结论'), findsNothing);
    await tester.pumpWidget(
      _card(
        created.apply(
          const StoolAnalysisEvent(
            analysisId: 'synthetic',
            sequence: 2,
            type: StoolAnalysisEventType.failed,
          ),
        ),
      ),
    );
    expect(find.text('专项分析未完成，请稍后重试。'), findsOneWidget);
  });

  testWidgets('validated fields stream into the card before completion', (
    tester,
  ) async {
    var state = const StoolCardState(analysisId: 'analysis')
        .apply(
          const StoolAnalysisEvent(
            analysisId: 'analysis',
            sequence: 1,
            type: StoolAnalysisEventType.cardCreated,
          ),
        )
        .apply(
          const StoolAnalysisEvent(
            analysisId: 'analysis',
            sequence: 2,
            type: StoolAnalysisEventType.started,
          ),
        );
    state = state.apply(
      StoolAnalysisEvent.fromJson({
        'analysis_id': 'analysis',
        'sequence': 3,
        'schema_version': 'stool.events.v1',
        'event_type': 'stool.field.ready',
        'payload': {'field': 'color', 'value': 'yellow'},
      }),
    );
    state = state.apply(
      StoolAnalysisEvent.fromJson({
        'analysis_id': 'analysis',
        'sequence': 4,
        'schema_version': 'stool.events.v1',
        'event_type': 'stool.field.ready',
        'payload': {'field': 'consistency', 'value': 'mushy'},
      }),
    );
    await tester.pumpWidget(_card(state));
    expect(find.text('黄色'), findsOneWidget);
    expect(find.text('糊状'), findsOneWidget);
    expect(find.text('正在生成分析结果…'), findsOneWidget);
  });

  testWidgets(
    'completed result is visible and enables same-analysis follow-up',
    (tester) async {
      var followed = false;
      var state = const StoolCardState(analysisId: 'analysis')
          .apply(
            const StoolAnalysisEvent(
              analysisId: 'analysis',
              sequence: 1,
              type: StoolAnalysisEventType.cardCreated,
            ),
          )
          .apply(
            const StoolAnalysisEvent(
              analysisId: 'analysis',
              sequence: 2,
              type: StoolAnalysisEventType.started,
            ),
          );
      final fields = <Object?>[
        'yellow',
        'mushy',
        ['none'],
        'routine',
        '从照片看为常见黄色糊状外观。',
        '继续观察宝宝整体状态和后续排便变化。',
      ];
      final names = [
        'color',
        'consistency',
        'findings',
        'risk_level',
        'summary',
        'care_advice',
      ];
      for (var index = 0; index < names.length; index++) {
        state = state.apply(
          StoolAnalysisEvent.fromJson({
            'analysis_id': 'analysis',
            'sequence': index + 3,
            'schema_version': 'stool.events.v1',
            'event_type': 'stool.field.ready',
            'payload': {'field': names[index], 'value': fields[index]},
          }),
        );
      }
      state = state.apply(
        StoolAnalysisEvent.fromJson({
          'analysis_id': 'analysis',
          'sequence': 9,
          'schema_version': 'stool.events.v1',
          'event_type': 'stool.analysis.completed',
          'payload': {
            'result': {
              'schema_version': 'stool.result.v1',
              'assessment_status': 'assessed',
              'color': 'yellow',
              'consistency': 'mushy',
              'findings': ['none'],
              'risk_level': 'routine',
              'summary': fields[4],
              'care_advice': fields[5],
              'uncertainties': [],
              'photo_observations': [
                {
                  'position': 0,
                  'image_quality': 'adequate',
                  'color': 'yellow',
                  'consistency': 'mushy',
                  'findings': ['none'],
                  'note': '主体清楚。',
                },
              ],
            },
          },
        }),
      );
      await tester.pumpWidget(_card(state, onFollowup: () => followed = true));
      expect(find.text('常规观察'), findsOneWidget);
      expect(find.text(fields[4]! as String), findsOneWidget);
      expect(find.text(fields[5]! as String), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chat-first-poop-followup')));
      expect(followed, isTrue);
    },
  );
}

Widget _card(StoolCardState analysis, {VoidCallback? onFollowup}) =>
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ChatFirstPoopTaskCard(
            status: ChatFirstPoopTaskStatus.completed,
            canInteract: false,
            canSubmit: false,
            analysisState: analysis,
            onPick: (_) {},
            onSubmit: () {},
            onRemove: (_) {},
            onFollowup: onFollowup,
          ),
        ),
      ),
    );
