package com.momcozymai.momcozy_flutter_app

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
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
    private lateinit var mmcBleChannel: MethodChannel
    private var scanCallback: ScanCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mmcBleChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MMC_BLE_CHANNEL
        )
        mmcBleChannel.setMethodCallHandler(::handleMmcBleCall)
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
            "requestLEScan" -> startBleScan(result)
            "stopLEScan" -> {
                stopBleScan()
                result.success(null)
            }
            "connect",
            "disconnect",
            "write",
            "writeWithoutResponse",
            "startNotifications",
            "stopNotifications" -> result.success(null)
            "getConnectedDevices" -> result.success(mapOf("devices" to connectedBleDevices()))
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

    override fun onDestroy() {
        stopBleScan()
        super.onDestroy()
    }

    private fun handlePumpNotificationCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermission" -> {
                requestNotificationPermissionIfNeeded()
                result.success(mapOf("granted" to hasNotificationPermission()))
            }
            "start",
            "update" -> {
                PumpSessionForegroundService.startOrUpdate(
                    this,
                    call.argument<String>("state") ?: "running",
                    call.argument<Int>("processAll") ?: 0,
                    call.argument<Int>("elapsedSeconds") ?: 0
                )
                result.success(null)
            }
            "stop" -> {
                PumpSessionForegroundService.stop(this)
                result.success(null)
            }
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

    @SuppressLint("MissingPermission")
    private fun startBleScan(result: MethodChannel.Result) {
        if (!hasBlePermissions()) {
            result.error("permission_denied", "Bluetooth permission is not granted", null)
            return
        }
        val scanner = bluetoothManager()?.adapter?.bluetoothLeScanner
        if (scanner == null) {
            result.error("scanner_unavailable", "Bluetooth LE scanner is unavailable", null)
            return
        }
        if (scanCallback != null) {
            result.success(null)
            return
        }
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                emitScanResult(result)
            }

            override fun onBatchScanResults(results: MutableList<ScanResult>) {
                results.forEach(::emitScanResult)
            }

            override fun onScanFailed(errorCode: Int) {
                scanCallback = null
                mmcBleChannel.invokeMethod(
                    "scanFailed",
                    mapOf("errorCode" to errorCode)
                )
            }
        }
        scanCallback = callback
        try {
            scanner.startScan(callback)
            result.success(null)
        } catch (error: RuntimeException) {
            scanCallback = null
            result.error("scan_failed", error.message ?: "Bluetooth scan failed", null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun stopBleScan() {
        val callback = scanCallback ?: return
        try {
            bluetoothManager()?.adapter?.bluetoothLeScanner?.stopScan(callback)
        } catch (_: RuntimeException) {
        }
        scanCallback = null
    }

    @SuppressLint("MissingPermission")
    private fun connectedBleDevices(): List<Map<String, Any?>> {
        if (!hasBlePermissions()) return emptyList()
        val manager = bluetoothManager() ?: return emptyList()
        return manager.getConnectedDevices(BluetoothProfile.GATT)
            .map { device -> deviceToMap(device, connected = true) }
    }

    @SuppressLint("MissingPermission")
    private fun emitScanResult(result: ScanResult) {
        val payload = mutableMapOf<String, Any?>(
            "device" to deviceToMap(result.device, connected = false),
            "rssi" to result.rssi
        )
        val localName = result.scanRecord?.deviceName
        if (!localName.isNullOrBlank()) payload["localName"] = localName
        mmcBleChannel.invokeMethod("scanResult", payload)
    }

    @SuppressLint("MissingPermission")
    private fun deviceToMap(device: BluetoothDevice, connected: Boolean): Map<String, Any?> {
        val name = device.name
        return mapOf(
            "deviceId" to device.address,
            "name" to (name ?: ""),
            "connected" to connected
        )
    }

    private fun bluetoothManager(): BluetoothManager? {
        return getSystemService(BLUETOOTH_SERVICE) as? BluetoothManager
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
