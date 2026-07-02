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
        'text': 'private voice playback text',
        'transcript': 'private speech transcript',
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
        'text': '***',
        'transcript': '***',
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
        'https://api.example.test/v1/agent/runs/run-1/stream?token=secret'
        '&user_id=demo-user&conversation_id=conv-1'
        '&text=private%20voice%20text&mode=voice#frag',
      );

      expect(
        url,
        'https://api.example.test/v1/agent/runs/run-1/stream?token=***'
        '&user_id=***&conversation_id=***'
        '&text=***&mode=voice#frag',
      );
    });

    test('leaves non-sensitive values readable for diagnostics', () {
      expect(isSensitiveLogKey('serialNumber'), isTrue);
      expect(isSensitiveLogKey('text'), isTrue);
      expect(isSensitiveLogKey('message'), isTrue);
      expect(isSensitiveLogKey('milkMl'), isFalse);
      expect(isSensitiveLogKey('elapsedSeconds'), isFalse);
      expect(
        redactLogValue(Uri.parse('https://example.test/path?mode=debug')),
        'https://example.test/path?mode=debug',
      );
    });

    test(
      'redacts full health data containers while keeping scalar diagnostics',
      () {
        final payload = <String, Object?>{
          'healthData': {'milkMl': 120, 'symptoms': 'private note'},
          'growth_records': [
            {'weight_g': 6200, 'height_cm': 64.5},
          ],
          'pregnancyDiary': {'mood': 'tired'},
          'milkMl': 42,
        };

        expect(redactLogMap(payload), {
          'healthData': '***',
          'growth_records': '***',
          'pregnancyDiary': '***',
          'milkMl': 42,
        });
      },
    );

    test('builds crash reports without sensitive context fields', () {
      final report = redactCrashReport(
        error: StateError(
          'failed Bearer secret-token '
          'https://api.example.test/path?token=secret&mode=debug',
        ),
        stackTrace: StackTrace.fromString('#0 PumpPage.finish\n#1 main'),
        context: <String, Object?>{
          'route': '/pump',
          'feature': 'pump-session',
          'statusCode': 503,
          'requestId': 'req-123',
          'user_id': 'demo-user',
          'threadId': 'thread-1',
          'healthData': {'milkMl': 120, 'symptoms': 'private note'},
          'message': 'baby private note',
          'metadata': {'token': 'nested-token'},
        },
      );

      expect(report['errorType'], 'StateError');
      expect(
        report['error'],
        'Bad state: failed Bearer *** '
        'https://api.example.test/path?token=***&mode=debug',
      );
      expect(report['stack'], ['#0 PumpPage.finish', '#1 main']);
      expect(report['context'], {
        'route': '/pump',
        'feature': 'pump-session',
        'statusCode': 503,
        'requestId': 'req-123',
        'user_id': '***',
        'threadId': '***',
        'healthData': '***',
        'message': '***',
        'metadata': '***',
      });
      expect(report.toString(), isNot(contains('secret-token')));
      expect(report.toString(), isNot(contains('private note')));
      expect(report.toString(), isNot(contains('demo-user')));
      expect(report.toString(), isNot(contains('thread-1')));
    });
  });
}
