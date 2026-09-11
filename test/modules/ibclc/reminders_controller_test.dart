import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/ibclc/workbench_reminder.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/ibclc/reminders/application/reminders_controller.dart';
import 'package:momcozy_flutter_app/services/ibclc/reminders_codec.dart';
import 'workbench_test_support.dart';

class ReminderRepository implements WorkbenchRemindersRepository {
  Future<WorkbenchReminders> Function(int)? onList;
  Future<void> Function(String)? onRead;
  int reads = 0;
  @override
  Future<WorkbenchReminders> reminders({int offset = 0}) async => onList == null
      ? readReminders(workbenchFixture('reminders'))
      : onList!(offset);
  @override
  Future<void> readReminder(String eventId) async {
    reads++;
    await onRead?.call(eventId);
  }
}

void main() {
  test(
    'read acknowledgements serialize taps and clear private rows after permission loss',
    () async {
      final repository = ReminderRepository();
      final pending = Completer<void>();
      repository.onRead = (_) => pending.future;
      final controller = WorkbenchRemindersController(repository);
      addTearDown(controller.dispose);
      await controller.load();
      final item = controller.data!.items.first;
      final first = controller.markRead(item);
      expect(await controller.markRead(item), isFalse);
      expect(repository.reads, 1);
      pending.completeError(const ProductFailure(ProductFailureKind.forbidden));
      expect(await first, isFalse);
      expect(controller.data, isNull);
      expect(controller.failure?.kind, ProductFailureKind.forbidden);
    },
  );
  test(
    'a late refresh cannot restore reminder rows after a newer authorization failure',
    () async {
      final repository = ReminderRepository();
      final old = Completer<WorkbenchReminders>();
      var calls = 0;
      repository.onList = (_) async {
        if (++calls == 1) return old.future;
        throw const ProductFailure(ProductFailureKind.forbidden);
      };
      final controller = WorkbenchRemindersController(repository);
      addTearDown(controller.dispose);
      final first = controller.load();
      await controller.load();
      old.complete(readReminders(workbenchFixture('reminders')));
      await first;
      expect(controller.data, isNull);
      expect(controller.failure?.kind, ProductFailureKind.forbidden);
    },
  );
}
