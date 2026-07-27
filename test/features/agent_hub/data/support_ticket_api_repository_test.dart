import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/network/api_json_transport.dart';
import 'package:app/features/agent_hub/data/support_ticket_api_repository.dart';

void main() {
  test(
    'submits the support form using backend enum values and idempotency',
    () async {
      final transport = _RecordingTransport();
      final repository = SupportTicketApiRepository(transport: transport);

      final result = await repository.submit(
        const SupportTicketSubmitRequest(
          artifactId: 'support-ticket-1',
          values: {
            'issue_type': '设备故障',
            'issue_summary': ' 吸奶器无法启动 ',
            'product_model': ' Air1 ',
            'order_number': ' MC123 ',
            'purchase_channel': ' 官网 ',
            'urgency': '安全相关',
          },
          threadId: 'thread-1',
          locale: 'zh-CN',
          idempotencyKey: 'agent-form-submit-1',
        ),
      );

      expect(transport.path, supportTicketEndpoint);
      expect(transport.headers, {'Idempotency-Key': 'agent-form-submit-1'});
      expect(transport.body, {
        'issue_type': 'malfunction',
        'issue_summary': '吸奶器无法启动',
        'product_model': 'Air1',
        'order_number': 'MC123',
        'purchase_channel': '官网',
        'urgency': 'safety',
        'source': 'agent_form',
        'payload': {'artifact_id': 'support-ticket-1'},
        'thread_id': 'thread-1',
        'locale': 'zh-CN',
      });
      expect(result.ticketNumber, 'MC-20260713-001');
      expect(result.status, 'open');
    },
  );
}

class _RecordingTransport implements ApiJsonTransport {
  String? path;
  Map<String, Object?>? body;
  Map<String, String>? headers;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    this.path = path;
    this.body = Map<String, Object?>.from(body);
    this.headers = Map<String, String>.from(headers);
    return const {'ticket_number': 'MC-20260713-001', 'status': 'open'};
  }
}
