import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/care_report.dart';
import 'package:momcozy_flutter_app/domain/ibclc/workbench_followup.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/ibclc/reports/application/report_controller.dart';
import 'package:momcozy_flutter_app/modules/ibclc/followup/application/followups_controller.dart';
import 'package:momcozy_flutter_app/services/reports/report_codec.dart';
import 'package:momcozy_flutter_app/services/ibclc/followups_codec.dart';
import 'package:momcozy_flutter_app/services/ibclc/workbench_codec.dart';
import 'workbench_test_support.dart';

class Reports implements CareReportsRepository {
  Map<String, Object?> value = workbenchFixture('report');
  int reviews = 0;
  Future<CareReportSnapshot> Function()? onRead;
  @override
  Future<CareReportSnapshot> read(
    String id, {
    required CareReportPurpose purpose,
    LocalDate? date,
  }) async => onRead == null ? readReportSnapshot(value) : onRead!();
  @override
  Future<CareReportSnapshot> generate(
    String id, {
    required CareReportPurpose purpose,
    LocalDate? date,
  }) => read(id, purpose: purpose, date: date);
  @override
  Future<List<CareReportDay>> history(
    String id, {
    required CareReportPurpose purpose,
  }) async => (workbenchFixture('report_history')['items'] as List)
      .map((value) => readReportDay(Map<String, Object?>.from(value as Map)))
      .toList();
  @override
  Future<CareReport> review(
    String id, {
    required int expectedVersion,
    required CareReportReviewDecision decision,
    String feedback = '',
  }) async {
    reviews++;
    final report = value['report'] as Map;
    report['review'] = {
      'id': '11111111-1111-4111-8111-111111111111',
      'version': expectedVersion + 1,
      'decision': reportReviewWire.write(decision),
      'feedback': feedback,
      'created_at': value['server_time'],
    };
    return readReport(Map<String, Object?>.from(report));
  }
}

class Followups implements WorkbenchFollowupsRepository {
  Future<WorkbenchFollowups> Function(WorkbenchFollowupFilter)? response;
  @override
  Future<WorkbenchFollowups> followups({
    String query = '',
    WorkbenchFollowupFilter filter = WorkbenchFollowupFilter.all,
    int offset = 0,
  }) async => response == null
      ? readFollowups(workbenchFixture('followups'))
      : response!(filter);
}

WorkbenchReportController reportController(Reports reports) {
  final clients = TestWorkbenchRepository()
    ..clientJson = workbenchFixture('report_client');
  final patient = readWorkbenchClientDetail(clients.clientJson).client;
  return WorkbenchReportController(
    clients: clients,
    reports: reports,
    patientRef: patient.patientRef,
  );
}

void main() {
  test(
    'report sources retain evidence, real dialogue and empty unsupported personality',
    () {
      final snapshot = readReportSnapshot(workbenchFixture('report'));
      expect(snapshot.report!.content!.emotionalState, isEmpty);
      expect(snapshot.report!.dialogues, hasLength(1));
      expect(snapshot.report!.sources, hasLength(5));
      expect(snapshot.report!.reviewable, isTrue);
    },
  );
  test(
    'review is bound to the opened report version and concrete feedback',
    () async {
      final repository = Reports();
      final controller = reportController(repository);
      addTearDown(controller.dispose);
      await controller.load();
      final target = controller.data!.report!;
      expect(
        await controller.review(
          target,
          CareReportReviewDecision.feedback,
          feedback: '  ',
        ),
        isFalse,
      );
      expect(repository.reviews, 0);
      expect(
        await controller.review(
          target,
          CareReportReviewDecision.feedback,
          feedback: '请先核对宝宝摄入量。',
        ),
        isTrue,
      );
      expect(controller.data!.report!.review!.feedback, '请先核对宝宝摄入量。');
      expect(controller.data!.report!.review!.version, 1);
      final newReport = repository.value['report'] as Map;
      newReport['id'] = '22222222-2222-4222-8222-222222222222';
      newReport['version'] = 2;
      newReport['review'] = null;
      await controller.load();
      expect(
        await controller.review(target, CareReportReviewDecision.confirmed),
        isFalse,
      );
      expect(repository.reviews, 1);
      expect(controller.failure!.code, 'care_report_changed');
    },
  );
  test(
    'authorization failure clears clinical content and report history',
    () async {
      final repository = Reports();
      final controller = reportController(repository);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.history, isNotEmpty);
      repository.onRead = () => throw const ProductFailure(
        ProductFailureKind.forbidden,
        code: 'ai_consent_required',
      );
      await controller.load();
      expect(controller.client, isNull);
      expect(controller.service, isNull);
      expect(controller.data, isNull);
      expect(controller.history, isEmpty);
      expect(controller.failure!.code, 'ai_consent_required');
    },
  );
  test('late report response cannot restore a disposed page', () async {
    final repository = Reports();
    final pending = Completer<CareReportSnapshot>();
    repository.onRead = () => pending.future;
    final controller = reportController(repository);
    final operation = controller.load();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    pending.complete(readReportSnapshot(repository.value));
    await operation;
    expect(controller.data, isNull);
  });
  test(
    'followup filter changes ignore a prior response and clear rows on denial',
    () async {
      final repository = Followups();
      final pending = Completer<WorkbenchFollowups>();
      final fixture = readFollowups(workbenchFixture('followups'));
      repository.response = (filter) => filter == WorkbenchFollowupFilter.all
          ? pending.future
          : Future.value(fixture);
      final controller = WorkbenchFollowupsController(repository);
      addTearDown(controller.dispose);
      final old = controller.load();
      await controller.setFilter(WorkbenchFollowupFilter.pending);
      pending.complete(
        readFollowups({
          ...workbenchFixture('followups'),
          'items': [],
          'total': 0,
        }),
      );
      await old;
      expect(controller.data!.items, isNotEmpty);
      repository.response = (_) =>
          throw const ProductFailure(ProductFailureKind.forbidden);
      await controller.load();
      expect(controller.data, isNull);
    },
  );
}
