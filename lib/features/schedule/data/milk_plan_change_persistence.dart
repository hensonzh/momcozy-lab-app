import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app/features/schedule/domain/milk_plan_change_store.dart';

class FlutterSecureMilkPlanChangePersistence
    implements MilkPlanChangePersistence {
  const FlutterSecureMilkPlanChangePersistence({
    required this.userId,
    this.storage = const FlutterSecureStorage(),
    this.namespace = 'momcozy.milkPlanChange.v1',
  });

  final String userId;
  final FlutterSecureStorage storage;
  final String namespace;

  @override
  Future<MilkPlanPendingState?> read() async {
    final raw = await storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return MilkPlanPendingState.fromMap(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(MilkPlanPendingState state) {
    return storage.write(key: storageKey, value: jsonEncode(state.toMap()));
  }

  String get storageKey {
    final scope = userId.trim().isEmpty ? 'anonymous' : userId.trim();
    return '$namespace.user.${Uri.encodeComponent(scope)}.pending';
  }
}
