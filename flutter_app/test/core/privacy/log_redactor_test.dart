import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/privacy/log_redactor.dart';

void main() {
  group('log redactor', () {
    test('redacts sensitive keys inside nested maps and lists', () {
      final payload = <String, Object?>{
        'Authorization': 'Bearer secret-token',
        'user_id': 'demo-user',
        'conversationId': 'conv-1',
        'deviceId': 'ble-left-001',
        'url': 'wss://api.example.test/ws?token=secret&mode=voice',
        'safe': 'kept',
        'nested': {'session_id': 'session-1', 'milkMl': 42},
        'events': [
          {'thread_id': 'thread-1', 'elapsedSeconds': 180},
        ],
      };

      final redacted = redactLogMap(payload);

      expect(redacted, {
        'Authorization': '***',
        'user_id': '***',
        'conversationId': '***',
        'deviceId': '***',
        'url': 'wss://api.example.test/ws?token=***&mode=voice',
        'safe': 'kept',
        'nested': {'session_id': '***', 'milkMl': 42},
        'events': [
          {'thread_id': '***', 'elapsedSeconds': 180},
        ],
      });
      expect(payload['Authorization'], 'Bearer secret-token');
    });

    test('redacts sensitive query parameters in log URLs', () {
      final url = redactUrlForLog(
        'wss://api.example.test/api/ag-ui-ws?token=secret'
        '&user_id=demo-user&conversation_id=conv-1&mode=voice#frag',
      );

      expect(
        url,
        'wss://api.example.test/api/ag-ui-ws?token=***'
        '&user_id=***&conversation_id=***&mode=voice#frag',
      );
    });

    test('leaves non-sensitive values readable for diagnostics', () {
      expect(isSensitiveLogKey('milkMl'), isFalse);
      expect(isSensitiveLogKey('elapsedSeconds'), isFalse);
      expect(
        redactLogValue(Uri.parse('https://example.test/path?mode=debug')),
        'https://example.test/path?mode=debug',
      );
    });
  });
}
