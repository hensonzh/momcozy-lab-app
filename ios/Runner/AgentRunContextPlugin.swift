import Flutter
import Foundation

final class AgentRunContextPlugin: NSObject, FlutterPlugin {
  private static let channelName =
    "com.momcozymai.app/agent_run_context"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(AgentRunContextPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "localTimezone" {
      result(TimeZone.autoupdatingCurrent.identifier)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }
}
