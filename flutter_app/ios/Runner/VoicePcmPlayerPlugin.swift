import AVFoundation
import Flutter
import Foundation

final class VoicePcmPlayerPlugin: NSObject, FlutterPlugin {
  private static let channelName = "com.momcozymai.flutter/voice_pcm_player"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(VoicePcmPlayerPlugin(), channel: channel)
  }

  private let audioQueue = DispatchQueue(label: "com.momcozymai.voice-pcm-player")
  private var engine: AVAudioEngine?
  private var player: AVAudioPlayerNode?
  private var format: AVAudioFormat?
  private var generation = 0
  private var pendingBufferCount = 0
  private var pendingFinishResults: [FlutterResult] = []

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      let arguments = call.arguments as? [String: Any]
      let sampleRate = (arguments?["sampleRate"] as? NSNumber)?.doubleValue ?? 24_000
      let channels = (arguments?["channels"] as? NSNumber)?.intValue ?? 1
      audioQueue.async { [weak self] in
        self?.start(sampleRate: sampleRate, channels: channels, result: result)
      }
    case "write":
      let arguments = call.arguments as? [String: Any]
      let bytes = (arguments?["bytes"] as? FlutterStandardTypedData)?.data ?? Data()
      audioQueue.async { [weak self] in
        self?.write(bytes, result: result)
      }
    case "finish":
      audioQueue.async { [weak self] in
        self?.finish(result: result)
      }
    case "stop":
      audioQueue.async { [weak self] in
        guard let self else { return }
        let replacedResults = self.stopLocked()
        replacedResults.forEach(self.replySuccess)
        self.replySuccess(result)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(
    sampleRate: Double,
    channels: Int,
    result: @escaping FlutterResult
  ) {
    guard sampleRate > 0, channels == 1 || channels == 2 else {
      replyError(
        result,
        code: "voice_pcm_invalid_format",
        message: "PCM output requires a positive sample rate and one or two channels."
      )
      return
    }

    let replacedResults = stopLocked()
    replacedResults.forEach(replySuccess)

    guard
      let pcmFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: sampleRate,
        channels: AVAudioChannelCount(channels),
        interleaved: true
      )
    else {
      replyError(
        result,
        code: "voice_pcm_unavailable",
        message: "Unable to create the PCM audio format."
      )
      return
    }

    let nextEngine = AVAudioEngine()
    let nextPlayer = AVAudioPlayerNode()
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
      try session.setActive(true)
      nextEngine.attach(nextPlayer)
      nextEngine.connect(nextPlayer, to: nextEngine.mainMixerNode, format: pcmFormat)
      try nextEngine.start()
      nextPlayer.play()
      engine = nextEngine
      player = nextPlayer
      format = pcmFormat
      replySuccess(result)
    } catch {
      nextPlayer.stop()
      nextEngine.stop()
      try? AVAudioSession.sharedInstance().setActive(
        false,
        options: [.notifyOthersOnDeactivation]
      )
      replyError(
        result,
        code: "voice_pcm_unavailable",
        message: error.localizedDescription
      )
    }
  }

  private func write(_ bytes: Data, result: @escaping FlutterResult) {
    guard let player, let format else {
      replyError(
        result,
        code: "voice_pcm_not_started",
        message: "PCM audio output is not started."
      )
      return
    }
    guard !bytes.isEmpty else {
      replySuccess(result)
      return
    }

    let bytesPerFrame = Int(format.streamDescription.pointee.mBytesPerFrame)
    guard bytesPerFrame > 0, bytes.count.isMultiple(of: bytesPerFrame) else {
      replyError(
        result,
        code: "voice_pcm_invalid_chunk",
        message: "PCM audio data does not contain complete frames."
      )
      return
    }

    let frameCount = bytes.count / bytesPerFrame
    guard frameCount <= Int(UInt32.max),
      let buffer = AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: AVAudioFrameCount(frameCount)
      ),
      let destination = buffer.mutableAudioBufferList.pointee.mBuffers.mData
    else {
      replyError(
        result,
        code: "voice_pcm_write_failed",
        message: "Unable to allocate a PCM audio buffer."
      )
      return
    }

    bytes.withUnsafeBytes { source in
      if let sourceAddress = source.baseAddress {
        memcpy(destination, sourceAddress, bytes.count)
      }
    }
    buffer.frameLength = AVAudioFrameCount(frameCount)
    buffer.mutableAudioBufferList.pointee.mBuffers.mDataByteSize = UInt32(bytes.count)

    let scheduledGeneration = generation
    pendingBufferCount += 1
    player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) {
      [weak self] _ in
      self?.audioQueue.async {
        self?.didPlayBuffer(generation: scheduledGeneration)
      }
    }
    if !player.isPlaying {
      player.play()
    }
    replySuccess(result)
  }

  private func finish(result: @escaping FlutterResult) {
    guard engine != nil else {
      replySuccess(result)
      return
    }
    guard pendingBufferCount > 0 else {
      stopLocked().forEach(replySuccess)
      replySuccess(result)
      return
    }
    pendingFinishResults.append(result)
  }

  private func didPlayBuffer(generation completedGeneration: Int) {
    guard completedGeneration == generation else { return }
    pendingBufferCount = max(0, pendingBufferCount - 1)
    if pendingBufferCount == 0, !pendingFinishResults.isEmpty {
      stopLocked().forEach(replySuccess)
    }
  }

  private func stopLocked() -> [FlutterResult] {
    generation &+= 1
    let finishResults = pendingFinishResults
    pendingFinishResults.removeAll()
    pendingBufferCount = 0
    player?.stop()
    engine?.stop()
    player = nil
    engine = nil
    format = nil
    try? AVAudioSession.sharedInstance().setActive(
      false,
      options: [.notifyOthersOnDeactivation]
    )
    return finishResults
  }

  private func replySuccess(_ result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      result(nil)
    }
  }

  private func replyError(
    _ result: @escaping FlutterResult,
    code: String,
    message: String
  ) {
    DispatchQueue.main.async {
      result(FlutterError(code: code, message: message, details: nil))
    }
  }
}
