import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/mom_bottom_navigation.dart';
import 'package:momcozy_flutter_app/modules/mom/application/me_controller.dart';
import 'package:momcozy_flutter_app/modules/mom/domain/me_experience.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_home_page.dart';

import '../../support/momcozy_test_fonts.dart';

final _now = DateTime(2026, 9, 20, 15);

class _MeHomeRepository implements MeRepository {
  _MeHomeRepository({MeState? initial}) : state = initial ?? _emptyState;

  static const _emptyState = MeState(
    profile: {'preferred_name': 'Mia', 'actual_delivery_date': '2026-08-30'},
  );

  MeState state;

  @override
  Future<MeState> load(DateTime _) async => state;

  @override
  Future<Map<String, Object?>> saveProfile(Map<String, Object?> value) async {
    state = state.copyWith(profile: {...state.profile, ...value});
    return state.profile;
  }

  @override
  Future<MeConcern> saveConcern(MeConcern value) async => value;

  @override
  Future<List<MeMetric>> saveOrder(List<MeMetric> value) async => value;

  @override
  Future<MeObservation> saveRecord(MeObservation value) async => value;
}

MeController _controller(_MeHomeRepository repository) => MeController(
  repository: repository,
  now: () => _now,
  state: repository.state,
);

Future<void> _pumpHome(
  WidgetTester tester,
  MeController controller, {
  required Size size,
  required double scale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(scale),
        disableAnimations: true,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xfffbf8f4),
          body: MeHomePage(
            controller: controller,
            onAsk: (_) {},
            onSharedRecord: (_, _) async {},
          ),
          bottomNavigationBar: const MomCozyBottomNavigation(location: '/me'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadMomCozyTestFonts);

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('Me home empty state matches Figma at ${width.toInt()}px', (
      tester,
    ) async {
      final repository = _MeHomeRepository();
      final controller = _controller(repository);
      await _pumpHome(tester, controller, size: Size(width, 844), scale: 1);
      expect(find.text('选择想改善的事'), findsOneWidget);
      expect(find.text('待记录'), findsNWidgets(4));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/me_home/me-home-empty-${width.toInt()}.png',
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Me home active concern state matches Figma', (tester) async {
    final repository = _MeHomeRepository(
      initial: _MeHomeRepository._emptyState.copyWith(
        concerns: [
          const MeConcern(id: 'comfort', issues: [MeIssue.comfort]),
        ],
      ),
    );
    final controller = _controller(repository);
    await _pumpHome(tester, controller, size: const Size(393, 844), scale: 1);
    expect(find.text('喂奶或泵奶时不舒服'), findsOneWidget);
    expect(find.text('我的关注 ›'), findsOneWidget);
    expect(find.text('待记录'), findsNWidgets(6));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/me_home/me-home-active-393.png'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
