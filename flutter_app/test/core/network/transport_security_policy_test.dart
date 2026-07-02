import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/network/transport_security_policy.dart';

void main() {
  group('TransportSecurityPolicy', () {
    test('allows HTTPS and WSS remote endpoints', () {
      expect(
        TransportSecurityPolicy.requireSecureHttp(
          Uri.parse('https://api.example.test/v1'),
        ),
        Uri.parse('https://api.example.test/v1'),
      );
      expect(
        AgentStreamEndpoint(
          uri: Uri.parse('wss://agent.example.test/v1/agent/runs/run-1/stream'),
        ).uri,
        Uri.parse('wss://agent.example.test/v1/agent/runs/run-1/stream'),
      );
    });

    test('keeps HTTP and WS limited to local development hosts', () {
      expect(
        TransportSecurityPolicy.requireSecureHttp(
          Uri.parse('http://127.0.0.1:8769'),
        ),
        Uri.parse('http://127.0.0.1:8769'),
      );
      expect(
        AgentStreamEndpoint(
          uri: Uri.parse('ws://localhost:8769/v1/agent/runs/run-1/stream'),
        ).uri,
        Uri.parse('ws://localhost:8769/v1/agent/runs/run-1/stream'),
      );
      expect(
        TransportSecurityPolicy.isLocalDevelopmentUri(
          Uri.parse('http://[::1]:8769'),
        ),
        isTrue,
      );
    });

    test('rejects remote plaintext HTTP and WebSocket endpoints', () {
      expect(
        () => IoApiJsonTransport(baseUri: Uri.parse('http://api.example.test')),
        throwsArgumentError,
      );
      expect(
        () => IoApiMultipartTransport(
          baseUri: Uri.parse('http://uploads.example.test'),
        ),
        throwsArgumentError,
      );
      expect(
        () => AgentStreamEndpoint(
          uri: Uri.parse('ws://agent.example.test/v1/agent/runs/run-1/stream'),
        ),
        throwsArgumentError,
      );
    });
  });
}
