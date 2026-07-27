import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/agent_hub/domain/agent_voice.dart';

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

    test(
      'reports blocked playback and notifies when playback becomes idle',
      () {
        final coordinator = AgentVoicePlaybackCoordinator();
        var idleCount = 0;
        final unsubscribe = coordinator.subscribeIdle(() {
          idleCount += 1;
        });

        final notification = coordinator.request(
          id: 'notification-1',
          source: AgentVoicePlaybackSource.notification,
        );
        final auto = coordinator.request(
          id: 'reply-1',
          source: AgentVoicePlaybackSource.autoReply,
        );

        expect(notification.status, AgentVoicePlaybackRequestStatus.started);
        expect(auto.status, AgentVoicePlaybackRequestStatus.blocked);
        expect(idleCount, 0);

        notification.handle?.finish();

        expect(idleCount, 1);
        expect(coordinator.activeSource, isNull);
        unsubscribe();
      },
    );

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

    test('does not notify idle while a greeting voice takes over', () {
      final coordinator = AgentVoicePlaybackCoordinator();
      var idleCount = 0;
      final unsubscribe = coordinator.subscribeIdle(() {
        idleCount += 1;
      });

      coordinator.request(
        id: 'reply-1',
        source: AgentVoicePlaybackSource.autoReply,
      );
      final greeting = coordinator.request(
        id: 'greeting-1',
        source: AgentVoicePlaybackSource.greeting,
      );

      expect(greeting.status, AgentVoicePlaybackRequestStatus.started);
      expect(idleCount, 0);

      greeting.handle?.finish();

      expect(idleCount, 1);
      unsubscribe();
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
