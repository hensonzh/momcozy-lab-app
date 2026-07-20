import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:momcozy_flutter_app/core/storage/user_scoped_storage_key.dart';

const _millilitersToOunces = 0.033814;

enum MomCozyVolumeUnit {
  milliliters('mL'),
  ounces('oz');

  const MomCozyVolumeUnit(this.storageValue);

  final String storageValue;

  String formatMilliliters(double milliliters) {
    final safe = milliliters < 0 ? 0.0 : milliliters;
    if (this == MomCozyVolumeUnit.ounces) {
      return (safe * _millilitersToOunces).toStringAsFixed(1);
    }
    return safe.round().toString();
  }

  /// Converts a UI value in this unit to the canonical whole-milliliter value.
  ///
  /// Valid values are rounded to the nearest mL; because negative input is
  /// rejected, an exact half-mL rounds up. Invalid or overflowing input returns
  /// `null` so callers cannot accidentally persist it as zero.
  int? toCanonicalMilliliters(double value) {
    if (!value.isFinite || value < 0) return null;
    final milliliters = this == MomCozyVolumeUnit.ounces
        ? value / _millilitersToOunces
        : value;
    if (!milliliters.isFinite) return null;
    return milliliters.round();
  }

  static MomCozyVolumeUnit? fromStorage(Object? value) {
    return switch (value) {
      'mL' => MomCozyVolumeUnit.milliliters,
      'oz' => MomCozyVolumeUnit.ounces,
      _ => null,
    };
  }
}

abstract interface class VolumeUnitPreferenceStore {
  Future<MomCozyVolumeUnit?> read();

  Future<void> write(MomCozyVolumeUnit unit);
}

class FlutterSecureVolumeUnitPreferenceStore
    implements VolumeUnitPreferenceStore {
  const FlutterSecureVolumeUnitPreferenceStore({
    required this.userId,
    this.storage = const FlutterSecureStorage(),
  });

  final String userId;
  final FlutterSecureStorage storage;

  @override
  Future<MomCozyVolumeUnit?> read() async {
    final raw = await storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return MomCozyVolumeUnit.fromStorage(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(MomCozyVolumeUnit unit) {
    return storage.write(key: storageKey, value: jsonEncode(unit.storageValue));
  }

  String get storageKey {
    final scopedUserId = userId.trim().isEmpty ? 'anonymous' : userId.trim();
    return userScopedStorageKey(scopedUserId, 'preferences.volumeUnit');
  }
}
