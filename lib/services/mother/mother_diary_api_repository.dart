import '../../core/network/api_json_transport.dart';
import '../../domain/mother/mother_diary.dart';
import '../../domain/shared/local_date.dart';
import '../shared/json_value.dart';
import '../shared/product_failure_mapper.dart';
import 'mother_diary_codec.dart';

class MotherDiaryApiRepository implements MotherDiaryRepository {
  const MotherDiaryApiRepository({required this.transport});
  final ApiJsonTransport transport;
  static const endpoint = '/v1/mother/diary';

  @override
  Future<List<MotherDiaryEntry>> list({
    required LocalDate start,
    required LocalDate end,
  }) => withProductFailure(() async {
    final response = await transport.getJson(
      endpoint,
      query: {'start': start.toString(), 'end': end.toString()},
    );
    final items = response['items'];
    if (items is! List) throw const FormatException('Diary list is missing.');
    return List.unmodifiable(
      items.map((item) => readMotherDiaryEntry(jsonObject(item))),
    );
  });

  @override
  Future<MotherDiaryEntry> save({
    required LocalDate date,
    required MotherDiary diary,
    required int expectedVersion,
  }) => withProductFailure(() async {
    if (diary.isEmpty) throw ArgumentError('Record at least one observation.');
    final client = transport;
    if (client is! ApiJsonMutationTransport) {
      throw StateError('Mutation transport is required.');
    }
    return readMotherDiaryEntry(
      await (client as ApiJsonMutationTransport).putJson(
        '$endpoint/$date',
        body: {
          'expected_version': expectedVersion,
          'diary': writeMotherDiary(diary),
        },
      ),
    );
  });
}
