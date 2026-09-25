import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/care_plan.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/ibclc/documentation/application/documentation_controller.dart';
import 'package:momcozy_flutter_app/modules/services/application/summary_controller.dart';
import 'package:momcozy_flutter_app/services/documentation/documentation_api_repository.dart';
import '../../support/fixture_api_transport.dart';
import 'documentation_test_support.dart';

void main() {
  test(
    'a saved legacy plan remains a draft until English copy is reviewed',
    () async {
      final repository = TestDocumentationRepository()
        ..json = documentationFixture('documentation_published');
      final controller = DocumentationController(
        repository: repository,
        appointmentId: 'appointment',
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.plan.complete, isTrue);
      expect(controller.canPublish, isFalse);
      expect(controller.plan.tasks.single.category, '观察');
      await controller.publish();
      expect(repository.calls, isEmpty);

      controller.changePlan(
        controller.plan.copyWith(
          tasks: [
            controller.plan.tasks.single.copyWith(
              category: 'Observation',
              dueLabel: 'Today',
            ),
          ],
        ),
      );
      repository.onCall = (action, body) async {
        if (action == 'save_plan') {
          (repository.json['plan'] as Map)['content'] = body['content'];
        }
      };
      await controller.savePlan();
      expect(repository.calls.single.action, 'save_plan');
      expect(controller.canPublish, isTrue);
      expect(controller.plan.tasks.single.sourceKey, 'log-observation');
    },
  );

  test(
    'an uncertain note save freezes content, version, and mutation key across retry',
    () async {
      final repository = TestDocumentationRepository();
      final controller = DocumentationController(
        repository: repository,
        appointmentId: 'appointment',
      );
      addTearDown(controller.dispose);
      await controller.load();
      controller.changeNote(
        controller.note.copyWith(subjective: 'New observation'),
      );
      repository.onCall = (action, body) async {
        (repository.json['note'] as Map)['content'] = body['content'];
        if (repository.calls.length == 1) {
          throw const ProductFailure(ProductFailureKind.offline);
        }
      };
      await controller.saveNote();
      expect(controller.uncertain, isTrue);
      controller.changeNote(
        controller.note.copyWith(
          subjective: 'Must not replace pending content',
        ),
      );
      await controller.retry();
      expect(repository.calls.length, 2);
      expect(repository.calls[0].body, repository.calls[1].body);
      expect(controller.note.subjective, 'New observation');
      expect(controller.uncertain, isFalse);
    },
  );

  test(
    'signing requires saved content and saving one editor preserves the other draft',
    () async {
      final repository = TestDocumentationRepository();
      final controller = DocumentationController(
        repository: repository,
        appointmentId: 'appointment',
      );
      addTearDown(controller.dispose);
      await controller.load();
      controller.changePlan(
        controller.plan.copyWith(summary: 'Unsubmitted plan'),
      );
      controller.changeNote(
        controller.note.copyWith(assessment: 'New assessment'),
      );
      await controller.sign();
      expect(repository.calls, isEmpty);
      repository.onCall = (action, body) async {
        if (action == 'save_note') {
          (repository.json['note'] as Map)['content'] = body['content'];
        }
      };
      await controller.saveNote();
      expect(controller.plan.summary, 'Unsubmitted plan');
      expect(controller.planDirty, isTrue);
      expect(controller.noteDirty, isFalse);
      expect(controller.canSign, isTrue);
      expect(controller.canPublish, isFalse);
    },
  );

  test(
    'acknowledged mutations do not repeat when only the following refresh fails',
    () async {
      final repository = TestDocumentationRepository();
      final controller = DocumentationController(
        repository: repository,
        appointmentId: 'appointment',
      );
      addTearDown(controller.dispose);
      await controller.load();
      repository.onLoad = () async =>
          throw const ProductFailure(ProductFailureKind.unavailable);
      controller.changeNote(controller.note.copyWith(plan: 'Saved change'));
      await controller.saveNote();
      expect(controller.uncertain, isFalse);
      expect(controller.needsReload, isTrue);
      expect(controller.noteEditable, isFalse);
      repository.onLoad = null;
      await controller.retry();
      expect(repository.calls.length, 1);
      expect(controller.needsReload, isFalse);
    },
  );

  test(
    'withdrawn case access removes private content from the controller',
    () async {
      final repository = TestDocumentationRepository();
      final controller = DocumentationController(
        repository: repository,
        appointmentId: 'appointment',
      );
      addTearDown(controller.dispose);
      await controller.load();
      repository.onLoad = () async => throw const ProductFailure(
        ProductFailureKind.forbidden,
        code: 'case_consent_required',
      );
      await controller.load();
      expect(controller.data, isNull);
      expect(controller.note.subjective, isEmpty);
      expect(controller.plan.tasks, isEmpty);
      expect(controller.noteEditable, isFalse);
    },
  );

  test(
    'task progress waits for the server and retries the same publication and version',
    () async {
      final repository = TestPatientPlanRepository();
      final controller = CareSummaryController(
        repository: repository,
        appointmentId: 'appointment',
      );
      addTearDown(controller.dispose);
      await controller.load();
      repository.onUpdate = () async {
        if (repository.calls.length == 1) {
          throw const ProductFailure(ProductFailureKind.offline);
        }
        final task =
            ((repository.json['publication'] as Map)['tasks'] as List).first
                as Map;
        task['status'] = 'completed';
        task['progress_version'] = 2;
      };
      await controller.update(
        controller.data!.publication!.tasks.first,
        CareTaskStatus.completed,
      );
      expect(
        controller.data!.publication!.tasks.first.status,
        CareTaskStatus.pending,
      );
      expect(controller.canUpdate, isFalse);
      await controller.retry();
      expect(repository.calls.first, repository.calls.last);
      expect(
        controller.data!.publication!.tasks.first.status,
        CareTaskStatus.completed,
      );
    },
  );

  test(
    'superseded publication blocks feedback until canonical plan is reloaded',
    () async {
      final repository = TestPatientPlanRepository();
      final controller = CareSummaryController(
        repository: repository,
        appointmentId: 'appointment',
      );
      addTearDown(controller.dispose);
      await controller.load();
      repository.onUpdate = () async => throw const ProductFailure(
        ProductFailureKind.conflict,
        code: 'plan_superseded',
      );
      await controller.update(
        controller.data!.publication!.tasks.first,
        CareTaskStatus.completed,
      );
      expect(controller.uncertain, isFalse);
      expect(controller.canUpdate, isFalse);
      await controller.retry();
      expect(repository.calls.length, 1);
      expect(controller.canUpdate, isTrue);
    },
  );

  test(
    'published DTO contains no clinical note and task API includes publication and CAS version',
    () async {
      final fixture = documentationFixture('patient_care_summary');
      final transport = FixtureApiJsonTransport(fixture);
      final repository = DocumentationApiRepository(transport: transport);
      final summary = await repository.summary('appointment');
      expect(fixture.keys, isNot(contains('note')));
      expect(summary.episode.remainingSessions, 1);
      final updates = FixtureApiJsonTransport(
        Map<String, Object?>.from(fixture['publication'] as Map),
      );
      await DocumentationApiRepository(transport: updates).updateTask(
        'publication',
        'task/key',
        expectedVersion: 4,
        status: CareTaskStatus.skipped,
      );
      expect(
        updates.lastPath,
        '/v1/care/plan-publications/publication/tasks/task%2Fkey',
      );
      expect(updates.lastBody, {'expected_version': 4, 'status': 'skipped'});
      expect(updates.lastMethod, 'PUT');
    },
  );
}
