import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:app/features/agent_hub/data/platform_voice_input.dart';
import 'package:app/features/agent_hub/domain/agent_voice.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android records a valid WAV for Agent Hub transcription', (
    tester,
  ) async {
    final recorder = AgentHubPlatformVoiceRecorder();

    expect(
      await recorder.permissionState(),
      AgentVoiceInputPermissionState.granted,
      reason: 'Grant RECORD_AUDIO to the integration-test package first.',
    );

    await recorder.start();
    await tester.pump(const Duration(milliseconds: 500));
    final recording = await recorder.stop();

    expect(recording, isNotNull);
    expect(recording!.mimeType, 'audio/wav');
    expect(recording.name, 'speech.wav');
    expect(recording.bytes.length, greaterThan(44));
    expect(recording.durationMs, greaterThanOrEqualTo(450));
    expect(String.fromCharCodes(recording.bytes.take(4)), 'RIFF');
  });
}
