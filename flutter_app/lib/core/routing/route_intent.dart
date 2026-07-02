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

List<RouteIntent> routeIntentsFromPendingStorage(Map<String, Object?> storage) {
  final birthJourneyIntent = _planPendingIntent(
    raw: _string(storage['mmc_birth_journey_plan_nav_pending']),
    type: 'OpenStatusBirthJourneyBadge',
    path: '/status',
    fallbackPayload: const {'source': 'birthJourneyPlanChanged'},
  );
  final milkPlanIntent = _planPendingIntent(
    raw: _string(storage['mmc_milk_plan_nav_pending']),
    type: 'OpenSchedulePlanBadge',
    path: '/schedule',
    fallbackPayload: const {'source': 'milkPlanChanged'},
  );

  return [
    ?birthJourneyIntent,
    ?milkPlanIntent,
    if (_string(storage['mmc_pregnancy_diary_nav_pending']) == '1')
      const RouteIntent(
        type: 'OpenStatusPregnancyDiaryBadge',
        path: '/status',
        payload: {'source': 'pregnancyDiaryChanged'},
        consume: 'once',
      ),
  ];
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
  final query = uri?.queryParameters ?? const <String, String>{};
  final notify = _decodeObject(_string(payload['notifyJson']));
  final event = _string(notify?['event']);

  if (cleanPath == '/schedule' &&
      (event == 'schedule_reminder' || query['mmcNotify'] == '1')) {
    final intentPayload = <String, Object?>{'source': 'native-notification'};
    final taskId = _string(notify?['taskId']) ?? _string(notify?['task_id']);
    if (taskId != null && taskId.isNotEmpty) {
      intentPayload['taskId'] = taskId;
    }
    return RouteIntent(
      type: 'OpenScheduleReminder',
      path: '/schedule',
      payload: intentPayload,
      consume: 'once',
    );
  }

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

RouteIntent _routeIntentFromMediaLink(Map<String, Object?> link) {
  final kind = _string(link['kind']) ?? '';
  final url = _string(link['url']) ?? '';
  final title = _string(link['title']) ?? '';
  if (!_supportedMediaKinds.contains(kind) || url.isEmpty) {
    return const RouteIntent(
      type: 'ShowToast',
      payload: {'message': '该资料暂不支持应用内打开'},
    );
  }

  return RouteIntent(
    type: 'OpenMediaViewer',
    path: '/media-viewer',
    payload: {'kind': kind, 'title': title, 'url': _resolveMediaUrl(url)},
  );
}

List<RouteIntent> _routeIntentsFromIbclc(Map<String, Object?> input) {
  final intents = <RouteIntent>[];
  final start = _record(input['start']);
  if (start != null) {
    intents.add(
      RouteIntent(
        type: 'OpenIbclcChat',
        path:
            _safeSameOriginPath(_string(start['baseUrl'])) ??
            '/ibclc-chat.html',
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
  final source = _string(event['source']) ?? '';
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
  final uri = Uri.tryParse(route);
  final cleanPath = uri?.path ?? _stripQuery(route);

  if (source == 'AgentHub calibration card' && cleanPath == '/calibration') {
    return const RouteIntent(
      type: 'OpenCalibrationFromAgent',
      path: '/calibration',
      payload: {'source': 'agentArtifact'},
    );
  }
  if (source == 'Device start pump without calibration' &&
      cleanPath == '/calibration') {
    return const RouteIntent(
      type: 'OpenCalibrationRequired',
      path: '/calibration',
      payload: {'source': 'deviceStartPump'},
    );
  }
  if (source == 'Pump session missing connected device' &&
      cleanPath == '/device') {
    return const RouteIntent(
      type: 'OpenDeviceRequired',
      path: '/device',
      payload: {'source': 'pumpSession'},
    );
  }
  if (source == 'Calibration auto start' && cleanPath == '/pump') {
    final payload = <String, Object?>{
      'autoStarted': uri?.queryParameters['autoStarted'] == '1',
    };
    final from = uri?.queryParameters['from'];
    if (from != null) payload['from'] = from;
    return RouteIntent(
      type: 'OpenPumpSession',
      path: '/pump',
      payload: payload,
    );
  }

  return RouteIntent(
    type: 'AgentArtifactRouteIntent',
    payload: {'rawRoute': route, 'status': 'unknown'},
  );
}

RouteIntent? _planPendingIntent({
  required String? raw,
  required String type,
  required String path,
  required Map<String, Object?> fallbackPayload,
}) {
  if (raw == null) return null;
  final payload = raw == '1'
      ? fallbackPayload
      : _planPayloadFromRecord(_decodeObject(raw)) ?? fallbackPayload;
  return RouteIntent(type: type, path: path, payload: payload, consume: 'once');
}

Map<String, Object?>? _planPayloadFromRecord(Map<String, Object?>? record) {
  if (record == null) return null;
  final payload = <String, Object?>{};
  void putString(String key) {
    final value = _string(record[key]);
    if (value != null && value.trim().isNotEmpty) payload[key] = value;
  }

  putString('kind');
  putString('reason');
  putString('label');
  final planId = record['planId'] ?? record['plan_id'];
  if (planId is num && planId.isFinite) payload['planId'] = planId.toInt();
  putString('planType');
  final planTypeSnake = _string(record['plan_type']);
  if (!payload.containsKey('planType') &&
      planTypeSnake != null &&
      planTypeSnake.trim().isNotEmpty) {
    payload['planType'] = planTypeSnake;
  }
  final dates = _uniqueDateStrings(record['dates']);
  if (dates.isNotEmpty) payload['dates'] = dates;
  putString('summary');
  return payload.isEmpty ? null : payload;
}

List<String> _uniqueDateStrings(Object? value) {
  if (value is! List) return const [];
  final dates = <String>[];
  final seen = <String>{};
  for (final item in value) {
    if (item is! String) continue;
    final trimmed = item.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(trimmed)) continue;
    final date = trimmed.substring(0, 10);
    if (seen.add(date)) dates.add(date);
  }
  return dates;
}

String _resolveMediaUrl(String url) {
  if (url.startsWith('/skill-assets/')) return 'resolved-http-url:$url';
  return url;
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
