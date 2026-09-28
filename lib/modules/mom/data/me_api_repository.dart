import '../../../core/network/api_json_transport.dart';
import '../domain/me_experience.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/shared/local_date.dart';
import '../../../services/baby/baby_records_api_repository.dart';
import '../../../services/baby/baby_profiles_api_repository.dart';
import '../../../features/records/data/records_api_repository.dart';
import 'me_shared_records.dart';

class MeApiRepository implements MeRepository {
  MeApiRepository(
    this.transport, {
    required this.timezoneProvider,
    this.selectedBabyId,
  });
  final Future<String> Function() timezoneProvider;
  final String? selectedBabyId;
  BabyProfile? baby;
  final ApiJsonTransport transport;
  ApiJsonMutationTransport get mutations =>
      transport as ApiJsonMutationTransport;
  static const path = '/v1/profile/me-experience';
  @override
  Future<MeState> load(DateTime day) async {
    final state = MeState.fromJson(
      await transport.getJson(
        path,
        query: {
          'start': DateTime(
            day.year,
            day.month,
            day.day,
          ).toUtc().toIso8601String(),
          'end': DateTime(
            day.year,
            day.month,
            day.day + 1,
          ).toUtc().toIso8601String(),
        },
      ),
    );
    final failures = <MeMetric>{};
    final records = <MeObservation>[...state.records];
    try {
      final profiles = await BabyProfilesApiRepository(
        transport: transport,
      ).list();
      baby =
          profiles.where((e) => e.id == selectedBabyId).firstOrNull ??
          profiles.firstOrNull;
      if (baby != null) {
        final date = LocalDate.fromDateTime(day);
        final timezone = await timezoneProvider();
        var offset = 0;
        while (true) {
          final page = await BabyRecordsApiRepository(transport: transport)
              .list(
                babyId: baby!.id,
                startDate: date,
                // The Baby records API treats end_date as an exclusive
                // boundary and rejects an empty date range.
                endDate: date.addDays(1),
                timezone: timezone,
                offset: offset,
              );
          records.addAll(meObservationsFromBaby(page.items));
          offset += page.items.length;
          if (offset >= page.total || page.items.isEmpty) break;
        }
      }
      if (baby != null) {
        final growth = await BabyRecordsApiRepository(
          transport: transport,
        ).latestGrowth(baby!.id);
        final fresh = meObservationsFromBaby(growth);
        final ids = fresh.map((e) => e.id).toSet();
        records.removeWhere(
          (e) => e.kind == MeMetric.weight && ids.contains(e.id),
        );
        records.addAll(fresh);
      }
    } catch (_) {
      failures.addAll([MeMetric.feed, MeMetric.diaper, MeMetric.weight]);
    }
    try {
      final pumping = await RecordsApiRepository(
        transport: transport,
      ).fetchPumpMilkRecords(date: day);
      records.addAll(
        pumping
            .where(
              (e) =>
                  e.occurredAt != null &&
                  !records.any((r) => r.fields['canonical_record_id'] == e.id),
            )
            .map(
              (e) => MeObservation(
                id: e.id,
                kind: MeMetric.pump,
                occurredAt: e.occurredAt!.toLocal(),
                value: '${e.measuredVolumeMl?.toStringAsFixed(0) ?? '—'} ml',
                fields: {
                  if (e.measuredVolumeMl != null)
                    'volume_ml': e.measuredVolumeMl!,
                },
              ),
            ),
      );
    } catch (_) {
      failures.add(MeMetric.pump);
    }
    return state.copyWith(records: records, failedMetrics: failures);
  }

  @override
  Future<Map<String, Object?>> saveProfile(Map<String, Object?> values) =>
      mutations.patchJson('$path/profile', body: values);
  @override
  Future<MeConcern> saveConcern(MeConcern concern) async => MeConcern.fromJson(
    await mutations.putJson(
      '$path/concerns/${concern.id}',
      body: concern.toJson(),
    ),
  );
  @override
  Future<List<MeMetric>> saveOrder(List<MeMetric> order) async {
    final result = await mutations.putJson(
      '$path/order',
      body: {'order': order.map((e) => e.name).toList()},
    );
    return (result['order']! as List)
        .map((e) => MeMetric.values.byName(e as String))
        .toList();
  }

  @override
  Future<MeObservation> saveRecord(MeObservation record) async {
    return MeObservation.fromJson(
      await mutations.putJson(
        '$path/records/${record.id}',
        body: record.toJson(),
      ),
    );
  }
}
