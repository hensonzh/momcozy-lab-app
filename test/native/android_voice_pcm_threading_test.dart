import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android PCM playback stays off the platform main thread', () {
    final source = File(
      'android/app/src/main/kotlin/com/momcozymai/'
      'app/MainActivity.kt',
    ).readAsStringSync();

    expect(source, contains('HandlerThread(VOICE_PCM_THREAD_NAME)'));
    expect(source, contains('private val voiceAudioHandler'));
    expect(source, contains('voiceMainHandler.post'));
    final channelHandler = RegExp(
      r'private fun handleVoicePcmPlayerCall[\s\S]*?override fun onDestroy',
    ).firstMatch(source)?.group(0);
    expect(channelHandler, isNotNull);
    for (final method in ['start', 'write', 'finish', 'stop']) {
      expect(
        RegExp(
          '"$method"\\s*->(?:\\s*\\{)?[\\s\\S]*?'
          'voiceAudioHandler\\.post\\s*\\{',
        ).hasMatch(channelHandler!),
        isTrue,
        reason: '$method must enqueue work on the PCM audio thread',
      );
    }

    final finishMethod = RegExp(
      r'private fun finishVoicePcmPlayback[\s\S]*?'
      r'private fun playbackHeadFrames',
    ).firstMatch(source)?.group(0);
    expect(finishMethod, isNotNull);
    expect(finishMethod, contains('voiceAudioHandler.postDelayed'));
    expect(finishMethod, isNot(contains('Handler(Looper.getMainLooper())')));
  });
}
