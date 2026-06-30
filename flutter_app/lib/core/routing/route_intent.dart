import 'dart:convert';

class RouteIntent {
  const RouteIntent({
    required this.type,
    this.path,
    this.payload = const <String, Object?>{},
    this.consume,
  });

  final String type;
  final String? path;
  final Map<String, Object?> payload;
  final String? consume;
}

List<RouteIntent> routeIntentsFromNativePayloads(List<Object?> payloads) {
  return payloads
      .whereType<Map<String, Object?>>()
      .map(routeIntentFromNativeNotification)
      .whereType<RouteIntent>()
      .toList(growable: false);
}

RouteIntent? routeIntentFromNativeNotification(Map<String, Object?> payload) {
  final path = _string(payload['path']) ?? '/';
  if (_isUnsafeRoute(path)) {
    return const RouteIntent(
      type: 'RejectUnsafeRoute',
      payload: {'reason': 'unsupported-scheme'},
    );
  }

  final cleanPath = _stripQuery(path);
  final notify = _decodeObject(_string(payload['notifyJson']));
  final event = _string(notify?['event']);

  if (cleanPath == '/status' && event == 'grown') {
    return const RouteIntent(
      type: 'OpenStatusGrowthHighlight',
      path: '/status',
      payload: {'source': 'native-notification', 'highlight': 'growth'},
      consume: 'once',
    );
  }

  if (cleanPath == '/pump' && notify == null) {
    return const RouteIntent(
      type: 'OpenPumpSession',
      path: '/pump',
      payload: {'source': 'pumpForegroundNotification'},
      consume: 'once',
    );
  }

  if (cleanPath == '/' &&
      notify == null &&
      payload['autoEndTeardown'] == true) {
    return const RouteIntent(
      type: 'OpenAgentHubAndRunPumpTeardown',
      path: '/',
      payload: {
        'source': 'pumpAutoEndNotification',
        'dedupe': 'tryRunPumpAutoEndOffPumpTeardownOnce',
      },
      consume: 'once',
    );
  }

  if (cleanPath != '/') {
    return RouteIntent(
      type: 'NotFoundIntent',
      path: cleanPath,
      payload: const {'fallback': 'AgentHub'},
    );
  }

  switch (event) {
    case 'summary':
    case 'mom_baby':
      final card = _record(notify?['analysis_card']);
      return RouteIntent(
        type: 'OpenAgentHubWithAnalysisCard',
        path: '/',
        payload: {
          'kind': _string(card?['kind']) ?? event,
          'chatMessageId': _string(notify?['chatMessageId']),
          'message': _string(notify?['body']) ?? '',
          'notification': false,
        },
        consume: 'once',
      );
    case 'milk_analysis':
      final card = _record(notify?['analysis_card']);
      return RouteIntent(
        type: 'OpenAgentHubWithMilkAnalysis',
        path: '/',
        payload: {
          'kind': _string(card?['kind']) ?? 'milk_analysis',
          'chatMessageId': _string(notify?['chatMessageId']),
          'message': _string(notify?['body']) ?? '',
          'notification': true,
          'requiresContextEvent': true,
          'requiresFollowupQueue': true,
        },
        consume: 'once',
      );
    case 'health_issue':
      return RouteIntent(
        type: 'OpenAgentHubWithHealthIssue',
        path: '/',
        payload: {
          'kind': 'health_issue',
          'chatMessageId': _string(notify?['chatMessageId']),
          'message': _string(notify?['body']) ?? '',
        },
        consume: 'once',
      );
  }

  if (notify == null && path == '/') return null;
  return RouteIntent(type: 'OpenAgentHub', path: cleanPath, consume: 'once');
}

RouteIntent routeIntentFromFallbackCase(Map<String, Object?> inputCase) {
  switch (_string(inputCase['source'])) {
    case 'native-notification':
      return routeIntentFromNativeNotification(inputCase) ??
          const RouteIntent(type: 'OpenAgentHub', path: '/');
    case 'media-viewer':
      final state = _record(inputCase['state']);
      final url = _string(state?['url']);
      if (url == null || url.isEmpty) {
        return const RouteIntent(
          type: 'MediaViewerMissingResource',
          path: '/media-viewer',
          payload: {'message': '缺少资源参数，请从资料卡片进入。'},
        );
      }
      return RouteIntent(type: 'OpenMediaViewer', path: '/media-viewer');
    case 'ibclc-return':
      final returnTo = _string(inputCase['returnTo']) ?? '/';
      if (_isUnsafeReturnTo(returnTo)) {
        return const RouteIntent(
          type: 'RejectUnsafeReturnTo',
          payload: {'fallback': '/'},
        );
      }
      return RouteIntent(type: 'IbclcReturnIntent', path: returnTo);
    case 'agent-artifact':
      final route = _string(inputCase['route']) ?? '';
      return RouteIntent(
        type: 'AgentArtifactRouteIntent',
        payload: {'rawRoute': route, 'status': 'unknown'},
      );
    default:
      return const RouteIntent(
        type: 'NotFoundIntent',
        payload: {'fallback': 'AgentHub'},
      );
  }
}

Map<String, Object?>? _decodeObject(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(value);
    return _record(decoded);
  } on FormatException {
    return null;
  }
}

Map<String, Object?>? _record(Object? value) {
  if (value is Map) return Map<String, Object?>.from(value);
  return null;
}

String? _string(Object? value) => value is String ? value : null;

String _stripQuery(String path) => path.split('?').first;

bool _isUnsafeRoute(String path) {
  final lower = path.toLowerCase();
  return lower.startsWith('javascript:') ||
      lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('//');
}

bool _isUnsafeReturnTo(String path) {
  return _isUnsafeRoute(path) || !path.startsWith('/');
}
