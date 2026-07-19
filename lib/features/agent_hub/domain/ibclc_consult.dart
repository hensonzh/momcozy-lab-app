class IbclcConsultRouteDraft {
  const IbclcConsultRouteDraft({
    required this.consultId,
    required this.sourceArtifactId,
    this.consultantName = 'IBCLC 顾问',
    this.consultantCredentials = 'IBCLC 国际认证哺乳顾问',
    this.consultantExperience = '',
    this.consultantBio = '',
    this.chatLabel = '咨询 IBCLC',
    this.chatNote = '启动咨询后，会自动将你的问题同步给顾问',
    this.reason = '',
    this.feedingContext = '',
    this.urgency = 'routine',
    this.preferredLanguage = '',
  });

  final String consultId;
  final String sourceArtifactId;
  final String consultantName;
  final String consultantCredentials;
  final String consultantExperience;
  final String consultantBio;
  final String chatLabel;
  final String chatNote;
  final String reason;
  final String feedingContext;
  final String urgency;
  final String preferredLanguage;

  IbclcConsultRouteState resolve({
    String threadId = '',
    String runId = '',
    String returnPath = '/',
    double returnScrollOffset = 0,
  }) {
    return IbclcConsultRouteState(
      consultId: consultId,
      sourceArtifactId: sourceArtifactId,
      threadId: threadId,
      runId: runId,
      returnPath: safeIbclcReturnPath(returnPath),
      returnScrollOffset: returnScrollOffset < 0 ? 0 : returnScrollOffset,
      consultantName: consultantName,
      consultantCredentials: consultantCredentials,
      consultantExperience: consultantExperience,
      consultantBio: consultantBio,
      chatLabel: chatLabel,
      chatNote: chatNote,
      reason: reason,
      feedingContext: feedingContext,
      urgency: urgency,
      preferredLanguage: preferredLanguage,
    );
  }
}

class IbclcConsultRouteState {
  const IbclcConsultRouteState({
    required this.consultId,
    this.sourceArtifactId = '',
    this.threadId = '',
    this.runId = '',
    this.returnPath = '/',
    this.returnScrollOffset = 0,
    this.consultantName = 'IBCLC 顾问',
    this.consultantCredentials = 'IBCLC 国际认证哺乳顾问',
    this.consultantExperience = '',
    this.consultantBio = '',
    this.chatLabel = '咨询 IBCLC',
    this.chatNote = '启动咨询后，会自动将你的问题同步给顾问',
    this.reason = '',
    this.feedingContext = '',
    this.urgency = 'routine',
    this.preferredLanguage = '',
  });

  factory IbclcConsultRouteState.fromRoute({
    required Object? extra,
    required Uri? uri,
  }) {
    if (extra is IbclcConsultRouteState) return extra;
    final values = extra is Map
        ? Map<String, Object?>.from(extra)
        : const <String, Object?>{};
    final query = uri?.queryParameters ?? const <String, String>{};
    String value(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final raw = values[key] ?? query[key];
        if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      }
      return fallback;
    }

