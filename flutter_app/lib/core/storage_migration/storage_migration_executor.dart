import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:momcozy_flutter_app/core/storage_migration/storage_migration_dry_run.dart';
import 'package:momcozy_flutter_app/core/storage_migration/storage_migration_plan.dart';

const currentStorageMigrationVersion = 1;
const storageMigrationVersionKey = 'momcozy.storageMigration.version';
const _targetPrefix = 'momcozy.storageMigration.v1';

String storageMigrationScopedKey(String userId, String key) {
  return '$_targetPrefix.user.${Uri.encodeComponent(userId)}.$key';
}

abstract interface class StorageMigrationTargetStore {
  Future<int?> readMigrationVersion();

  Future<void> writeMigrationValue(String key, Object? value);

  Future<void> writeMigrationVersion(int version);

  Future<void> removeLegacyKey(String bucket, String key);
}

class StorageMigrationApplyResult {
  const StorageMigrationApplyResult({
    required this.applied,
    required this.previousVersion,
    required this.migrationVersion,
    required this.writtenKeyCount,
    required this.deletedLegacyKeyCount,
    required this.diagnostics,
    required this.unhandledLegacyKeys,
  });

  final bool applied;
  final int? previousVersion;
  final int migrationVersion;
  final int writtenKeyCount;
  final int deletedLegacyKeyCount;
  final List<Map<String, Object?>> diagnostics;
  final Map<String, List<String>> unhandledLegacyKeys;
}

class StorageMigrationExecutor {
  const StorageMigrationExecutor(this.store);

  final StorageMigrationTargetStore store;

  Future<StorageMigrationApplyResult> applyInputIfNeeded(
    Map<String, Object?> input, {
    Map<String, Object?> context = const <String, Object?>{},
    String source = 'app-bootstrap',
  }) async {
    final normalized = normalizeStorageMigrationInput(input);
    final fixtureContext = Map<String, Object?>.from(
      (normalized['context'] is Map ? normalized['context'] as Map : const {})
          .cast<String, Object?>(),
    )..addAll(context);
    final fixture = {...normalized, 'context': fixtureContext};
    final report = buildStorageMigrationDryRunReport(fixture, source: source);
    return applyPlanIfNeeded(
      report.plan,
      unhandledLegacyKeys: report.unhandledLegacyKeys,
    );
  }

  Future<StorageMigrationApplyResult> applyPlanIfNeeded(
    StorageMigrationPlan plan, {
    Map<String, List<String>> unhandledLegacyKeys = const {},
  }) async {
    final previousVersion = await store.readMigrationVersion();
    if (previousVersion != null && previousVersion >= plan.migrationVersion) {
      return StorageMigrationApplyResult(
        applied: false,
        previousVersion: previousVersion,
        migrationVersion: plan.migrationVersion,
        writtenKeyCount: 0,
        deletedLegacyKeyCount: 0,
        diagnostics: plan.diagnostics,
        unhandledLegacyKeys: unhandledLegacyKeys,
      );
    }

    final userId = _migrationUserId(plan);
    var writtenKeyCount = 0;
    for (final entry in plan.scopedKeyValue.entries) {
      await store.writeMigrationValue(
        storageMigrationScopedKey(userId, entry.key),
        entry.value,
      );
      writtenKeyCount += 1;
    }

    writtenKeyCount += await _writeIfNotEmpty(
      userId,
      'agent.chatMessages',
      plan.chatMessages,
    );
    writtenKeyCount += await _writeIfNotNull(
      userId,
      'calibration',
      plan.calibration,
    );
    writtenKeyCount += await _writeIfNotEmpty(
      userId,
      'deviceRepository',
      plan.deviceRepository,
    );
    writtenKeyCount += await _writeIfNotEmpty(
      userId,
      'localHistory',
      plan.localHistory,
    );
    writtenKeyCount += await _writeIfNotEmpty(
      userId,
      'routeIntentQueue',
      plan.routeIntentQueue,
    );
    writtenKeyCount += await _writeIfNotEmpty(
      userId,
      'backgroundJobQueue',
      plan.backgroundJobQueue,
    );
    writtenKeyCount += await _writeIfNotNull(
      userId,
      'pumpSessionState',
      plan.pumpSessionState,
    );
    writtenKeyCount += await _writeIfNotEmpty(
      userId,
      'nativeServiceStore',
      plan.nativeServiceStore,
    );

    var deletedLegacyKeyCount = 0;
    for (final entry in plan.deleteLegacyKeys.entries) {
      for (final key in entry.value) {
        await store.removeLegacyKey(entry.key, key);
        deletedLegacyKeyCount += 1;
      }
    }

    await store.writeMigrationVersion(plan.migrationVersion);
    return StorageMigrationApplyResult(
      applied: true,
      previousVersion: previousVersion,
      migrationVersion: plan.migrationVersion,
      writtenKeyCount: writtenKeyCount,
      deletedLegacyKeyCount: deletedLegacyKeyCount,
      diagnostics: plan.diagnostics,
      unhandledLegacyKeys: unhandledLegacyKeys,
    );
  }

  Future<int> _writeIfNotNull(String userId, String key, Object? value) async {
    if (value == null) return 0;
    await store.writeMigrationValue(
      storageMigrationScopedKey(userId, key),
      value,
    );
    return 1;
  }

  Future<int> _writeIfNotEmpty(String userId, String key, Object? value) async {
    if (value is Map && value.isEmpty) return 0;
    if (value is Iterable && value.isEmpty) return 0;
    return _writeIfNotNull(userId, key, value);
  }
}

class FlutterSecureStorageMigrationTargetStore
    implements StorageMigrationTargetStore {
  const FlutterSecureStorageMigrationTargetStore({
    this.storage = const FlutterSecureStorage(),
  });

  final FlutterSecureStorage storage;

  @override
  Future<int?> readMigrationVersion() async {
    return int.tryParse(
      await storage.read(key: storageMigrationVersionKey) ?? '',
    );
  }

  @override
  Future<void> writeMigrationValue(String key, Object? value) {
    return storage.write(key: key, value: jsonEncode(value));
  }

  @override
  Future<void> writeMigrationVersion(int version) {
    return storage.write(
      key: storageMigrationVersionKey,
      value: version.toString(),
    );
  }

  @override
  Future<void> removeLegacyKey(String bucket, String key) {
    return storage.write(
      key: '$_targetPrefix.legacyDelete.$bucket.${Uri.encodeComponent(key)}',
      value: '1',
    );
  }
}

String _migrationUserId(StorageMigrationPlan plan) {
  final userId = plan.scopedKeyValue['runtime.userId'];
  if (userId is String && userId.trim().isNotEmpty) return userId.trim();
  return 'anonymous';
}
