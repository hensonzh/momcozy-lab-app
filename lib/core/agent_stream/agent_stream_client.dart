import 'agent_stream_event.dart';

class AgentStreamRequest {
  const AgentStreamRequest({
    required this.message,
    this.threadId,
    this.runId,
    this.afterSequence = 0,
    this.locale = 'en-US',
    this.timezone,
    this.messageSentAt,
    this.images = const <AgentStreamImageInput>[],
    this.metadata = const <String, Object?>{},
    this.idempotencyKey,
  });

  final String message;
  final String? threadId;
  final String? runId;
  final int afterSequence;
  final String locale;
  final String? timezone;
  final String? messageSentAt;
  final List<AgentStreamImageInput> images;
  final Map<String, Object?> metadata;
  final String? idempotencyKey;

  Map<String, Object?> toMap() => {
    'message': message,
    if (threadId != null) 'threadId': threadId,
    if (locale.trim().isNotEmpty) 'locale': locale,
    if (timezone?.trim().isNotEmpty ?? false) 'timezone': timezone,
    if (messageSentAt?.trim().isNotEmpty ?? false)
      'messageSentAt': messageSentAt,
    if (images.isNotEmpty)
      'images': images.map((image) => image.toMap()).toList(growable: false),
    if (metadata.isNotEmpty) 'metadata': metadata,
    if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
  };

  AgentStreamRequest resume({
    required String runId,
    required int afterSequence,
    String? threadId,
  }) {
    return AgentStreamRequest(
      message: message,
      threadId: threadId ?? this.threadId,
      runId: runId,
      afterSequence: afterSequence < 0 ? 0 : afterSequence,
      locale: locale,
      timezone: timezone,
      messageSentAt: messageSentAt,
      images: images,
      metadata: metadata,
      idempotencyKey: idempotencyKey,
    );
  }

  AgentStreamRequest withRunCreateContext(AgentRunCreateContext context) {
    return AgentStreamRequest(
      message: message,
      threadId: threadId,
      runId: runId,
      afterSequence: afterSequence,
      locale: locale,
      timezone: context.timezone,
      messageSentAt: context.messageSentAt,
      images: images,
      metadata: metadata,
      idempotencyKey: idempotencyKey,
    );
  }
}

class AgentRunCreateContext {
  const AgentRunCreateContext({
    required this.timezone,
    required this.messageSentAt,
  });

  final String timezone;
  final String messageSentAt;
}

class AgentStreamImageInput {
  const AgentStreamImageInput({
    this.assetId = '',
    required this.dataUrl,
    this.mimeType = 'image/png',
    this.name = 'image.png',
    this.size = 0,
    this.detail = 'auto',
  });

  final String assetId;
  final String dataUrl;
  final String mimeType;
  final String name;
  final int size;
  final String detail;

  Map<String, Object?> toMap() => {
    if (assetId.trim().isNotEmpty) 'assetId': assetId,
    'dataUrl': dataUrl,
    'mimeType': mimeType,
    'name': name,
    'size': size,
    'detail': detail,
  };

  Map<String, Object?> toProductionAttachment() {
    final normalizedAssetId = assetId.trim();
    if (normalizedAssetId.isEmpty) {
      throw const AgentStreamPayloadException(
        'Image upload must complete before sending.',
      );
    }
    return {
      'type': 'image',
      'asset_id': normalizedAssetId,
      'detail': detail.trim().isEmpty ? 'auto' : detail,
    };
  }
}

class AgentStreamPayloadException implements Exception {
  const AgentStreamPayloadException(this.message);

  final String message;

  @override
  String toString() => 'AgentStreamPayloadException($message)';
}

