import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_finalization.dart';

class FlutterSecureMotionAssessmentFinalizationStore
    implements MotionAssessmentFinalizationStore {
  const FlutterSecureMotionAssessmentFinalizationStore({
    required this.userId,
    this.storage = const FlutterSecureStorage(),
    this.namespace = 'momcozy.motionFinalization.v1',
    this.maximumPending = 5,
  });

  final String userId;
  final FlutterSecureStorage storage;
  final String namespace;
  final int maximumPending;

  @override
  Future<List<MotionAssessmentFinalization>> readAll() async {
    final raw = await storage.read(key: _key);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return List<MotionAssessmentFinalization>.unmodifiable(
        decoded.take(maximumPending).whereType<Map>().map((item) {
          try {
            return MotionAssessmentFinalization.fromJson(
              Map<String, Object?>.from(item),
            );
          } on FormatException {
            return null;
          }
        }).whereType<MotionAssessmentFinalization>(),
      );
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> upsert(MotionAssessmentFinalization finalization) async {
    final pending = await readAll();
    final updated = <MotionAssessmentFinalization>[
      ...pending.where(
        (item) => item.finalizationId != finalization.finalizationId,
      ),
      finalization,
    ];
    final bounded = updated.length <= maximumPending
        ? updated
        : updated.sublist(updated.length - maximumPending);
    await storage.write(
      key: _key,
      value: jsonEncode(bounded.map((item) => item.toJson()).toList()),
    );
  }

  @override
  Future<void> remove(String finalizationId) async {
    final pending = await readAll();
    final retained = pending
        .where((item) => item.finalizationId != finalizationId)
        .toList();
    if (retained.isEmpty) {
      await storage.delete(key: _key);
      return;
    }
    await storage.write(
      key: _key,
      value: jsonEncode(retained.map((item) => item.toJson()).toList()),
    );
  }

  String get _key {
    final scopedUserId = userId.trim().isEmpty ? 'anonymous' : userId.trim();
    return '$namespace.user.${Uri.encodeComponent(scopedUserId)}.pending';
  }
}
