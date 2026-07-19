import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/storage_migration/storage_migration_executor.dart';
import 'package:momcozy_flutter_app/core/storage_migration/storage_migration_plan.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('StorageMigrationExecutor', () {
    test(
      'applies a plan into user-scoped storage and writes version last',
      () async {
        final fixture = readFixtureMap(
          'storage_migration/p0_valid_core_state.json',
        );
        final plan = buildStorageMigrationPlan(fixture);
        final store = _MemoryMigrationStore();

        final result = await StorageMigrationExecutor(
          store,
        ).applyPlanIfNeeded(plan);

        expect(result.applied, isTrue);
        expect(result.previousVersion, isNull);
        expect(result.migrationVersion, currentStorageMigrationVersion);
        expect(store.version, currentStorageMigrationVersion);
        expect(store.versionWriteIndex, store.operations.length - 1);
        expect(
          store.values[storageMigrationScopedKey(
            'demo-user-001',
            'runtime.userId',
          )],
          'demo-user-001',
        );
        expect(
          store.values[storageMigrationScopedKey(
            'demo-user-001',
            'agent.chatMessages',
          )],
          hasLength(3),
        );
        expect(
          store.values[storageMigrationScopedKey(
            'demo-user-001',
            'deviceRepository',
          )],
          containsPair('L', isA<Map>()),
        );
        expect(
          store.removedLegacyKeys,
          contains('sessionStorage:mai_agent_conversation_id'),
        );
      },
    );

    test(
      'skips when an equal or newer migration version already exists',
      () async {
        final fixture = readFixtureMap(
          'storage_migration/p0_valid_core_state.json',
        );
        final plan = buildStorageMigrationPlan(fixture);
        final store = _MemoryMigrationStore(
          version: currentStorageMigrationVersion,
        );

        final result = await StorageMigrationExecutor(
          store,
        ).applyPlanIfNeeded(plan);

        expect(result.applied, isFalse);
        expect(result.previousVersion, currentStorageMigrationVersion);
        expect(store.values, isEmpty);
        expect(store.removedLegacyKeys, isEmpty);
      },
    );

    test(
      'does not persist migration version when a target write fails',
      () async {
        final fixture = readFixtureMap(
          'storage_migration/p0_valid_core_state.json',
        );
        final plan = buildStorageMigrationPlan(fixture);
        final store = _MemoryMigrationStore(
          failOnKey: storageMigrationScopedKey(
            'demo-user-001',
            'agent.chatMessages',
          ),
        );

        await expectLater(
          StorageMigrationExecutor(store).applyPlanIfNeeded(plan),
          throwsStateError,
        );

        expect(store.version, isNull);
        expect(store.operations, isNot(contains('writeVersion:1')));
      },
    );

    test('normalizes raw legacy exports and reports unhandled keys', () async {
      final store = _MemoryMigrationStore();

      final result = await StorageMigrationExecutor(store).applyInputIfNeeded({
        'localStorage': {
          'mai_debug_user_id': 'legacy-user',
          'unknown_legacy_key': 'left-over',
        },
        'sessionStorage': {'mai_agent_conversation_id': 'session-conv'},
      });

      expect(result.applied, isTrue);
      expect(result.unhandledLegacyKeys['localStorage'], [
        'unknown_legacy_key',
      ]);
      expect(
        store.values[storageMigrationScopedKey(
          'legacy-user',
          'agent.conversationId',
        )],
        'session-conv',
      );
    });
  });
}

class _MemoryMigrationStore implements StorageMigrationTargetStore {
  _MemoryMigrationStore({this.version, this.failOnKey});

  int? version;
  final String? failOnKey;
  final values = <String, Object?>{};
  final removedLegacyKeys = <String>[];
  final operations = <String>[];
  int? versionWriteIndex;

  @override
  Future<int?> readMigrationVersion() async => version;

  @override
  Future<void> writeMigrationValue(String key, Object? value) async {
    if (key == failOnKey) throw StateError('failed write $key');
    operations.add('write:$key');
    values[key] = value;
  }

  @override
  Future<void> writeMigrationVersion(int version) async {
    operations.add('writeVersion:$version');
    versionWriteIndex = operations.length - 1;
    this.version = version;
  }

  @override
  Future<void> removeLegacyKey(String bucket, String key) async {
    operations.add('remove:$bucket:$key');
    removedLegacyKeys.add('$bucket:$key');
  }
}
