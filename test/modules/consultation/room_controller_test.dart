import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/consultation_room.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/services/consultations/consultation_media.dart';
import 'room_test_support.dart';

void main() {
  test(
    'joining requires explicit video consent and confirmed current location',
    () async {
      final repository = TestRoomRepository();
      final media = TestConsultationMedia();
      final controller = testController(repository, media);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.enter();
      expect(repository.prepareCalls, 0);
      expect(media.connectCalls, 0);
      expect(controller.canEnter, isFalse);
      repository.ready();
      await controller.load();
      await controller.enter();
      expect(media.connectCalls, 1);
      expect(repository.sentPresence, contains(ParticipantPresence.joined));
    },
  );
  test(
    'an uncertain join retries the same intent and double taps do not connect twice',
    () async {
      final repository = TestRoomRepository()..ready();
      final media = TestConsultationMedia();
      final controller = testController(repository, media);
      addTearDown(controller.dispose);
      await controller.load();
      final pending = Completer<ConsultationJoin>();
      repository.nextJoin = pending.future;
      final first = controller.enter();
      await Future<void>.delayed(Duration.zero);
      await controller.enter();
      expect(repository.keys, hasLength(1));
      pending.completeError(const ProductFailure(ProductFailureKind.offline));
      await first;
      repository.nextJoin = null;
      await controller.enter();
      expect(repository.keys[0], repository.keys[1]);
      expect(media.connectCalls, 1);
    },
  );
  test(
    'leaving disconnects media and reports presence without ending consultation',
    () async {
      final repository = TestRoomRepository()..ready();
      final media = TestConsultationMedia();
      final controller = testController(repository, media);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.enter();
      repository.room(status: 'in_progress', version: 2);
      await controller.load();
      await controller.leave();
      expect(media.state, ConsultationMediaState.disconnected);
      expect(repository.sentPresence.last, ParticipantPresence.left);
      expect(repository.endCalls, 0);
      expect(controller.data!.active, isTrue);
    },
  );
  test('withdrawal and remote end disconnect media on refresh', () async {
    final repository = TestRoomRepository()..ready();
    final media = TestConsultationMedia();
    final controller = testController(repository, media);
    addTearDown(controller.dispose);
    await controller.load();
    await controller.enter();
    repository.json['video_consent'] = false;
    repository.room(roomStatus: 'closing', version: 2);
    await controller.load();
    expect(media.state, ConsultationMediaState.disconnected);
    expect(repository.endCalls, 0);
  });
  test(
    'leaving during delayed join prevents a late media connection',
    () async {
      final repository = TestRoomRepository()..ready();
      final media = TestConsultationMedia();
      final controller = testController(repository, media);
      addTearDown(controller.dispose);
      await controller.load();
      final pending = Completer<ConsultationJoin>();
      repository.nextJoin = pending.future;
      final joining = controller.enter();
      await Future<void>.delayed(Duration.zero);
      await controller.leave();
      pending.complete(
        ConsultationJoin(
          context: repository.context,
          connectionId: 'late',
          credentials: null,
        ),
      );
      await joining;
      expect(media.connectCalls, 0);
      expect(repository.sentPresence.last, ParticipantPresence.left);
    },
  );
}
