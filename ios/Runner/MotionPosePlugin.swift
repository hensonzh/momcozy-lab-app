import AVFoundation
import Flutter
import ImageIO
import UIKit
import Vision

fileprivate protocol MotionPoseViewControlling: AnyObject {
  func start()
  func stop()
}

final class MotionPosePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private static let controlChannel = "com.momcozymai.motion_pose/control"
  private static let eventChannel = "com.momcozymai.motion_pose/events"
  private static let viewType = "com.momcozymai.motion_pose/preview"

  private var eventSink: FlutterEventSink?
  private weak var currentView: MotionPoseViewControlling?
  private var startRequested = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = MotionPosePlugin()
    let methods = FlutterMethodChannel(
      name: controlChannel,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(
      name: eventChannel,
      binaryMessenger: registrar.messenger()
    )
    events.setStreamHandler(instance)
    registrar.register(
      MotionPoseViewFactory(plugin: instance),
      withId: viewType
    )
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestPermission":
      requestPermissions(result: result)
    case "start":
      guard hasCameraPermission else {
        result(
          FlutterError(
            code: "permission_denied",
            message: "Camera permission is required",
            details: nil
          )
        )
        return
      }
      startRequested = true
      currentView?.start()
      result(nil)
    case "stop":
      startRequested = false
      currentView?.stop()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  fileprivate func attach(_ view: MotionPoseViewControlling) {
    currentView?.stop()
    currentView = view
    if startRequested && hasCameraPermission {
      view.start()
    }
  }

  fileprivate func emit(_ event: [String: Any]) {
    DispatchQueue.main.async { [weak self] in self?.eventSink?(event) }
  }

  fileprivate func emitError(code: String, message: String) {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(FlutterError(code: code, message: message, details: nil))
    }
  }

  private var hasCameraPermission: Bool {
    AVCaptureDevice.authorizationStatus(for: .video) == .authorized
  }

  private func requestPermissions(result: @escaping FlutterResult) {
    requestAccess(for: .video) { cameraGranted in
      DispatchQueue.main.async { result(cameraGranted) }
    }
  }

  private func requestAccess(
    for mediaType: AVMediaType,
    completion: @escaping (Bool) -> Void
  ) {
    switch AVCaptureDevice.authorizationStatus(for: mediaType) {
    case .authorized:
      completion(true)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: mediaType, completionHandler: completion)
    default:
      completion(false)
    }
  }
}

private final class MotionPoseViewFactory: NSObject, FlutterPlatformViewFactory {
  private let plugin: MotionPosePlugin

  init(plugin: MotionPosePlugin) {
    self.plugin = plugin
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    if #available(iOS 14.0, *) {
      let view = MotionPosePlatformView(frame: frame, plugin: plugin)
      plugin.attach(view)
      return view
    }
    let view = MotionPoseUnsupportedPlatformView(frame: frame, plugin: plugin)
    plugin.attach(view)
    return view
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

private final class MotionPoseUnsupportedPlatformView: NSObject,
  FlutterPlatformView, MotionPoseViewControlling
{
  private let container: UIView
  private weak var plugin: MotionPosePlugin?

  init(frame: CGRect, plugin: MotionPosePlugin) {
    container = UIView(frame: frame)
    self.plugin = plugin
    super.init()
    container.backgroundColor = .black
  }

  func view() -> UIView { container }

  func start() {
    plugin?.emitError(
      code: "unsupported_ios_version",
      message: "Dynamic posture assessment requires iOS 14 or later"
    )
  }

  func stop() {}
}

private final class MotionPreviewContainer: UIView {
  var previewLayer: AVCaptureVideoPreviewLayer?

