import 'dart:async';
import 'dart:convert';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'mom_inventory_transport.dart';

/// Raw SSE and HTTP control boundaries; real parser, runner and cancel client.
class AgentInventoryTransport extends MomInventoryTransport
    implements
        AgentStreamTransport,
        AgentStreamControlHttpConnector,
        AgentRunStatusReader {
  final requests = <AgentStreamRequest>[];
  final streams = <StreamController<String>>[];
  final controls = <Uri>[];
  final statusReads = <String>[];
  bool failConnections = false;
  int cancelStatus = 200;
  Completer<void>? cancelGate;

  @override
  Stream<String> frames(AgentStreamRequest request) {
    requests.add(request);
    final stream = StreamController<String>();
    streams.add(stream);
    if (failConnections) {
      stream.addError(
        const AgentStreamTransportException(
          'Isolated connection failure',
          isRetryable: true,
        ),
      );
    }
    return stream.stream;
  }

  void emit(
    int index,
    String type,
    int sequence,
    Map<String, Object?> payload, {
    int? run,
  }) {
    final r = run ?? index;
    final event = {
      'event_id': 'event-$r-$sequence',
      'type': type,
      'thread_id': '11111111-1111-4111-8111-111111111111',
      'run_id': 'inventory-run-$r',
      'message_id': 'inventory-message-$r',
      'sequence': sequence,
      'payload': payload,
    };
    streams[index].add('data: ${jsonEncode(event)}\n\n');
  }

  void fail(int index) => streams[index].addError(
    const AgentStreamTransportException(
      'Isolated connection failure',
      isRetryable: true,
    ),
  );

  @override
  Future<AgentRunStatusSnapshot> read(String runId) async {
    statusReads.add(runId);
    return AgentRunStatusSnapshot(
      runId: runId,
      status: AgentRunLifecycleStatus.unknown,
    );
  }

  @override
  Future<AgentStreamControlHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    Duration? timeout,
  }) async {
    controls.add(uri);
    await cancelGate?.future;
    return AgentStreamControlHttpResponse(statusCode: cancelStatus, body: '{}');
  }

  void disposeStreams() {
    if (cancelGate case final gate? when !gate.isCompleted) gate.complete();
    for (final stream in streams) {
      unawaited(stream.close());
    }
  }
}
