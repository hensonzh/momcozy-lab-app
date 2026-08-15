import 'package:flutter_timezone/flutter_timezone.dart';

import 'agent_stream_client.dart';

typedef AgentTimezoneLoader = Future<String> Function();

abstract interface class AgentRunCreateContextProvider {
  Future<AgentRunCreateContext> load();
}

class PlatformAgentRunCreateContextProvider
    implements AgentRunCreateContextProvider {
  PlatformAgentRunCreateContextProvider({
    AgentTimezoneLoader? timezoneLoader,
    DateTime Function()? now,
  }) : _timezoneLoader = timezoneLoader ?? _loadDeviceTimezone,
       _now = now ?? DateTime.now;

  final AgentTimezoneLoader _timezoneLoader;
  final DateTime Function() _now;

  @override
  Future<AgentRunCreateContext> load() async {
    final timezone = (await _timezoneLoader()).trim();
    if (!_looksLikeIanaTimezone(timezone)) {
      throw const AgentStreamPayloadException(
        'The device did not return a valid IANA timezone.',
      );
    }
    return AgentRunCreateContext(
      timezone: timezone,
      messageSentAt: formatRfc3339WithOffset(_now()),
    );
  }
}

Future<String> _loadDeviceTimezone() async {
  return (await FlutterTimezone.getLocalTimezone()).identifier;
}

String formatRfc3339WithOffset(DateTime value) {
  final offsetMinutes = value.timeZoneOffset.inMinutes;
  final sign = offsetMinutes < 0 ? '-' : '+';
  final absoluteMinutes = offsetMinutes.abs();
  final offsetHours = absoluteMinutes ~/ 60;
  final offsetRemainderMinutes = absoluteMinutes % 60;
  return '${_fourDigits(value.year)}-'
      '${_twoDigits(value.month)}-'
      '${_twoDigits(value.day)}T'
      '${_twoDigits(value.hour)}:'
      '${_twoDigits(value.minute)}:'
      '${_twoDigits(value.second)}'
      '$sign${_twoDigits(offsetHours)}:${_twoDigits(offsetRemainderMinutes)}';
}

bool _looksLikeIanaTimezone(String value) {
  if (value == 'UTC' || value == 'GMT') return true;
  return RegExp(
    r'^[A-Za-z][A-Za-z0-9._+-]*(?:/[A-Za-z0-9][A-Za-z0-9._+-]*)+$',
  ).hasMatch(value);
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _fourDigits(int value) => value.toString().padLeft(4, '0');
