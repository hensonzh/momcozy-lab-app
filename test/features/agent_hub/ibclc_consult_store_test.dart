import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/agent_hub/data/ibclc_consult_store.dart';
import 'package:app/features/agent_hub/domain/ibclc_consult.dart';

void main() {
  test(
    'IBCLC consult store persists completions by stable consult id',
    () async {
      final persistence = _MemoryIbclcPersistence();
      final store = IbclcConsultStore(
        persistence: persistence,
        now: () => DateTime.utc(2026, 7, 11, 9, 30),
      );
      const routeState = IbclcConsultRouteState(
        consultId: 'consult-explicit',
        sourceArtifactId: 'artifact-1',
        threadId: 'thread-1',
        runId: 'run-1',
        returnPath: '/',
        returnScrollOffset: 248,
        consultantName: 'Lin Zhao',
        reason: '含乳疼痛',
        feedingContext: '左侧喂养后疼痛',
      );

      store.beginConsult(routeState);
      await store.markCompleted(routeState);

      expect(store.isCompleted('consult-explicit'), isTrue);
      expect(store.lastCompletedRouteState, routeState);
      expect(persistence.writes.single.single.consultId, 'consult-explicit');

      final restored = IbclcConsultStore(
        persistence: persistence,
        now: () => DateTime.utc(2026, 7, 12),
      );
      await restored.restore();

      expect(restored.isCompleted('consult-explicit'), isTrue);
      expect(restored.lastCompletedRouteState, isNull);
    },
  );

  test('IBCLC route state rejects unsafe return paths', () {
    final state = IbclcConsultRouteState.fromRoute(
      extra: null,
      uri: Uri.parse(
        '/ibclc-chat.html?consult_id=consult-2&thread_id=thread-2&return_to=https://evil.example',
      ),
    );

    expect(state.consultId, 'consult-2');
    expect(state.threadId, 'thread-2');
    expect(state.returnPath, '/');
  });

  test('IBCLC fallback consult ids match the legacy stable hash', () {
    expect(stableIbclcConsultId('message:0'), 'ibclc_553b237e');
    expect(
      stableIbclcConsultId('message:0'),
      isNot(stableIbclcConsultId('message:1')),
    );
  });
}

class _MemoryIbclcPersistence implements IbclcConsultPersistence {
  List<IbclcConsultCompletion> values = const [];
  final List<List<IbclcConsultCompletion>> writes = [];

  @override
  Future<List<IbclcConsultCompletion>> read() async => values;

  @override
  Future<void> write(List<IbclcConsultCompletion> completions) async {
    values = List<IbclcConsultCompletion>.from(completions);
    writes.add(values);
  }
}