Map<String, Object?> buildProductionAgentRunPayload(
  AgentStreamRequest request, {
  String? idempotencyKey,
}) {
  final text = request.message.trim();
  if (text.isEmpty) {
    throw const AgentStreamPayloadException('Missing message.');
  }

  final threadId = request.threadId?.trim();
  final attachments = request.images
      .map((image) => image.toProductionAttachment())
      .toList(growable: true);
  final formSubmission = _productionFormSubmissionAttachment(request.metadata);
  if (formSubmission != null) attachments.add(formSubmission);
  final normalizedIdempotencyKey = (idempotencyKey ?? request.idempotencyKey)
      ?.trim();
  final normalizedLocale = request.locale.trim();
  final normalizedSource = _productionClientContextString(
    request.metadata['source'],
  );
  final normalizedTimezone = request.timezone?.trim();
  final normalizedMessageSentAt = request.messageSentAt?.trim();
  final hospitalBagCart = _productionHospitalBagCart(
    request.metadata['hospital_bag_cart'],
  );
  final clientContext = <String, Object?>{
    if (normalizedLocale.isNotEmpty) 'locale': normalizedLocale,
    if (normalizedTimezone != null && normalizedTimezone.isNotEmpty)
      'timezone': normalizedTimezone,
    if (normalizedMessageSentAt != null && normalizedMessageSentAt.isNotEmpty)
      'message_sent_at': normalizedMessageSentAt,
  };
  if (normalizedSource != null) clientContext['source'] = normalizedSource;
  if (hospitalBagCart != null) {
    clientContext['hospital_bag_cart'] = hospitalBagCart;
  }

  return {
    if (threadId != null && threadId.isNotEmpty && _looksLikeUuid(threadId))
      'thread_id': threadId,
    'message': text,
    if (attachments.isNotEmpty) 'attachments': attachments,
    if (clientContext.isNotEmpty) 'client_context': clientContext,
    'runtime_pattern': 'sdk_only',
    if (normalizedIdempotencyKey != null && normalizedIdempotencyKey.isNotEmpty)
      'idempotency_key': normalizedIdempotencyKey,
  };
}

String? _productionClientContextString(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

Map<String, Object?>? _productionHospitalBagCart(Object? value) {
  if (value == null) return null;
  final cart = _stringKeyedMap(value);
  if (cart == null) {
    throw const AgentStreamPayloadException('Invalid hospital bag cart.');
  }
  final rawGroups = cart['groups'];
  final rawTotals = cart['totals'];
  if (rawGroups is! List || rawTotals is! Map) {
    throw const AgentStreamPayloadException('Invalid hospital bag cart.');
  }

  return {
    'groups': rawGroups
        .map(_productionHospitalBagCartGroup)
        .toList(growable: false),
    'totals': _productionHospitalBagCartTotals(rawTotals),
  };
}

Map<String, Object?> _productionHospitalBagCartGroup(Object? value) {
  final group = _stringKeyedMap(value);
  final rawItems = group?['items'];
  if (group == null || rawItems is! List) {
    throw const AgentStreamPayloadException('Invalid hospital bag cart group.');
  }
  return {
    ..._allowedFields(group, const {'title', 'tone'}),
    'items': rawItems
        .map(_productionHospitalBagCartItem)
        .toList(growable: false),
  };
}

Map<String, Object?> _productionHospitalBagCartItem(Object? value) {
  final item = _stringKeyedMap(value);
  if (item == null) {
    throw const AgentStreamPayloadException('Invalid hospital bag cart item.');
  }
  return _allowedFields(item, const {
    'id',
    'name',
    'desc',
    'qty',
    'price',
    'currency',
    'price_label',
    'sale_price_label',
    'official_price_usd',
    'sale_price_usd',
    'exchange_rate_usd_cny',
    'product_url',
    'image_url',
    'image_alt',
    'sku_id',
    'model',
    'keywords',
  });
}

Map<String, Object?> _productionHospitalBagCartTotals(Object? value) {
  final totals = _stringKeyedMap(value);
  if (totals == null) {
    throw const AgentStreamPayloadException(
      'Invalid hospital bag cart totals.',
    );
  }
  final result = _allowedFields(totals, const {
    'currency',
    'subtotal',
    'itemCount',
    'discount',
    'shipping',
    'total',
    'exchange_rate_usd_cny',
    'converted_usd_subtotal',
    'mixed_currency',
  });
  if (!totals.containsKey('itemCount') && totals.containsKey('item_count')) {
    result['itemCount'] = totals['item_count'];
  }
  final rawCurrencyTotals = totals['currency_totals'];
  if (rawCurrencyTotals != null) {
    if (rawCurrencyTotals is! List) {
      throw const AgentStreamPayloadException(
        'Invalid hospital bag cart currency totals.',
      );
    }
    result['currency_totals'] = rawCurrencyTotals
        .map((value) {
          final currencyTotal = _stringKeyedMap(value);
          if (currencyTotal == null) {
            throw const AgentStreamPayloadException(
              'Invalid hospital bag cart currency total.',
            );
          }
          final result = _allowedFields(currencyTotal, const {
            'currency',
            'subtotal',
            'itemCount',
            'discount',
            'shipping',
            'total',
          });
          if (!currencyTotal.containsKey('itemCount') &&
              currencyTotal.containsKey('item_count')) {
            result['itemCount'] = currencyTotal['item_count'];
          }
          return result;
        })
        .toList(growable: false);
  }
  return result;
}

Map<String, Object?> _allowedFields(
  Map<String, Object?> source,
  Set<String> allowed,
) => {
  for (final entry in source.entries)
    if (allowed.contains(entry.key)) entry.key: entry.value,
};

Map<String, Object?>? _stringKeyedMap(Object? value) {
  if (value is! Map) return null;
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) return null;
    result[entry.key as String] = entry.value;
  }
  return result;
}

