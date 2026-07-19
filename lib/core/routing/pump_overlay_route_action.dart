class PumpOverlayRouteAction {
  const PumpOverlayRouteAction({
    required this.type,
    required this.reason,
    this.state,
    this.processAll,
  });

  final String type;
  final String reason;
  final String? state;
  final int? processAll;

  Map<String, Object?> toMap() {
    return {
      'type': type,
      if (state != null) 'state': state,
      if (processAll != null) 'processAll': processAll,
      'reason': reason,
    };
  }
}

int clampPumpOverlayProgress(Object? value) {
  if (value is! num || !value.isFinite) return 0;
  return value.round().clamp(0, 100);
}

PumpOverlayRouteAction buildPumpOverlayRouteAction({
  required String platform,
  required bool permissionGranted,
  required String state,
  required Object? processAll,
  required String routePath,
  required bool appVisible,
}) {
  if (platform != 'android') {
    return const PumpOverlayRouteAction(
      type: 'skip',
      reason: 'platform-not-android',
    );
  }

  if (!permissionGranted) {
    return const PumpOverlayRouteAction(
      type: 'skip',
      reason: 'overlay-permission-denied',
    );
  }

  if (routePath == '/pump' && appVisible) {
    return const PumpOverlayRouteAction(
      type: 'hide',
      reason: 'route-is-pump-and-app-visible',
    );
  }

  if (state == 'running' || state == 'paused') {
    return PumpOverlayRouteAction(
      type: 'update',
      state: state,
      processAll: clampPumpOverlayProgress(processAll),
      reason: 'app-not-visible-or-outside-pump',
    );
  }

  return const PumpOverlayRouteAction(type: 'hide', reason: 'session-inactive');
}