  override func layoutSubviews() {
    super.layoutSubviews()
    previewLayer?.frame = bounds
  }
}

@available(iOS 14.0, *)
fileprivate final class MotionPosePlatformView: NSObject, FlutterPlatformView,
  AVCaptureVideoDataOutputSampleBufferDelegate, MotionPoseViewControlling
{
  private let container: MotionPreviewContainer
  private weak var plugin: MotionPosePlugin?
  private let session = AVCaptureSession()
  private let cameraQueue = DispatchQueue(label: "com.momcozymai.motion_pose.camera")
  private let visionQueue = DispatchQueue(label: "com.momcozymai.motion_pose.vision")
  private let poseRequest = VNDetectHumanBodyPoseRequest()
  private var configured = false
  private var running = false
  private var lastAnalyzedTime: CFTimeInterval = 0

  init(frame: CGRect, plugin: MotionPosePlugin) {
    container = MotionPreviewContainer(frame: frame)
    self.plugin = plugin
    super.init()
    container.backgroundColor = .black
  }

  func view() -> UIView { container }

  func start() {
    guard !running else { return }
    running = true
    cameraQueue.async { [weak self] in
      guard let self, self.running else { return }
      do {
        if !self.configured {
          try self.configureSession()
          self.configured = true
        }
        if !self.session.isRunning { self.session.startRunning() }
      } catch {
        self.running = false
        self.plugin?.emitError(
          code: "camera_start_failed",
          message: error.localizedDescription
        )
      }
    }
  }

  func stop() {
    running = false
    cameraQueue.async { [weak self] in
      guard let self, self.session.isRunning else { return }
      self.session.stopRunning()
    }
  }

  private func configureSession() throws {
    session.beginConfiguration()
    defer { session.commitConfiguration() }
    session.sessionPreset = .hd1280x720

    guard
      let camera = AVCaptureDevice.default(
        .builtInWideAngleCamera,
        for: .video,
        position: .front
      )
    else {
      throw MotionPoseError.cameraUnavailable
    }
    let input = try AVCaptureDeviceInput(device: camera)
    guard session.canAddInput(input) else { throw MotionPoseError.cameraUnavailable }
    session.addInput(input)

    let output = AVCaptureVideoDataOutput()
    output.alwaysDiscardsLateVideoFrames = true
    output.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String:
        kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    ]
    output.setSampleBufferDelegate(self, queue: visionQueue)
    guard session.canAddOutput(output) else { throw MotionPoseError.cameraUnavailable }
    session.addOutput(output)
    if let connection = output.connection(with: .video) {
      if connection.isVideoOrientationSupported { connection.videoOrientation = .portrait }
      if connection.isVideoMirroringSupported { connection.isVideoMirrored = true }
    }

    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.videoGravity = .resizeAspectFill
    if let connection = previewLayer.connection {
      if connection.isVideoOrientationSupported { connection.videoOrientation = .portrait }
      if connection.isVideoMirroringSupported { connection.isVideoMirrored = true }
    }
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.container.layer.insertSublayer(previewLayer, at: 0)
      self.container.previewLayer = previewLayer
      self.container.setNeedsLayout()
    }
  }

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard running else { return }
    let now = CACurrentMediaTime()
    guard now - lastAnalyzedTime >= 0.066 else { return }
    lastAnalyzedTime = now
    let startedAt = CACurrentMediaTime()
    do {
      let handler = VNImageRequestHandler(
        cmSampleBuffer: sampleBuffer,
        orientation: .leftMirrored,
        options: [:]
      )
      try handler.perform([poseRequest])
      let observations = Array((poseRequest.results ?? []).prefix(2))
      let poses = try observations.map(encodePose)
      let timestamp = Int64(
        CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
          * 1000
      )
      let inference = Int64((CACurrentMediaTime() - startedAt) * 1000)
      let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
      let rawWidth = pixelBuffer.map { CVPixelBufferGetWidth($0) } ?? 1
      let rawHeight = pixelBuffer.map { CVPixelBufferGetHeight($0) } ?? 1
      plugin?.emit([
        "timestamp_ms": timestamp,
        "inference_ms": inference,
        "input_width": rawHeight,
        "input_height": rawWidth,
        "engine": "apple_vision_body_pose",
        "poses": poses,
      ])
    } catch {
      plugin?.emitError(
        code: "pose_inference_failed",
        message: error.localizedDescription
      )
    }
  }

  private func encodePose(
    _ observation: VNHumanBodyPoseObservation
  ) throws -> [String: Any] {
    let points = try observation.recognizedPoints(.all)
    var landmarks = Array(
      repeating: [
        "x": 0.0,
        "y": 0.0,
        "z": 0.0,
        "visibility": 0.0,
        "presence": 0.0,
      ],
      count: 33
    )
    let mapping: [(Int, VNHumanBodyPoseObservation.JointName)] = [
      (0, .nose),
      (2, .leftEye),
      (5, .rightEye),
      (7, .leftEar),
      (8, .rightEar),
      (11, .leftShoulder),
      (12, .rightShoulder),
      (13, .leftElbow),
      (14, .rightElbow),
      (15, .leftWrist),
      (16, .rightWrist),
      (23, .leftHip),
      (24, .rightHip),
      (25, .leftKnee),
      (26, .rightKnee),
      (27, .leftAnkle),
      (28, .rightAnkle),
    ]
    var reliable: [CGPoint] = []
    for (index, name) in mapping {
      guard let point = points[name] else { continue }
      let confidence = Double(point.confidence)
      let x = Double(point.location.x)
      let y = 1.0 - Double(point.location.y)
      landmarks[index] = [
        "x": x,
        "y": y,
        "z": 0.0,
        "visibility": confidence,
        "presence": confidence,
      ]
      if confidence >= 0.35 {
        reliable.append(CGPoint(x: x, y: y))
      }
    }
    let extentPoints = reliable.isEmpty ? [CGPoint(x: 0.5, y: 0.5)] : reliable
    let minX = extentPoints.map(\.x).min() ?? 0
    let maxX = extentPoints.map(\.x).max() ?? 0
    let minY = extentPoints.map(\.y).min() ?? 0
    let maxY = extentPoints.map(\.y).max() ?? 0
    return [
      "center_x": Double((minX + maxX) / 2),
      "center_y": Double((minY + maxY) / 2),
      "body_scale": Double(max(maxX - minX, maxY - minY)),
      "landmarks": landmarks,
    ]
  }

  deinit { stop() }
}

private enum MotionPoseError: LocalizedError {
  case cameraUnavailable

  var errorDescription: String? {
    switch self {
    case .cameraUnavailable:
      return "Front camera is unavailable"
    }
  }
}
