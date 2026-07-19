import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:momcozy_flutter_app/core/storage_migration/storage_migration_executor.dart';
import 'package:momcozy_flutter_app/features/status/domain/status_selection.dart';

abstract interface class StatusPreferenceStore {
  Future<StatusCareStage?> readCareStage();

  Future<void> writeCareStage(StatusCareStage stage);
}

class FlutterSecureStatusPreferenceStore implements StatusPreferenceStore {
  const FlutterSecureStatusPreferenceStore({
    required this.userId,
    this.storage = const FlutterSecureStorage(),
  });

  final String userId;
  final FlutterSecureStorage storage;

  @override
  Future<StatusCareStage?> readCareStage() async {
    final raw = await storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return StatusCareStage.fromStorage(jsonDecode(raw));
    } catch (_) {
      return StatusCareStage.fromStorage(raw);
    }
  }

  @override
  Future<void> writeCareStage(StatusCareStage stage) {
    return storage.write(
      key: storageKey,
      value: jsonEncode(stage.storageValue),
    );
  }

  String get storageKey {
    final scopedUserId = userId.trim().isEmpty ? 'anonymous' : userId.trim();
    return storageMigrationScopedKey(scopedUserId, 'status.careStage');
  }
}
