import 'package:app/core/network/api_json_transport.dart';

const supportTicketEndpoint = '/v1/support/tickets';

typedef SupportTicketSubmitter =
    Future<SupportTicketSubmitResult> Function(
      SupportTicketSubmitRequest request,
    );

class SupportTicketSubmitRequest {
  const SupportTicketSubmitRequest({
    required this.artifactId,
    required this.values,
    required this.idempotencyKey,
    this.threadId,
    this.locale,
  });

  final String artifactId;
  final Map<String, Object?> values;
  final String idempotencyKey;
  final String? threadId;
  final String? locale;
}

class SupportTicketSubmitResult {
  const SupportTicketSubmitResult({
    required this.ticketNumber,
    required this.status,
  });

  final String ticketNumber;
  final String status;
}

class SupportTicketApiRepository {
  const SupportTicketApiRepository({required this.transport});

  final ApiJsonTransport transport;

  Future<SupportTicketSubmitResult> submit(
    SupportTicketSubmitRequest request,
  ) async {
    final values = request.values;
    final response = await transport.postJson(
      supportTicketEndpoint,
      headers: {'Idempotency-Key': request.idempotencyKey},
      body: <String, Object?>{
        'issue_type': _issueType(values['issue_type']),
        'issue_summary': _text(values['issue_summary']),
        if (_text(values['product_model']).isNotEmpty)
          'product_model': _text(values['product_model']),
        if (_text(values['order_number']).isNotEmpty)
          'order_number': _text(values['order_number']),
        if (_text(values['purchase_channel']).isNotEmpty)
          'purchase_channel': _text(values['purchase_channel']),
        if (_text(values['user_contact']).isNotEmpty)
          'user_contact': _text(values['user_contact']),
        'urgency': _urgency(values['urgency']),
        'source': 'agent_form',
        'payload': {'artifact_id': request.artifactId},
        if (_text(request.threadId).isNotEmpty)
          'thread_id': _text(request.threadId),
        if (_text(request.locale).isNotEmpty) 'locale': _text(request.locale),
      },
    );
    final ticketNumber = _text(response['ticket_number']);
    final status = _text(response['status']);
    if (ticketNumber.isEmpty || status.isEmpty) {
      throw const FormatException('Support ticket response is invalid.');
    }
    return SupportTicketSubmitResult(
      ticketNumber: ticketNumber,
      status: status,
    );
  }
}

String _issueType(Object? value) {
  const values = <String, String>{
    '设备故障': 'malfunction',
    '缺少配件': 'missing_parts',
    '疑似质量问题': 'defect',
    '保修': 'warranty',
    '退换货/退款': 'return_or_refund',
    '订单/物流': 'order_or_shipping',
    '使用帮助': 'usage_help',
    '安全问题': 'safety_concern',
    '其他': 'other',
  };
  const supported = <String>{
    'malfunction',
    'missing_parts',
    'defect',
    'warranty',
    'return_or_refund',
    'order_or_shipping',
    'usage_help',
    'safety_concern',
    'other',
  };
  final normalized = _text(value);
  return values[normalized] ??
      (supported.contains(normalized) ? normalized : 'other');
}

String _urgency(Object? value) {
  const values = <String, String>{
    '普通': 'normal',
    '较急': 'high',
    '安全相关': 'safety',
  };
  const supported = <String>{'normal', 'high', 'safety'};
  final normalized = _text(value);
  return values[normalized] ??
      (supported.contains(normalized) ? normalized : 'normal');
}

String _text(Object? value) => value?.toString().trim() ?? '';
