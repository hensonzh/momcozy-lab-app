import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/preferences/volume_unit_preference.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/status/presentation/baby_status_cards.dart';
import 'package:momcozy_flutter_app/features/status/presentation/status_dashboard_controller.dart';

void main() {
  group('Baby status cards', () {
    testWidgets(
      'renders measured feeding data, unit changes, and card actions',
      (tester) async {
        await _setViewport(tester);
        final hostKey = GlobalKey<_CardsHostState>();
        await tester.pumpWidget(_CardsHost(key: hostKey));

        expect(find.text('加载中'), findsWidgets);
        hostKey.currentState!.publishFeeding(const [
          FeedingRecord(id: 'one', type: 'bottle', amountMl: 80),
          FeedingRecord(id: 'two', type: 'bottle', amountMl: 40),
          FeedingRecord(id: 'three', type: 'breast', amountMl: null),
        ]);
        await tester.pump();
        expect(find.text('120mL'), findsOneWidget);
        expect(find.text('3次'), findsOneWidget);

        hostKey.currentState!.setUnit(MomCozyVolumeUnit.ounces);
        await tester.pump();
        expect(find.text('4.1oz'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('status-baby-feed-info-button')),
        );
        await tester.tap(
          find.byKey(const ValueKey('status-growth-milestone-action')),
        );
        expect(hostKey.currentState!.infoTaps, 1);
        expect(hostKey.currentState!.milestoneTaps, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('prefills and saves complete growth measurements', (
      tester,
    ) async {
      await _setViewport(tester);
      final hostKey = GlobalKey<_CardsHostState>();
      await tester.pumpWidget(
        _CardsHost(
          key: hostKey,
          growthInitial: StatusResource.data([
            GrowthRecord(
              id: 'growth-existing',
              weightGram: 4200,
              heightCm: 54.5,
              headCm: 36.2,
              measuredAt: DateTime(2026, 7, 11, 8),
            ),
          ]),
        ),
      );

      expect(find.text('4.2kg'), findsOneWidget);
      expect(find.text('54.5cm'), findsOneWidget);
      expect(find.text('36.2cm'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('status-growth-record-action')),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('status-growth-weight-input')),
            )
            .controller
            ?.text,
        '4.2',
      );
      await tester.enterText(
        find.byKey(const ValueKey('status-growth-weight-input')),
        '4.35',
      );
      await tester.enterText(
        find.byKey(const ValueKey('status-growth-height-input')),
        '55.1',
      );
      await tester.enterText(
        find.byKey(const ValueKey('status-growth-head-input')),
        '36.8',
      );
      tester.testTextInput.hide();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('status-growth-save-button')));
      await tester.pumpAndSettle();

      expect(hostKey.currentState!.lastSave, (
        weightKg: 4.35,
        heightCm: 55.1,
        headCm: 36.8,
      ));
      expect(
        find.byKey(const ValueKey('status-growth-editor-dialog')),
        findsNothing,
      );
      expect(find.text('4.35kg'), findsOneWidget);
      expect(find.text('55.1cm'), findsOneWidget);
      expect(find.text('36.8cm'), findsOneWidget);
    });

    testWidgets('blocks incomplete saves and keeps failures retryable', (
      tester,
    ) async {
      await _setViewport(tester);
      final hostKey = GlobalKey<_CardsHostState>();
      await tester.pumpWidget(
        _CardsHost(
          key: hostKey,
          saveSucceeds: false,
          growthInitial: const StatusResource.data(<GrowthRecord>[]),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('status-growth-record-action')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('status-growth-save-button')));
      await tester.pump();
      expect(find.text('请填写完整的体重、身高与头围'), findsOneWidget);
      expect(hostKey.currentState!.lastSave, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('status-growth-weight-input')),
        '4.3',
      );
      await tester.enterText(
        find.byKey(const ValueKey('status-growth-height-input')),
        '55',
      );
      await tester.enterText(
        find.byKey(const ValueKey('status-growth-head-input')),
        '36.5',
      );
      tester.testTextInput.hide();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('status-growth-save-button')));
      await tester.pumpAndSettle();

      expect(find.text('保存失败，请稍后重试'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('status-growth-editor-dialog')),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, '保存修改'), findsOneWidget);
    });
  });
}

class _CardsHost extends StatefulWidget {
  const _CardsHost({
    super.key,
    this.growthInitial = const StatusResource.loading(),
    this.saveSucceeds = true,
  });

  final StatusResource<List<GrowthRecord>> growthInitial;
  final bool saveSucceeds;

  @override
  State<_CardsHost> createState() => _CardsHostState();
}

class _CardsHostState extends State<_CardsHost> {
  final feeding = ValueNotifier<StatusResource<List<FeedingRecord>>>(
    const StatusResource.loading(),
  );
  late final ValueNotifier<StatusResource<List<GrowthRecord>>> growth;
  final mutation = ValueNotifier<StatusMutationState>(
    const StatusMutationState.idle(),
  );
  final volumeUnit = ValueNotifier<MomCozyVolumeUnit>(
    MomCozyVolumeUnit.milliliters,
  );
  ({double? weightKg, double? heightCm, double? headCm})? lastSave;
  var infoTaps = 0;
  var milestoneTaps = 0;

  @override
  void initState() {
    super.initState();
    growth = ValueNotifier(widget.growthInitial);
  }

  void publishFeeding(List<FeedingRecord> records) {
    feeding.value = StatusResource.data(records);
  }

  void setUnit(MomCozyVolumeUnit unit) {
    volumeUnit.value = unit;
  }

  Future<bool> save({
    required double? weightKg,
    required double? heightCm,
    required double? headCm,
  }) async {
    lastSave = (weightKg: weightKg, heightCm: heightCm, headCm: headCm);
    mutation.value = const StatusMutationState.saving();
    if (!widget.saveSucceeds) {
      mutation.value = const StatusMutationState.error('保存失败，请稍后重试');
      return false;
    }
    growth.value = StatusResource.data([
      GrowthRecord(
        id: 'growth-saved',
        weightGram: (weightKg! * 1000).round(),
        heightCm: heightCm,
        headCm: headCm,
        measuredAt: DateTime(2026, 7, 11, 12),
      ),
    ]);
    mutation.value = const StatusMutationState.success('成长指标已保存');
    return true;
  }

  @override
  void dispose() {
    feeding.dispose();
    growth.dispose();
    mutation.dispose();
    volumeUnit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: momCozyTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 190,
            child: Row(
              children: [
                Expanded(
                  child: BabyFeedingCard(
                    records: feeding,
                    volumeUnit: volumeUnit,
                    onInfoTap: () => infoTaps += 1,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BabyGrowthSummaryCard(
                    records: growth,
                    mutation: mutation,
                    onSave: save,
                    onMilestoneTap: () => milestoneTaps += 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _setViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
