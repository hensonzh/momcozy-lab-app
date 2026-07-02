import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';

void main() {
  group('AgentVoicePlaybackCoordinator', () {
    test('keeps notification voice from being interrupted by auto reply', () {
      final coordinator = AgentVoicePlaybackCoordinator();
      var notificationCancelled = false;
      var autoCancelled = false;

      final notification = coordinator.request(
        id: 'notification-1',
        source: AgentVoicePlaybackSource.notification,
        cancel: () => notificationCancelled = true,
      );
      final auto = coordinator.request(
        id: 'reply-1',
        source: AgentVoicePlaybackSource.autoReply,
        cancel: () => autoCancelled = true,
      );

      expect(notification.status, AgentVoicePlaybackRequestStatus.started);
      expect(auto.status, AgentVoicePlaybackRequestStatus.blocked);
      expect(auto.activeId, 'notification-1');
      expect(auto.activeSource, AgentVoicePlaybackSource.notification);
      expect(notificationCancelled, isFalse);
      expect(autoCancelled, isFalse);
      expect(coordinator.activeSource, AgentVoicePlaybackSource.notification);

      notification.handle?.finish();
      expect(coordinator.activeSource, isNull);
    });

    test('lets notification voice interrupt auto reply playback', () {
      final coordinator = AgentVoicePlaybackCoordinator();
      var autoCancelled = false;

      coordinator.request(
        id: 'reply-1',
        source: AgentVoicePlaybackSource.autoReply,
        cancel: () => autoCancelled = true,
      );
      final notification = coordinator.request(
        id: 'notification-1',
        source: AgentVoicePlaybackSource.notification,
      );

      expect(notification.status, AgentVoicePlaybackRequestStatus.started);
      expect(autoCancelled, isTrue);
      expect(coordinator.activeSource, AgentVoicePlaybackSource.notification);
      expect(coordinator.activeId, 'notification-1');
    });

    test('lets manual bubble playback interrupt notification voice', () {
      final coordinator = AgentVoicePlaybackCoordinator();
      var notificationCancelled = false;
      var manualCancelled = false;

      coordinator.request(
        id: 'notification-1',
        source: AgentVoicePlaybackSource.notification,
        cancel: () => notificationCancelled = true,
      );
      final manual = coordinator.request(
        id: 'message-1',
        source: AgentVoicePlaybackSource.manualBubble,
        cancel: () => manualCancelled = true,
      );

      expect(manual.status, AgentVoicePlaybackRequestStatus.started);
      expect(notificationCancelled, isTrue);
      expect(manualCancelled, isFalse);
      expect(coordinator.activeSource, AgentVoicePlaybackSource.manualBubble);

      expect(manual.handle?.cancel(), isTrue);
      expect(manualCancelled, isTrue);
      expect(coordinator.activeSource, isNull);
    });

    test('preserves notification voice for hidden followup work', () {
      final coordinator = AgentVoicePlaybackCoordinator();
      var notificationCancelled = false;

      coordinator.request(
        id: 'notification-1',
        source: AgentVoicePlaybackSource.notification,
        cancel: () => notificationCancelled = true,
      );

      expect(
        coordinator.cancel(
          preserveSources: {AgentVoicePlaybackSource.notification},
        ),
        isFalse,
      );
      expect(notificationCancelled, isFalse);
      expect(coordinator.activeSource, AgentVoicePlaybackSource.notification);
    });
  });
}
