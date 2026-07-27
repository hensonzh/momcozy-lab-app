import 'package:flutter/services.dart';

import 'agent_stream_client.dart';

const agentRunCreateContextChannelName = 'com.momcozymai.app/agent_run_context';

abstract interface class AgentRunCreateContextProvider {
  Future<AgentRunCreateContext> load();
}

class PlatformAgentRunCreateContextProvider
    implements AgentRunCreateContextProvider {
  PlatformAgentRunCreateContextProvider({
    MethodChannel? channel,
    DateTime Function()? now,
  }) : _channel =
           channel ?? const MethodChannel(agentRunCreateContextChannelName),
       _now = now ?? DateTime.now;

  final MethodChannel _channel;
  final DateTime Function() _now;

  @override
  Future<AgentRunCreateContext> load() async {
    final timezone = await _loadTimezone();
    return AgentRunCreateContext(
      timezone: timezone,
      messageSentAt: formatRfc3339WithOffset(_now()),
    );
  }

  Future<String> _loadTimezone() async {
    final timezone = (await _channel.invokeMethod<String>(
      'localTimezone',
    ))?.trim();
    if (timezone == null || !_looksLikeIanaTimezone(timezone)) {
      throw const AgentStreamPayloadException(
        'The device did not return a valid IANA timezone.',
      );
    }
    return timezone;
  }
}

String formatRfc3339WithOffset(DateTime value) {
  final offset = value.timeZoneOffset;
  final offsetMinutes = offset.inMinutes;
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
