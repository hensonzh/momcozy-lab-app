package com.momcozymai.momcozy_flutter_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MMC_BLE_CHANNEL
        ).setMethodCallHandler(::handleMmcBleCall)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PUMP_NOTIFICATION_CHANNEL
        ).setMethodCallHandler(::handlePumpNotificationCall)
    }

    private fun handleMmcBleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "permissionState" -> result.success(mapOf("state" to blePermissionState()))
            "initialize" -> {
                requestBlePermissionsIfNeeded()
                result.success(mapOf("state" to blePermissionState()))
            }
            "requestLEScan",
            "stopLEScan",
            "connect",
            "disconnect",
            "write",
            "writeWithoutResponse",
            "startNotifications",
            "stopNotifications" -> result.success(null)
            "getConnectedDevices" -> result.success(mapOf("devices" to emptyList<Map<String, Any>>()))
            "read" -> result.success(mapOf("value" to emptyList<Int>()))
            "openBluetoothSettings" -> {
                startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                result.success(null)
            }
            "openAppSettings" -> {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handlePumpNotificationCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermission" -> {
                requestNotificationPermissionIfNeeded()
                result.success(mapOf("granted" to hasNotificationPermission()))
            }
            "start",
            "update",
            "stop",
            "showCompletionNotice",
            "showAutoEndNotice",
            "enqueuePendingNavigate" -> result.success(null)
            "consumePendingNavigate" -> result.success(mapOf("path" to ""))
            "restoreSnapshot" -> result.success(null)
            else -> result.notImplemented()
        }
    }

    private fun requestBlePermissionsIfNeeded() {
        if (hasBlePermissions()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            requestPermissions(
                arrayOf(
                    Manifest.permission.BLUETOOTH_SCAN,
                    Manifest.permission.BLUETOOTH_CONNECT
                ),
                REQUEST_BLE_PERMISSIONS
            )
        } else {
            requestPermissions(
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
                REQUEST_BLE_PERMISSIONS
            )
        }
    }

    private fun hasBlePermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
                checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } else {
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun blePermissionState(): String {
        return if (hasBlePermissions()) "granted" else "denied"
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (hasNotificationPermission()) return
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_NOTIFICATION_PERMISSION
        )
    }

    private fun hasNotificationPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }

    companion object {
        private const val MMC_BLE_CHANNEL = "com.momcozymai.flutter/mmc_ble"
        private const val PUMP_NOTIFICATION_CHANNEL =
            "com.momcozymai.flutter/pump_session_notification"
        private const val REQUEST_BLE_PERMISSIONS = 4101
        private const val REQUEST_NOTIFICATION_PERMISSION = 4102
    }
}
