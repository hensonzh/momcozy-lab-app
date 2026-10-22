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
    expect(find.textContaining('正在等待已验证的分析结果'), findsOneWidget);
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
}

Widget _card(StoolCardState analysis) => MaterialApp(
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
        onAbandon: () {},
      ),
    ),
  ),
);