    final rawOffset =
        values['returnScrollOffset'] ??
        values['return_scroll_offset'] ??
        query['return_scroll_offset'];
    final offset = switch (rawOffset) {
      num number => number.toDouble(),
      String text => double.tryParse(text.trim()) ?? 0,
      _ => 0.0,
    };
    return IbclcConsultRouteState(
      consultId: value(const [
        'consultId',
        'consult_id',
      ], fallback: 'ibclc-flutter-default'),
      sourceArtifactId: value(const ['sourceArtifactId', 'source_artifact_id']),
      threadId: value(const ['threadId', 'thread_id']),
      runId: value(const ['runId', 'run_id']),
      returnPath: safeIbclcReturnPath(
        value(const ['returnPath', 'return_to'], fallback: '/'),
      ),
      returnScrollOffset: offset < 0 ? 0 : offset,
      consultantName: value(const [
        'consultantName',
        'consultant_name',
      ], fallback: 'Emily Chen'),
      consultantCredentials: value(const [
        'consultantCredentials',
        'consultant_credentials',
      ], fallback: 'IBCLC 国际认证哺乳顾问'),
      consultantExperience: value(const [
        'consultantExperience',
        'consultant_experience',
      ]),
      consultantBio: value(const ['consultantBio', 'consultant_bio']),
      chatLabel: value(const ['chatLabel', 'chat_label'], fallback: '咨询 IBCLC'),
      chatNote: value(const [
        'chatNote',
        'chat_note',
      ], fallback: '启动咨询后，会自动将你的问题同步给顾问'),
      reason: value(const ['reason']),
      feedingContext: value(const ['feedingContext', 'feeding_context']),
      urgency: value(const ['urgency'], fallback: 'routine'),
      preferredLanguage: value(const [
        'preferredLanguage',
        'preferred_language',
      ]),
    );
  }

  final String consultId;
  final String sourceArtifactId;
  final String threadId;
  final String runId;
  final String returnPath;
  final double returnScrollOffset;
  final String consultantName;
  final String consultantCredentials;
  final String consultantExperience;
  final String consultantBio;
  final String chatLabel;
  final String chatNote;
  final String reason;
  final String feedingContext;
  final String urgency;
  final String preferredLanguage;

  Map<String, Object?> eventMetadata() => {
    'consult_id': consultId,
    if (sourceArtifactId.isNotEmpty) 'source_artifact_id': sourceArtifactId,
    if (threadId.isNotEmpty) 'thread_id': threadId,
    'consultant_name': consultantName,
    'source': 'ibclc-chat',
    'handoff': 'vendor_h5_native',
    'return_to': returnPath,
    if (reason.isNotEmpty) 'reason': reason,
    if (feedingContext.isNotEmpty) 'feeding_context': feedingContext,
  };

  IbclcConsultRouteState withReturnContext({
    required String returnPath,
    required double returnScrollOffset,
  }) {
    return IbclcConsultRouteState(
      consultId: consultId,
      sourceArtifactId: sourceArtifactId,
      threadId: threadId,
      runId: runId,
      returnPath: safeIbclcReturnPath(returnPath),
      returnScrollOffset: returnScrollOffset < 0 ? 0 : returnScrollOffset,
      consultantName: consultantName,
      consultantCredentials: consultantCredentials,
      consultantExperience: consultantExperience,
      consultantBio: consultantBio,
      chatLabel: chatLabel,
      chatNote: chatNote,
      reason: reason,
      feedingContext: feedingContext,
      urgency: urgency,
      preferredLanguage: preferredLanguage,
    );
  }
}

class IbclcConsultCompletion {
  const IbclcConsultCompletion({
    required this.consultId,
    required this.completedAt,
    this.threadId = '',
  });

  factory IbclcConsultCompletion.fromMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid IBCLC completion.');
    }
    final map = Map<String, Object?>.from(value);
    final consultId = _text(map['consultId'] ?? map['consult_id']);
    final completedAt = DateTime.tryParse(
      _text(map['completedAt'] ?? map['completed_at']),
    );
    if (consultId.isEmpty || completedAt == null) {
      throw const FormatException('Invalid IBCLC completion.');
    }
    return IbclcConsultCompletion(
      consultId: consultId,
      threadId: _text(map['threadId'] ?? map['thread_id']),
      completedAt: completedAt,
    );
  }

  final String consultId;
  final String threadId;
  final DateTime completedAt;

  Map<String, Object?> toMap() => {
    'consultId': consultId,
    if (threadId.isNotEmpty) 'threadId': threadId,
    'completedAt': completedAt.toIso8601String(),
  };
}

String stableIbclcConsultId(String seed) {
  var hash = 0x811c9dc5;
  for (final codeUnit in seed.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return 'ibclc_${hash.toRadixString(16).padLeft(8, '0')}';
}

String safeIbclcReturnPath(String value) {
  final raw = value.trim();
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !raw.startsWith('/') ||
      raw.startsWith('//') ||
      raw.contains('\\') ||
      uri.pathSegments.contains('..') ||
      uri.path == '/ibclc-chat.html') {
    return '/';
  }
  return uri.toString();
}

String _text(Object? value) => value is String ? value.trim() : '';
