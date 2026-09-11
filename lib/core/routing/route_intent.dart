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

List<RouteIntent> routeIntentsFromAgentNavigationEvents(List<Object?> events) {
  return events
      .whereType<Map>()
      .map((value) => Map<String, Object?>.from(value))
      .map(_routeIntentFromAgentNavigationEvent)
      .whereType<RouteIntent>()
      .toList(growable: false);
}

List<RouteIntent> routeIntentsFromMediaAndIbclcInput(
  Map<String, Object?> input,
) {
  final intents = <RouteIntent>[];
  final mediaLinks = input['mediaLinks'];
  if (mediaLinks is List) {
    intents.addAll(
      mediaLinks.whereType<Map>().map((value) {
        return _routeIntentFromMediaLink(Map<String, Object?>.from(value));
      }),
    );
  }

  final ibclc = _record(input['ibclc']);
  if (ibclc != null) intents.addAll(_routeIntentsFromIbclc(ibclc));
  return intents;
}

RouteIntent? routeIntentFromNativeNotification(Map<String, Object?> payload) {
  final path = _string(payload['path']) ?? '/';
  if (_isUnsafeRoute(path)) {
    return const RouteIntent(
      type: 'RejectUnsafeRoute',
      payload: {'reason': 'unsupported-scheme'},
    );
  }

  final uri = Uri.tryParse(path);
  final cleanPath = uri?.path ?? _stripQuery(path);
  final notify = _decodeObject(_string(payload['notifyJson']));

  if (cleanPath == '/schedule') {
    return const RouteIntent(
      type: 'OpenSchedule',
      path: '/schedule',
      payload: {'source': 'native-navigation'},
      consume: 'once',
    );
  }

  if (cleanPath == '/pump' && notify == null) {
    return const RouteIntent(
      type: 'OpenLactation',
      path: '/me/lactation',
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
      if (_isRetiredSkillAssetUrl(url)) {
        return const RouteIntent(
          type: 'ShowToast',
          payload: {'message': '该资料已失效，请获取最新资料。'},
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

RouteIntent _routeIntentFromMediaLink(Map<String, Object?> link) {
  final kind = _string(link['kind']) ?? '';
  final url = _string(link['url']) ?? '';
  final title = _string(link['title']) ?? '';
  if (_isRetiredSkillAssetUrl(url)) {
    return const RouteIntent(
      type: 'ShowToast',
      payload: {'message': '该资料已失效，请获取最新资料。'},
    );
  }
  if (!_supportedMediaKinds.contains(kind) || url.isEmpty) {
    return const RouteIntent(
      type: 'ShowToast',
      payload: {'message': '该资料暂不支持应用内打开'},
    );
  }

  return RouteIntent(
    type: 'OpenMediaViewer',
    path: '/media-viewer',
    payload: {'kind': kind, 'title': title, 'url': url},
  );
}

List<RouteIntent> _routeIntentsFromIbclc(Map<String, Object?> input) {
  final intents = <RouteIntent>[];
  final start = _record(input['start']);
  if (start != null) {
    intents.add(
      RouteIntent(
        type: 'OpenServiceCatalog',
        path: '/services',
        payload: {
          'consultId': _string(start['consultId']) ?? '',
          'threadId': _string(start['threadId']) ?? '',
          'returnTo': _safeSameOriginPath(_string(start['returnTo'])) ?? '/',
          'userId': _string(start['userId']) ?? '',
        },
      ),
    );
  }

  final viewport = _record(input['storedReturnViewport']);
  final completion = _record(input['completionPayload']);
  final returnTo = _safeSameOriginPath(_string(viewport?['return_to']));
  if (viewport != null && completion != null && returnTo != null) {
    intents.add(
      RouteIntent(
        type: 'ReturnFromIbclc',
        path: returnTo,
        payload: {
          'consultId':
              _string(viewport['consult_id']) ??
              _string(completion['consult_id']) ??
              '',
          'scrollTop': _int(viewport['scroll_top']),
          'scrollHeight': _int(viewport['scroll_height']),
          'completionEvent': _string(completion['event_type']) ?? '',
        },
        consume: 'once',
      ),
    );
  }

  return intents;
}

RouteIntent? _routeIntentFromAgentNavigationEvent(Map<String, Object?> event) {
  final link = _record(event['link']);
  final linkAction = _string(link?['action']);
  if (linkAction == 'open-schedule') {
    return const RouteIntent(
      type: 'OpenScheduleFromAgent',
      path: '/schedule',
      payload: {'source': 'agentBubbleLink', 'action': 'open-schedule'},
    );
  }

  final navigate = _record(event['navigate']);
  final navigatePath = _string(navigate?['path']);
  final navigateState = _record(navigate?['state']);
  final agentPrefill = _string(navigateState?['agentPrefill']);
  if (navigatePath == '/' && agentPrefill != null && agentPrefill.isNotEmpty) {
    return RouteIntent(
      type: 'OpenAgentHubWithPrefill',
      path: '/',
      payload: {'agentPrefill': agentPrefill, 'autoSend': true},
    );
  }

  final customEvent = _record(event['customEvent']);
  final customEventName = _string(customEvent?['name']);
  if (customEventName == 'navigate-to' &&
      _string(customEvent?['detail']) == '/schedule') {
    return const RouteIntent(
      type: 'OpenSchedule',
      path: '/schedule',
      payload: {'source': 'inlineFlow'},
    );
  }
  if (customEventName == 'hub-start-work-flow') {
    return const RouteIntent(
      type: 'OpenAgentHubAndStartWorkFlow',
      path: '/',
      payload: {'prompt': '我想制定返工计划'},
    );
  }

  final route = _string(event['route']);
  if (route == null || route.isEmpty) return null;
  return RouteIntent(
    type: 'AgentArtifactRouteIntent',
    payload: {'rawRoute': route, 'status': 'unknown'},
  );
}

bool _isRetiredSkillAssetUrl(String url) {
  return Uri.tryParse(url.trim())?.path.startsWith('/skill-assets/') == true;
}

String? _safeSameOriginPath(String? value) {
  if (value == null || value.isEmpty || _isUnsafeReturnTo(value)) return null;
  return value;
}

int _int(Object? value) {
  if (value is num && value.isFinite) return value.toInt();
  return 0;
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

const _supportedMediaKinds = {'pdf', 'image', 'video'};
