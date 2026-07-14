import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:momcozy_flutter_app/features/pregnancy_plan/domain/pregnancy_plan_change_store.dart';

class FlutterSecurePregnancyPlanChangePersistence
    implements PregnancyPlanChangePersistence {
  const FlutterSecurePregnancyPlanChangePersistence({
    required this.userId,
    this.storage = const FlutterSecureStorage(),
    this.namespace = 'momcozy.pregnancyPlanChange.v1',
  });

  final String userId;
  final FlutterSecureStorage storage;
  final String namespace;

  @override
  Future<PregnancyPlanPendingState?> read() async {
    final raw = await storage.read(key: _key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return PregnancyPlanPendingState.fromMap(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(PregnancyPlanPendingState state) {
    return storage.write(key: _key, value: jsonEncode(state.toMap()));
  }

  String get _key {
    final scope = userId.trim().isEmpty ? 'anonymous' : userId.trim();
    return '$namespace.user.${Uri.encodeComponent(scope)}.pending';
  }
}
