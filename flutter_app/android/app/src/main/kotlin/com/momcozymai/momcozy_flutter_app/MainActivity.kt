package com.momcozymai.momcozy_flutter_app

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
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
import java.util.Locale
import java.util.UUID

class MainActivity : FlutterActivity() {
    private lateinit var mmcBleChannel: MethodChannel
    private var scanCallback: ScanCallback? = null
    private val pumpAgentCompletedUploadKeys = mutableSetOf<String>()
    private var pumpAgentProcessL = 0
    private var pumpAgentProcessR = 0
    private var pumpAgentProcessAll = 0
    private var pumpAgentElapsedSeconds = 0
    private val gatts = mutableMapOf<String, BluetoothGatt>()
    private val connectResults = mutableMapOf<String, MethodChannel.Result>()
    private val readResults = mutableMapOf<String, MethodChannel.Result>()
    private val writeResults = mutableMapOf<String, MethodChannel.Result>()
    private val notifyResults = mutableMapOf<String, MethodChannel.Result>()
    private val notifyKeys = mutableSetOf<String>()

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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PUMP_AGENT_UPLOAD_CHANNEL
        ).setMethodCallHandler(::handlePumpAgentUploadCall)
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
            "connect" -> connectGatt(call, result)
            "disconnect" -> disconnectGatt(call, result)
            "write" -> writeGatt(call, result, withoutResponse = false)
            "writeWithoutResponse" -> writeGatt(call, result, withoutResponse = true)
            "startNotifications" -> startGattNotifications(call, result)
            "stopNotifications" -> stopGattNotifications(call, result)
            "getConnectedDevices" -> result.success(mapOf("devices" to connectedBleDevices()))
            "read" -> readGatt(call, result)
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

    private fun handlePumpAgentUploadCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setConfig",
            "markStepStop",
            "markStepPause",
            "setOperationSource" -> result.success(null)
            "sampleFromSnapshot" -> result.success(pumpAgentProgressMap())
            "resetProgress" -> {
                pumpAgentProcessL = 0
                pumpAgentProcessR = 0
                pumpAgentProcessAll = 0
                pumpAgentElapsedSeconds = 0
                pumpAgentCompletedUploadKeys.clear()
                result.success(pumpAgentProgressMap())
            }
            "uploadWorkstate",
            "getProcessData",
            "uploadProcess",
            "uploadMilkRecord" -> result.success(pumpAgentUploadResult(call))
            else -> result.notImplemented()
        }
    }

    override fun onDestroy() {
        stopBleScan()
        gatts.keys.toList().forEach(::closeGatt)
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

    private fun pumpAgentProgressMap(): Map<String, Any> {
        return mapOf(
            "processL" to pumpAgentProcessL,
            "processR" to pumpAgentProcessR,
            "processAll" to pumpAgentProcessAll,
            "elapsedSeconds" to pumpAgentElapsedSeconds
        )
    }

    private fun pumpAgentUploadResult(call: MethodCall): Map<String, Any?> {
        val body = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
        val uploadKey = "${call.method}:${body.toSortedString()}"
        val deduped = !pumpAgentCompletedUploadKeys.add(uploadKey)
        return mapOf(
            "body" to body,
            "response" to mapOf("error" to 0),
            "deduped" to deduped
        ) + pumpAgentProgressMap()
    }

    private fun Map<*, *>.toSortedString(): String {
        return entries
            .map { entry -> "${entry.key}=${entry.value}" }
            .sorted()
            .joinToString("&")
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

    @SuppressLint("MissingPermission")
    private fun connectGatt(call: MethodCall, result: MethodChannel.Result) {
        if (!hasBlePermissions()) {
            result.error("permission_denied", "Bluetooth permission is not granted", null)
            return
        }
        val deviceId = call.argument<String>("deviceId")
        if (deviceId.isNullOrBlank()) {
            result.error("invalid_args", "deviceId is required", null)
            return
        }
        val adapter = bluetoothManager()?.adapter
        if (adapter == null || !adapter.isEnabled) {
            result.error("adapter_unavailable", "Bluetooth adapter is unavailable", null)
            return
        }
        try {
            closeGatt(deviceId)
            val device = adapter.getRemoteDevice(deviceId)
            connectResults[deviceId] = result
            gatts[deviceId] = device.connectGatt(
                this,
                false,
                GattCallback(deviceId),
                BluetoothDevice.TRANSPORT_LE
            )
        } catch (error: RuntimeException) {
            connectResults.remove(deviceId)
            result.error("connect_failed", error.message ?: "Bluetooth connect failed", null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun disconnectGatt(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("deviceId")
        if (deviceId.isNullOrBlank()) {
            result.error("invalid_args", "deviceId is required", null)
            return
        }
        closeGatt(deviceId)
        result.success(null)
    }

    @SuppressLint("MissingPermission")
    private fun readGatt(call: MethodCall, result: MethodChannel.Result) {
        val ref = requireCharacteristic(call, result) ?: return
        val key = characteristicKey(ref.deviceId, ref.serviceUuid, ref.characteristicUuid)
        readResults[key] = result
        try {
            if (!ref.gatt.readCharacteristic(ref.characteristic)) {
                readResults.remove(key)
                result.error("read_failed", "readCharacteristic returned false", null)
            }
        } catch (error: RuntimeException) {
            readResults.remove(key)
            result.error("read_failed", error.message ?: "Bluetooth read failed", null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun writeGatt(
        call: MethodCall,
        result: MethodChannel.Result,
        withoutResponse: Boolean
    ) {
        val ref = requireCharacteristic(call, result) ?: return
        val value = byteArrayFrom(call.argument<List<Any?>>("value"))
        if (value == null) {
            result.error("invalid_args", "value must be a number array", null)
            return
        }
        val key = characteristicKey(ref.deviceId, ref.serviceUuid, ref.characteristicUuid)
        ref.characteristic.writeType = if (withoutResponse) {
            BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
        } else {
            BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        }
        @Suppress("DEPRECATION")
        ref.characteristic.value = value
        try {
            if (!ref.gatt.writeCharacteristic(ref.characteristic)) {
                result.error("write_failed", "writeCharacteristic returned false", null)
                return
            }
            if (withoutResponse) {
                result.success(null)
            } else {
                writeResults[key] = result
            }
        } catch (error: RuntimeException) {
            result.error("write_failed", error.message ?: "Bluetooth write failed", null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun startGattNotifications(call: MethodCall, result: MethodChannel.Result) {
        val ref = requireCharacteristic(call, result) ?: return
        val descriptor = ref.characteristic.getDescriptor(CLIENT_CHARACTERISTIC_CONFIG)
        if (descriptor == null) {
            result.error("notify_failed", "CCCD descriptor not found", null)
            return
        }
        val key = characteristicKey(ref.deviceId, ref.serviceUuid, ref.characteristicUuid)
        try {
            if (!ref.gatt.setCharacteristicNotification(ref.characteristic, true)) {
                result.error("notify_failed", "setCharacteristicNotification returned false", null)
                return
            }
            @Suppress("DEPRECATION")
            descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            notifyResults[key] = result
            @Suppress("DEPRECATION")
            if (!ref.gatt.writeDescriptor(descriptor)) {
                notifyResults.remove(key)
                result.error("notify_failed", "writeDescriptor returned false", null)
            }
        } catch (error: RuntimeException) {
            notifyResults.remove(key)
            result.error("notify_failed", error.message ?: "Bluetooth notify failed", null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun stopGattNotifications(call: MethodCall, result: MethodChannel.Result) {
        val ref = requireCharacteristic(call, result) ?: return
        val key = characteristicKey(ref.deviceId, ref.serviceUuid, ref.characteristicUuid)
        notifyKeys.remove(key)
        try {
            ref.gatt.setCharacteristicNotification(ref.characteristic, false)
        } catch (_: RuntimeException) {
        }
        result.success(null)
    }

    private fun requireCharacteristic(
        call: MethodCall,
        result: MethodChannel.Result
    ): CharacteristicRef? {
        val deviceId = call.argument<String>("deviceId")
        val serviceUuid = call.argument<String>("serviceUUID")
        val characteristicUuid = call.argument<String>("characteristicUUID")
        if (deviceId.isNullOrBlank() || serviceUuid.isNullOrBlank() || characteristicUuid.isNullOrBlank()) {
            result.error(
                "invalid_args",
                "deviceId, serviceUUID and characteristicUUID are required",
                null
            )
            return null
        }
        val gatt = gatts[deviceId]
        if (gatt == null) {
            result.error("not_connected", "Device is not connected", null)
            return null
        }
        val service = gatt.getService(parseUuid(serviceUuid))
        if (service == null) {
            result.error("service_not_found", "GATT service not found: $serviceUuid", null)
            return null
        }
        val characteristic = service.getCharacteristic(parseUuid(characteristicUuid))
        if (characteristic == null) {
            result.error(
                "characteristic_not_found",
                "GATT characteristic not found: $characteristicUuid",
                null
            )
            return null
        }
        return CharacteristicRef(deviceId, serviceUuid, characteristicUuid, gatt, characteristic)
    }

    @SuppressLint("MissingPermission")
    private fun closeGatt(deviceId: String) {
        rejectPendingForDevice(deviceId, "Bluetooth disconnected")
        notifyKeys.removeAll { key -> key.startsWith("$deviceId|") }
        val gatt = gatts.remove(deviceId) ?: return
        try {
            gatt.disconnect()
            gatt.close()
        } catch (_: RuntimeException) {
        }
    }

    private fun rejectPendingForDevice(deviceId: String, message: String) {
        connectResults.remove(deviceId)?.error("disconnected", message, null)
        rejectPendingMap(readResults, deviceId, message)
        rejectPendingMap(writeResults, deviceId, message)
        rejectPendingMap(notifyResults, deviceId, message)
    }

    private fun rejectPendingMap(
        pending: MutableMap<String, MethodChannel.Result>,
        deviceId: String,
        message: String
    ) {
        val keys = pending.keys.filter { key -> key.startsWith("$deviceId|") }
        keys.forEach { key ->
            pending.remove(key)?.error("disconnected", message, null)
        }
    }

    private fun characteristicKey(
        deviceId: String,
        serviceUuid: String,
        characteristicUuid: String
    ): String {
        return "$deviceId|${parseUuid(serviceUuid)}|${parseUuid(characteristicUuid)}"
    }

    private fun parseUuid(value: String): UUID {
        val normalized = value.lowercase(Locale.US)
        return if (normalized.length == 4) {
            UUID.fromString("0000$normalized-0000-1000-8000-00805f9b34fb")
        } else {
            UUID.fromString(normalized)
        }
    }

    private fun byteArrayFrom(values: List<Any?>?): ByteArray? {
        if (values == null) return null
        val out = ByteArray(values.size)
        values.forEachIndexed { index, value ->
            val number = value as? Number ?: return null
            out[index] = (number.toInt() and 0xff).toByte()
        }
        return out
    }

    private fun intListFrom(value: ByteArray?): List<Int> {
        if (value == null) return emptyList()
        return value.map { byte -> byte.toInt() and 0xff }
    }

    private data class CharacteristicRef(
        val deviceId: String,
        val serviceUuid: String,
        val characteristicUuid: String,
        val gatt: BluetoothGatt,
        val characteristic: BluetoothGattCharacteristic
    )

    private inner class GattCallback(private val deviceId: String) : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                try {
                    gatt.discoverServices()
                } catch (error: RuntimeException) {
                    connectResults.remove(deviceId)?.error(
                        "connect_failed",
                        error.message ?: "discoverServices failed",
                        null
                    )
                }
                return
            }
            if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                gatts.remove(deviceId)
                rejectPendingForDevice(deviceId, "Bluetooth disconnected")
                mmcBleChannel.invokeMethod(
                    "disconnected",
                    mapOf("deviceId" to deviceId, "status" to status)
                )
                try {
                    gatt.close()
                } catch (_: RuntimeException) {
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            val result = connectResults.remove(deviceId) ?: return
            if (status == BluetoothGatt.GATT_SUCCESS) {
                result.success(null)
            } else {
                result.error("connect_failed", "GATT discovery failed: $status", null)
            }
        }

        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
            status: Int
        ) {
            val key = characteristicKey(
                deviceId,
                characteristic.service.uuid.toString(),
                characteristic.uuid.toString()
            )
            val result = readResults.remove(key) ?: return
            if (status == BluetoothGatt.GATT_SUCCESS) {
                result.success(mapOf("value" to intListFrom(value)))
            } else {
                result.error("read_failed", "GATT read failed: $status", null)
            }
        }

        @Deprecated("Android 13 calls the overload with value.")
        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            @Suppress("DEPRECATION")
            onCharacteristicRead(gatt, characteristic, characteristic.value, status)
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            val key = characteristicKey(
                deviceId,
                characteristic.service.uuid.toString(),
                characteristic.uuid.toString()
            )
            val result = writeResults.remove(key) ?: return
            if (status == BluetoothGatt.GATT_SUCCESS) {
                result.success(null)
            } else {
                result.error("write_failed", "GATT write failed: $status", null)
            }
        }

        override fun onDescriptorWrite(
            gatt: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            status: Int
        ) {
            val characteristic = descriptor.characteristic
            val key = characteristicKey(
                deviceId,
                characteristic.service.uuid.toString(),
                characteristic.uuid.toString()
            )
            val result = notifyResults.remove(key) ?: return
            if (status == BluetoothGatt.GATT_SUCCESS) {
                notifyKeys.add(key)
                result.success(null)
            } else {
                result.error("notify_failed", "GATT descriptor write failed: $status", null)
            }
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray
        ) {
            emitNotification(characteristic, value)
        }

        @Deprecated("Android 13 calls the overload with value.")
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            @Suppress("DEPRECATION")
            emitNotification(characteristic, characteristic.value)
        }

        private fun emitNotification(
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray
        ) {
            val key = characteristicKey(
                deviceId,
                characteristic.service.uuid.toString(),
                characteristic.uuid.toString()
            )
            if (!notifyKeys.contains(key)) return
            mmcBleChannel.invokeMethod(
                "notification",
                mapOf(
                    "deviceId" to deviceId,
                    "serviceUUID" to characteristic.service.uuid.toString(),
                    "characteristicUUID" to characteristic.uuid.toString(),
                    "value" to intListFrom(value)
                )
            )
        }
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
        private val CLIENT_CHARACTERISTIC_CONFIG =
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        private const val MMC_BLE_CHANNEL = "com.momcozymai.flutter/mmc_ble"
        private const val PUMP_NOTIFICATION_CHANNEL =
            "com.momcozymai.flutter/pump_session_notification"
        private const val PUMP_AGENT_UPLOAD_CHANNEL =
            "com.momcozymai.flutter/pump_agent_upload"
        private const val REQUEST_BLE_PERMISSIONS = 4101
        private const val REQUEST_NOTIFICATION_PERMISSION = 4102
    }
}
