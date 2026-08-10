import 'package:flutter_webrtc/flutter_webrtc.dart';

abstract interface class MotionRealtimeAudioSession {
  Future<void> activate();

  Future<void> deactivate();
}

class WebRtcMotionRealtimeAudioSession implements MotionRealtimeAudioSession {
  @override
  Future<void> activate() async {
    await Helper.setAndroidAudioConfiguration(
      AndroidAudioConfiguration.communication,
    );
    if (WebRTC.platformIsIOS) await Helper.ensureAudioSession();
    if (WebRTC.platformIsAndroid || WebRTC.platformIsIOS) {
      await Helper.setSpeakerphoneOnButPreferBluetooth();
    }
  }

  @override
  Future<void> deactivate() async {
    if (WebRTC.platformIsAndroid) {
      await Helper.clearAndroidCommunicationDevice();
    }
    await Helper.setAndroidAudioConfiguration(AndroidAudioConfiguration.media);
  }
}
