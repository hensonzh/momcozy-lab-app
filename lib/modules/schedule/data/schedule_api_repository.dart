import '../../../core/network/api_json_transport.dart';
import '../../../domain/shared/local_date.dart';
import '../../../services/shared/json_value.dart';
import '../../../services/shared/product_failure_mapper.dart';
import '../domain/schedule.dart';

abstract interface class ScheduleRepository {
  Future<SchedulePageData> read({
    required LocalDate start,
    required LocalDate end,
    required String timezone,
    int offset = 0,
    int limit = 100,
  });
  Future<PersonalScheduleEntry> create({
    required String title,
    required LocalDate date,
    required String startTime,
    required String note,
    required String idempotencyKey,
  });
  Future<PersonalScheduleEntry> update(
    PersonalScheduleEntry entry, {
    required String title,
    required LocalDate date,
    required String startTime,
    required String note,
  });
  Future<void> delete(PersonalScheduleEntry entry);
}

class ScheduleApiRepository implements ScheduleRepository {
  const ScheduleApiRepository({required this.transport});
  final ApiJsonTransport transport;

  @override
  Future<SchedulePageData> read({
    required LocalDate start,
    required LocalDate end,
    required String timezone,
    int offset = 0,
    int limit = 100,
  }) => withProductFailure(() async {
    final json = await transport.getJson(
      '/v1/schedule',
      query: {
        'start_date': start.toString(),
        'end_date': end.toString(),
        'timezone': timezone,
        'offset': offset,
        'limit': limit,
      },
    );
    return SchedulePageData(
      personal: jsonList(json['personal'], _personal),
      serverTime: jsonInstant(json['server_time']),
      hasMore: jsonBool(json['has_more']),
    );
  });

  @override
  Future<PersonalScheduleEntry> create({
    required String title,
    required LocalDate date,
    required String startTime,
    required String note,
    required String idempotencyKey,
  }) => withProductFailure(
    () async => _personal(
      await transport.postJson(
        '/v1/schedule/personal',
        body: {
          'title': title,
          'date': date.toString(),
          'start_time': startTime,
          'note': note,
        },
        headers: {'Idempotency-Key': idempotencyKey},
      ),
    ),
  );

  @override
  Future<PersonalScheduleEntry> update(
    PersonalScheduleEntry entry, {
    required String title,
    required LocalDate date,
    required String startTime,
    required String note,
  }) => withProductFailure(
    () async => _personal(
      await (transport as ApiJsonMutationTransport).patchJson(
        '/v1/schedule/personal/${Uri.encodeComponent(entry.id)}',
        body: {
          'title': title,
          'date': date.toString(),
          'start_time': startTime,
          'note': note,
          'expected_updated_at': entry.updatedAt.toUtc().toIso8601String(),
        },
      ),
    ),
  );

  @override
  Future<void> delete(
    PersonalScheduleEntry entry,
  ) => withProductFailure(() async {
    await (transport as ApiJsonMutationTransport).deleteJson(
      '/v1/schedule/personal/${Uri.encodeComponent(entry.id)}?expected_updated_at=${Uri.encodeQueryComponent(entry.updatedAt.toUtc().toIso8601String())}',
    );
  });
}

PersonalScheduleEntry _personal(Map<String, Object?> json) =>
    PersonalScheduleEntry(
      id: jsonString(json['id']),
      title: jsonString(json['title']),
      date: LocalDate.parse(jsonString(json['date'])),
      startTime: jsonString(json['start_time']),
      note: jsonString(json['note']),
      updatedAt: jsonInstant(json['updated_at']),
    );
