import 'dart:async';
import 'dart:convert';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'agent_inventory_transport.dart';

class AgentWorkflowInventoryTransport extends AgentInventoryTransport {
  final ticketBodies = <Map<String, Object?>>[];
  final ticketKeys = <String?>[];
  final actionBodies = <Map<String, Object?>>[];
  final actionKeys = <String?>[];
  Completer<void>? ticketGate, actionGate;
  bool failTicket = false;
  int actionStatus = 200;
  String actionResult = 'completed';

  void publish(
    int run,
    String type,
    int sequence,
    Map<String, Object?> payload, {
    String? artifactId,
    String? actionId,
  }) {
    final event = {
      'event_id': 'workflow-$run-$sequence',
      'type': type,
      'thread_id': '11111111-1111-4111-8111-111111111111',
      'run_id': 'inventory-run-$run',
      'message_id': 'inventory-message-$run',
      'sequence': sequence,
      'artifact_id': ?artifactId,
      'action_id': ?actionId,
      'payload': payload,
    };
    streams[run].add('data: ${jsonEncode(event)}\n\n');
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path != '/v1/support/tickets') {
      return super.postJson(path, body: body, headers: headers);
    }
    ticketBodies.add(body);
    ticketKeys.add(headers['Idempotency-Key']);
    await ticketGate?.future;
    if (failTicket) {
      throw const ApiHttpException(
        statusCode: 503,
        statusText: 'Unavailable',
        body: null,
      );
    }
    return {'ticket_number': 'INV-001', 'status': 'submitted'};
  }

  @override
  Future<AgentStreamControlHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    Duration? timeout,
  }) async {
    if (!uri.path.contains('/actions/')) {
      return super.post(uri, headers: headers, body: body, timeout: timeout);
    }
    controls.add(uri);
    actionBodies.add(Map<String, Object?>.from(jsonDecode(body) as Map));
    actionKeys.add(headers['Idempotency-Key']);
    await actionGate?.future;
    return AgentStreamControlHttpResponse(
      statusCode: actionStatus,
      body: jsonEncode({'status': actionResult}),
    );
  }

  @override
  void disposeStreams() {
    for (final gate in [ticketGate, actionGate]) {
      if (gate != null && !gate.isCompleted) gate.complete();
    }
    super.disposeStreams();
  }
}
