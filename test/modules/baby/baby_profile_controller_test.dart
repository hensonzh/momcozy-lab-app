import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_profile_controller.dart';

class Profiles implements BabyProfileRepository {
  final writes = <BabyProfile>[];
  final keys = <String>[];
  ProductFailure? nextFailure;
  @override
  Future<List<BabyProfile>> list() async => const [
    BabyProfile(id: 'baby', name: '更新后的名字', sex: BabySex.female, version: 3),
  ];
  @override
  Future<BabyProfile> save(
    BabyProfile profile, {
    required String timezone,
    required String idempotencyKey,
  }) async {
    writes.add(profile);
    keys.add(idempotencyKey);
    final failure = nextFailure;
    nextFailure = null;
    if (failure != null) throw failure;
    return BabyProfile(
      id: profile.id.isEmpty ? 'baby' : profile.id,
      name: profile.name,
      birthDate: profile.birthDate,
      sex: profile.sex,
      feedingMode: profile.feedingMode,
      version: (profile.version ?? 0) + 1,
    );
  }
}

void main() {
  test(
    'failed creation retains its draft and unchanged retries use the same key',
    () async {
      final repo = Profiles()
        ..nextFailure = const ProductFailure(ProductFailureKind.unavailable);
      final controller = BabyProfileController(
        repository: repo,
        timezone: 'Pacific/Kiritimati',
        now: () => DateTime.utc(2026, 9, 8, 14, 30),
      );
      controller.setName('Luna');
      controller.setSex(BabySex.female);
      controller.setBirthDate(LocalDate(2026, 9, 9));
      expect(await controller.save(), isNull);
      expect(controller.uncertain, isTrue);
      expect(controller.editable, isTrue);
      final saved = await controller.save();
      expect(saved!.name, 'Luna');
      expect(repo.keys[0], repo.keys[1]);
      expect(repo.writes.last.birthDate, LocalDate(2026, 9, 9));
      controller.dispose();
    },
  );
  test(
    'version conflict keeps the draft until the user reloads the current profile',
    () async {
      final repo = Profiles()
        ..nextFailure = const ProductFailure(ProductFailureKind.conflict);
      final controller = BabyProfileController(
        repository: repo,
        timezone: 'UTC',
        now: () => DateTime.utc(2026, 9, 8),
        initial: const BabyProfile(
          id: 'baby',
          name: '旧名字',
          sex: BabySex.female,
          version: 1,
        ),
        deliveryDate: LocalDate(2026, 8, 22),
      );
      controller.setName('本次修改');
      expect(await controller.save(), isNull);
      expect(controller.name, '本次修改');
      await controller.reload();
      expect(controller.name, '更新后的名字');
      controller.setName('再次修改');
      await controller.save();
      expect(repo.writes.last.version, 3);
      controller.dispose();
    },
  );
}
