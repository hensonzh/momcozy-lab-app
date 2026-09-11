import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/ibclc/workbench.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/ibclc/appointments/application/appointments_controller.dart';
import 'package:momcozy_flutter_app/modules/ibclc/users/application/clients_controller.dart';
import 'package:momcozy_flutter_app/services/ibclc/workbench_codec.dart';
import 'workbench_test_support.dart';

void main() {
  test(
    'canonical API fixture allows an appointment without a note or consultation',
    () {
      final data = readWorkbenchAppointments(workbenchFixture('appointments'));
      expect(data.items.single.noteStatus, isNull);
      expect(data.items.single.caseConsent, isTrue);
      expect(data.items.single.patientName, '林晓');
      expect(
        readWorkbenchClientDetail(workbenchFixture('client')).client.patientRef,
        data.items.single.patientRef,
      );
    },
  );
  test(
    'changing the calendar date cannot show the previous in-flight response',
    () async {
      final repository = TestWorkbenchRepository();
      final old = Completer<WorkbenchAppointments>();
      final nextDate = LocalDate(2026, 9, 9);
      repository.onAppointments = (date, offset) async {
        if (date == null) return old.future;
        return readWorkbenchAppointments({
          ...repository.appointmentsJson,
          'date': nextDate.toString(),
          'items': [],
          'total': 0,
        });
      };
      final controller = WorkbenchAppointmentsController(repository);
      addTearDown(controller.dispose);
      final first = controller.load();
      await controller.selectDate(nextDate);
      old.complete(readWorkbenchAppointments(repository.appointmentsJson));
      await first;
      expect(controller.data!.date, nextDate);
      expect(controller.data!.items, isEmpty);
    },
  );
  test(
    'workbench clears private list data after an authorization failure',
    () async {
      final repository = TestWorkbenchRepository();
      final controller = WorkbenchAppointmentsController(repository);
      addTearDown(controller.dispose);
      await controller.load();
      repository.onAppointments = (_, _) =>
          throw const ProductFailure(ProductFailureKind.forbidden);
      await controller.load();
      expect(controller.data, isNull);
      expect(controller.failure!.kind, ProductFailureKind.forbidden);
    },
  );
  test(
    'client search ignores responses from a superseded query and sends the selected service filter',
    () async {
      final repository = TestWorkbenchRepository();
      final old = Completer<WorkbenchClients>();
      repository.onClients = (query) async => query == 'old'
          ? old.future
          : readWorkbenchClients({
              ...repository.clientsJson,
              'items': [],
              'total': 0,
            });
      final controller = WorkbenchClientsController(repository);
      addTearDown(controller.dispose);
      controller.search('old');
      final first = controller.load();
      controller.search('new');
      await controller.setFilter(WorkbenchClientFilter.active);
      old.complete(readWorkbenchClients(repository.clientsJson));
      await first;
      expect(controller.data!.items, isEmpty);
      expect(repository.clientCalls.last, (
        query: 'new',
        filter: WorkbenchClientFilter.active,
        offset: 0,
      ));
    },
  );
}
