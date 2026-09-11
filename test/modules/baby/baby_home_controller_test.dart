import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'baby_profile_controller_test.dart';

class HomeProfiles extends Profiles {
  List<BabyProfile> values = const [
    BabyProfile(id: 'first', name: 'Luna', version: 1),
    BabyProfile(id: 'second', name: 'Milo', version: 1),
  ];
  @override
  Future<List<BabyProfile>> list() async => values;
}

class HomeRecords implements BabyRecordRepository {
  final pending = <String, Completer<BabyRecordPage>>{};
  int calls = 0;
  @override
  Future<List<BabyGrowthRecord>> latestGrowth(String babyId) async => [];
  @override
  Future<BabyRecordPage> list({
    required String babyId,
    required LocalDate startDate,
    required LocalDate endDate,
    required String timezone,
    BabyRecordKind? kind,
    int offset = 0,
    int limit = 100,
  }) {
    calls++;
    return (pending[babyId] ??= Completer<BabyRecordPage>()).future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.utc(2026, 9, 8, 10);
  test(
    'late response from previous baby cannot replace the selected baby or its record state',
    () async {
      final records = HomeRecords();
      final controller = BabyHomeController(
        profileRepository: HomeProfiles(),
        recordRepository: records,
        timezoneProvider: () async => 'Asia/Shanghai',
        now: () => now,
      );
      final first = controller.load();
      await Future<void>.delayed(Duration.zero);
      expect(controller.baby!.id, 'first');
      final second = controller.select('second');
      await Future<void>.delayed(Duration.zero);
      expect(controller.summary, isNull);
      records.pending['second']!.complete(
        BabyRecordPage(
          items: [
            BabyFeedingRecord(
              id: 'feed',
              babyId: 'second',
              occurredAt: now,
              method: BabyFeedingMethod.expressedMilk,
              volumeMl: 40,
            ),
          ],
          total: 1,
          offset: 0,
          limit: 200,
          serverTime: now,
        ),
      );
      await second;
      records.pending['first']!.completeError(
        const ProductFailure(ProductFailureKind.offline),
      );
      await first;
      expect(controller.baby!.id, 'second');
      expect(controller.summary!.measuredIntakeMl, 40);
      expect(controller.recentRecords.failure, isNull);
      controller.dispose();
    },
  );
  test('an empty account does not request or invent a demo baby', () async {
    final profiles = HomeProfiles()..values = [];
    final records = HomeRecords();
    final controller = BabyHomeController(
      profileRepository: profiles,
      recordRepository: records,
      timezoneProvider: () async => 'UTC',
      now: () => now,
      selectedBabyId: 'stale-selection',
    );
    await controller.load();
    expect(controller.baby, isNull);
    expect(controller.profiles.value, isEmpty);
    expect(records.calls, 0);
    controller.dispose();
  });
}
