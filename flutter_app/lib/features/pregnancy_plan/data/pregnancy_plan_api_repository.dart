import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/pregnancy_plan/domain/pregnancy_plan.dart';

const pregnancyPlansEndpoint = '/v1/plans';

class PregnancyPlanApiRepository implements PregnancyPlanRepository {
  const PregnancyPlanApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<PregnancyPlan?> fetchActivePlan() async {
    final response = await transport.getJson(
      pregnancyPlansEndpoint,
      query: const {'plan_type': 'pregnancy', 'status': 'active', 'limit': 1},
    );
    final items = response['items'];
    if (items is! List) {
      throw const FormatException(
        'Pregnancy plans response has no items list.',
      );
    }
    if (items.isEmpty) return null;
    for (final raw in items.whereType<Map>()) {
      final plan = _pregnancyPlan(Map<String, Object?>.from(raw));
      if (plan != null) return plan;
    }
    throw const FormatException(
      'Pregnancy plans response has no valid active pregnancy plan.',
    );
  }

  @override
  Future<void> deletePlan({required String planId}) async {
    final value = transport;
    if (value is! ApiJsonMutationTransport) {
      throw UnsupportedError('Pregnancy plans require mutation support.');
    }
    await (value as ApiJsonMutationTransport).deleteJson(
      '$pregnancyPlansEndpoint/${Uri.encodeComponent(planId.trim())}',
    );
  }

  @override
  Future<PregnancyPlan> updateTodoCompletion({
    required String planId,
    required String itemId,
    required bool completed,
    required int expectedVersion,
    String? idempotencyKey,
  }) async {
    final value = transport;
    if (value is! ApiJsonMutationTransport) {
      throw UnsupportedError('Pregnancy plan todos require mutation support.');
    }
    final normalizedPlanId = planId.trim();
    final normalizedItemId = itemId.trim();
    if (normalizedPlanId.isEmpty ||
        normalizedItemId.isEmpty ||
        expectedVersion < 1) {
      throw const FormatException('Pregnancy plan todo identity is invalid.');
    }
    final response = await (value as ApiJsonMutationTransport).patchJson(
      '$pregnancyPlansEndpoint/${Uri.encodeComponent(normalizedPlanId)}/todos/'
      '${Uri.encodeComponent(normalizedItemId)}/completion',
      body: {'completed': completed, 'expected_version': expectedVersion},
      headers: {
        if (idempotencyKey?.trim().isNotEmpty == true)
          'Idempotency-Key': idempotencyKey!.trim(),
      },
    );
    final plan = _pregnancyPlan(response);
    if (plan == null || plan.id != normalizedPlanId) {
      throw const FormatException(
        'Pregnancy plan todo response is not authoritative.',
      );
    }
    return plan;
  }
}

PregnancyPlan? _pregnancyPlan(Map<String, Object?> data) {
  final id = _string(data['id']);
  final planType = _string(data['plan_type']);
  final status = _string(data['status']);
  if (id == null || planType != 'pregnancy' || status != 'active') {
    return null;
  }
  final rawPayload = data['payload'];
  final payload = rawPayload is Map
      ? Map<String, Object?>.unmodifiable(Map<String, Object?>.from(rawPayload))
      : const <String, Object?>{};
  return PregnancyPlan(
    id: id,
    version: _integer(data['version']),
    planType: 'pregnancy',
    title: _string(data['title']) ?? '孕期计划',
    summary: _string(data['summary']) ?? '',
    status: 'active',
    source: _string(data['source']) ?? '',
    payload: payload,
  );
}

int _integer(Object? value) {
  if (value is int) return value < 0 ? 0 : value;
  final parsed = int.tryParse(value?.toString() ?? '');
  return parsed == null || parsed < 0 ? 0 : parsed;
}

String? _string(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
