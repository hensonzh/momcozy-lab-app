import AVFoundation
import Flutter

/// Plays backend PCM incrementally; vendor credentials and text stay in Dart's HTTPS request.
final class ChatFirstPcmPlayer: NSObject, FlutterPlugin {
  private var engine: AVAudioEngine?
  private var player: AVAudioPlayerNode?
  private var format: AVAudioFormat?
  private var pending = 0
  private var generation = 0
  private var finishResult: FlutterResult?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "momcozy/chat_first_pcm", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ChatFirstPcmPlayer(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      stop()
      do {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try AVAudioSession.sharedInstance().setActive(true)
        guard let pcm = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000,
                                      channels: 1, interleaved: true) else {
          throw NSError(domain: "voice", code: 1)
        }
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: pcm)
        try engine.start()
        player.play()
        self.engine = engine
        self.player = player
        self.format = pcm
        result(nil)
      } catch {
        stop()
        result(FlutterError(code: "audio_unavailable", message: "PCM output is unavailable", details: nil))
      }
    case "write":
      guard let bytes = (call.arguments as? FlutterStandardTypedData)?.data,
            !bytes.isEmpty, bytes.count % 2 == 0,
            let player = player, let format = format,
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(bytes.count / 2)),
            let samples = buffer.int16ChannelData?.pointee else {
        result(FlutterError(code: "invalid_pcm", message: "PCM frame is invalid", details: nil))
        return
      }
      buffer.frameLength = buffer.frameCapacity
      bytes.withUnsafeBytes { raw in
        if let base = raw.baseAddress { memcpy(samples, base, bytes.count) }
      }
      let run = generation
      pending += 1
      player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
        DispatchQueue.main.async {
          guard let self = self, self.generation == run else { return }
          self.pending -= 1
          if self.pending == 0, let completion = self.finishResult {
            self.finishResult = nil
            completion(nil)
          }
        }
      }
      result(nil)
    case "finish":
      if pending == 0 { result(nil) }
      else { finishResult = result }
    case "stop":
      stop()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func stop() {
    generation += 1
    finishResult?(nil)
    finishResult = nil
    pending = 0
    player?.stop()
    engine?.stop()
    player = nil
    engine = nil
    format = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
  }
}
