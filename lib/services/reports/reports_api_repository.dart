import '../../core/network/api_json_transport.dart';
import '../../domain/care/care_report.dart';
import '../../domain/shared/local_date.dart';
import '../shared/json_value.dart';
import '../shared/product_failure_mapper.dart';
import 'report_codec.dart';

class CareReportsApiRepository implements CareReportsRepository {
  const CareReportsApiRepository({required this.transport});
  final ApiJsonTransport transport;
  String _path(String id) =>
      '/v1/ibclc/episodes/${Uri.encodeComponent(id)}/reports';
  @override
  Future<CareReportSnapshot> read(
    String episodeId, {
    required CareReportPurpose purpose,
    LocalDate? date,
  }) => withProductFailure(
    () async => readReportSnapshot(
      await transport.getJson(
        _path(episodeId),
        query: {
          'purpose': reportPurposeWire.write(purpose),
          'report_date': date?.toString(),
        },
      ),
    ),
  );
  @override
  Future<CareReportSnapshot> generate(
    String episodeId, {
    required CareReportPurpose purpose,
    LocalDate? date,
  }) => withProductFailure(
    () async => readReportSnapshot(
      await transport.postJson(
        _path(episodeId),
        body: {
          'purpose': reportPurposeWire.write(purpose),
          'report_date': date?.toString(),
        },
      ),
    ),
  );
  @override
  Future<List<CareReportDay>> history(
    String episodeId, {
    required CareReportPurpose purpose,
  }) => withProductFailure(
    () async => jsonList(
      (await transport.getJson(
        '${_path(episodeId)}/history',
        query: {'purpose': reportPurposeWire.write(purpose)},
      ))['items'],
      readReportDay,
    ),
  );
  @override
  Future<CareReport> review(
    String reportId, {
    required int expectedVersion,
    required CareReportReviewDecision decision,
    String feedback = '',
  }) => withProductFailure(
    () async => readReport(
      await transport.postJson(
        '/v1/ibclc/reports/${Uri.encodeComponent(reportId)}/reviews',
        body: {
          'expected_version': expectedVersion,
          'decision': reportReviewWire.write(decision),
          'feedback': feedback.trim(),
        },
      ),
    ),
  );
}
