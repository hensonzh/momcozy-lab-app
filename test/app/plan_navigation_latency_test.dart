import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/plan/data/plan_api_repository.dart';
import 'package:momcozy_flutter_app/features/plan/presentation/plan_page.dart';

import '../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyPlanTestFonts);

  testWidgets('route shell warms the Plan dashboard after its first frame', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = _RecordingPlanTransport();
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      userId: 'plan-latency-user',
      babyId: 'plan-latency-baby',
      now: () => DateTime(2026, 10, 22),
    );

    await tester.pumpWidget(
      MomCozyRuntimeScope(
        apiRuntime: runtime,
        child: const MaterialApp(
          home: MomCozyRouteShell(location: '/', child: SizedBox()),
        ),
      ),
    );
    await tester.pump();

    expect(transport.getPaths, [planListEndpoint, planSessionListEndpoint]);
    expect(
      runtime.planRepository.snapshotFor(weekOf: runtime.now()),
      isNotNull,
    );

    await tester.pumpWidget(
      MomCozyRuntimeScope(
        apiRuntime: runtime,
        child: MaterialApp(
          home: PlanPage(repository: runtime.planRepository, now: runtime.now),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('plan-loading-view')), findsNothing);
    expect(find.text('No Plans Yet'), findsOneWidget);
  });
}

class _RecordingPlanTransport implements ApiJsonTransport {
  final List<String> getPaths = <String>[];

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    getPaths.add(path);
    return const {'items': <Object?>[]};
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => throw UnsupportedError('POST is not used by Plan dashboard loading.');
}