Map<String, Object?>? _productionFormSubmissionAttachment(
  Map<String, Object?> metadata,
) {
  final rawSubmission = metadata['form_submission'];
  if (rawSubmission == null) return null;
  if (rawSubmission is! Map) {
    throw const AgentStreamPayloadException('Invalid form submission.');
  }
  final submission = Map<String, Object?>.from(rawSubmission);
  final artifactId = submission['artifact_id']?.toString().trim() ?? '';
  final formId = submission['form_id']?.toString().trim() ?? '';
  final values = submission['values'];
  if (artifactId.isEmpty || formId.isEmpty || values is! Map) {
    throw const AgentStreamPayloadException('Invalid form submission.');
  }
  return {
    'type': 'form_submission',
    'artifact_id': artifactId,
    'form_id': formId,
    'values': Map<String, Object?>.from(values),
  };
}

bool _looksLikeUuid(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}

abstract interface class AgentStreamClient {
  Stream<AgentStreamEvent> stream(AgentStreamRequest request);
}

abstract interface class AgentStreamRetryableFailure {
  bool get isRetryable;
}

enum AgentRunLifecycleStatus {
  queued,
  running,
  waitingForConfirmation,
  completed,
  failed,
  cancelled,
  expired,
  unknown;

  bool get isActive => this == queued || this == running;

  bool get isTerminal => switch (this) {
    waitingForConfirmation ||
    completed ||
    failed ||
    cancelled ||
    expired => true,
    _ => false,
  };
}

class AgentRunStatusSnapshot {
  const AgentRunStatusSnapshot({
    required this.runId,
    required this.status,
    this.threadId,
    this.errorCode,
  });

  final String runId;
  final String? threadId;
  final AgentRunLifecycleStatus status;
  final String? errorCode;

  AgentStreamEvent? terminalEvent() {
    final eventType = switch (status) {
      AgentRunLifecycleStatus.waitingForConfirmation =>
        'run.waiting_for_confirmation',
      AgentRunLifecycleStatus.completed => 'run.completed',
      AgentRunLifecycleStatus.failed => 'run.failed',
      AgentRunLifecycleStatus.cancelled => 'run.cancelled',
      AgentRunLifecycleStatus.expired => 'run.expired',
      _ => null,
    };
    if (eventType == null) return null;

    return AgentStreamEvent({
      'event_id': 'run-status:$runId:${status.name}',
      'type': eventType,
      'run_id': runId,
      if (threadId?.trim().isNotEmpty ?? false) 'thread_id': threadId,
      'payload': {
        'reconciled_from_run_status': true,
        if (errorCode?.trim().isNotEmpty ?? false) 'code': errorCode,
      },
    });
  }
}

abstract interface class AgentRunStatusReader {
  Future<AgentRunStatusSnapshot> read(String runId);
}

abstract interface class AgentStreamTransport {
  Stream<String> frames(AgentStreamRequest request);
}

typedef AgentStreamFrameDecoder = List<AgentStreamEvent> Function(String frame);

class TransportAgnosticAgentStreamClient implements AgentStreamClient {
  const TransportAgnosticAgentStreamClient({
    required this.transport,
    required this.decodeFrame,
  });

  final AgentStreamTransport transport;
  final AgentStreamFrameDecoder decodeFrame;

  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) async* {
    await for (final frame in transport.frames(request)) {
      for (final event in decodeFrame(frame)) {
        yield event;
        if (event.isTerminal) return;
      }
    }
  }
}

class SseAgentStreamClient extends TransportAgnosticAgentStreamClient {
  const SseAgentStreamClient(AgentStreamTransport transport)
    : super(transport: transport, decodeFrame: parseAgentEventStream);
}

class JsonlAgentStreamClient extends TransportAgnosticAgentStreamClient {
  const JsonlAgentStreamClient(AgentStreamTransport transport)
    : super(transport: transport, decodeFrame: parseAgentJsonl);
}

class FixtureAgentStreamTransport implements AgentStreamTransport {
  const FixtureAgentStreamTransport(this.seedFrames);

  final Iterable<String> seedFrames;

  @override
  Stream<String> frames(AgentStreamRequest request) async* {
    for (final frame in seedFrames) {
      yield frame;
    }
  }
}
