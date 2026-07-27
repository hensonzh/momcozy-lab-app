import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app/features/pregnancy_diary/domain/pregnancy_diary_change_store.dart';

class FlutterSecurePregnancyDiaryChangePersistence
    implements PregnancyDiaryChangePersistence {
  const FlutterSecurePregnancyDiaryChangePersistence({
    required this.userId,
    this.storage = const FlutterSecureStorage(),
    this.namespace = 'momcozy.pregnancyDiaryChange.v1',
  });

  final String userId;
  final FlutterSecureStorage storage;
  final String namespace;

  @override
  Future<PregnancyDiaryPendingState?> read() async {
    final raw = await storage.read(key: _key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return PregnancyDiaryPendingState.fromMap(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(PregnancyDiaryPendingState state) {
    return storage.write(key: _key, value: jsonEncode(state.toMap()));
  }

  String get _key {
    final scope = userId.trim().isEmpty ? 'anonymous' : userId.trim();
    return '$namespace.user.${Uri.encodeComponent(scope)}.pending';
  }
}
