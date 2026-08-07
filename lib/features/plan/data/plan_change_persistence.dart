import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_change_store.dart';

class FlutterSecurePlanChangePersistence implements PlanChangePersistence {
  const FlutterSecurePlanChangePersistence({
    required this.userId,
    this.storage = const FlutterSecureStorage(),
    this.namespace = 'momcozy.planChange.v2',
  });

  final String userId;
  final FlutterSecureStorage storage;
  final String namespace;

  @override
  Future<PlanChangeSnapshot?> read() async {
    final raw = await storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return PlanChangeSnapshot.fromMap(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(PlanChangeSnapshot state) {
    return storage.write(key: storageKey, value: jsonEncode(state.toMap()));
  }

  String get storageKey {
    final scope = userId.trim().isEmpty ? 'anonymous' : userId.trim();
    return '$namespace.user.${Uri.encodeComponent(scope)}.pending';
  }
}
