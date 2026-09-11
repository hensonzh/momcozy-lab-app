import Flutter
import UIKit
import UserNotifications

final class NotificationPermissionPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "momcozy/notifications_permission", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(NotificationPermissionPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    switch call.method {
    case "getPermission":
      permission(result)
    case "requestPermission":
      center.getNotificationSettings { settings in
        guard settings.authorizationStatus == .notDetermined else {
          self.permission(result)
          return
        }
        center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in self.permission(result) }
      }
    case "openSettings":
      let address: String
      if #available(iOS 16.0, *) {
        address = UIApplication.openNotificationSettingsURLString
      } else {
        address = UIApplication.openSettingsURLString
      }
      if let url = URL(string: address) { UIApplication.shared.open(url) }
      result(nil)
    case "clearNotifications":
      center.getDeliveredNotifications { delivered in
        let identifiers = delivered.filter { $0.request.content.userInfo["notification_id"] != nil }.map { $0.request.identifier }
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        DispatchQueue.main.async { UIApplication.shared.applicationIconBadgeNumber = 0; result(nil) }
      }
    case "setBadge":
      let count = max(0, (call.arguments as? [String: Any])?["count"] as? Int ?? 0)
      if #available(iOS 16.0, *) {
        center.setBadgeCount(count) { _ in DispatchQueue.main.async { result(nil) } }
      } else {
        UIApplication.shared.applicationIconBadgeNumber = count
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func permission(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let value: String
      if settings.authorizationStatus == .notDetermined { value = "not_determined" }
      else if settings.authorizationStatus == .denied { value = "denied" }
      else if settings.authorizationStatus == .authorized { value = "authorized" }
      else if settings.authorizationStatus == .provisional { value = "provisional" }
      else if #available(iOS 14.0, *), settings.authorizationStatus == .ephemeral { value = "provisional" }
      else { value = "unavailable" }
      DispatchQueue.main.async { result(value) }
    }
  }
}
