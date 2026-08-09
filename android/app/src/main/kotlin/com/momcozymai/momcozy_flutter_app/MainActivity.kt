package com.momcozymai.momcozy_flutter_app

import android.Manifest
import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
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
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.UUID

class MainActivity : FlutterActivity() {
    private lateinit var mmcBleChannel: MethodChannel
    private lateinit var pumpNotificationChannel: MethodChannel
    private lateinit var voicePcmPlayerChannel: MethodChannel
    private lateinit var pumpAgentUploadHandler: PumpAgentUploadChannelHandler
    private lateinit var pumpAgentBackgroundRunner: PumpAgentBackgroundRunner
    private lateinit var motionPosePlugin: MotionPosePlugin
    private var scanCallback: ScanCallback? = null
    private val gatts = mutableMapOf<String, BluetoothGatt>()
    private val connectResults = mutableMapOf<String, MethodChannel.Result>()
    private val readResults = mutableMapOf<String, MethodChannel.Result>()
    private val writeResults = mutableMapOf<String, MethodChannel.Result>()
    private val notifyResults = mutableMapOf<String, MethodChannel.Result>()
    private val notifyKeys = mutableSetOf<String>()
    private var pendingBlePermissionResult: MethodChannel.Result? = null
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null
    private val voiceMainHandler = Handler(Looper.getMainLooper())
    private val voiceAudioThread = HandlerThread(VOICE_PCM_THREAD_NAME).apply { start() }
    private val voiceAudioHandler = Handler(voiceAudioThread.looper)
    private var voiceAudioTrack: AudioTrack? = null
    private var voiceAudioTrackSampleRate = 24000
    private var voiceAudioTrackChannels = 1
    private var voiceAudioTrackWrittenFrames = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mmcBleChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MMC_BLE_CHANNEL
        )
        mmcBleChannel.setMethodCallHandler(::handleMmcBleCall)
        pumpNotificationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PUMP_NOTIFICATION_CHANNEL
        )
        pumpNotificationChannel.setMethodCallHandler(::handlePumpNotificationCall)
        voicePcmPlayerChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VOICE_PCM_PLAYER_CHANNEL
        )
        voicePcmPlayerChannel.setMethodCallHandler(::handleVoicePcmPlayerCall)
        val pumpAgentUploadChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PUMP_AGENT_UPLOAD_CHANNEL
        )
        pumpAgentUploadHandler = PumpAgentUploadChannelHandler(this, pumpAgentUploadChannel)
        pumpAgentBackgroundRunner = PumpAgentBackgroundRunner(
            pumpAgentUploadHandler
        ) { state, processAll, elapsedSeconds ->
            PumpSessionForegroundService.startOrUpdate(
                applicationContext,
                state,
                processAll,
                elapsedSeconds
            )
        }
        pumpAgentUploadChannel.setMethodCallHandler(pumpAgentUploadHandler::handle)
        motionPosePlugin = MotionPosePlugin(this, flutterEngine)
        handleLaunchNavigationIntent(intent)
    }

    private fun handleMmcBleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "permissionState" -> result.success(mapOf("state" to blePermissionState()))
            "initialize" -> {
                if (!requestBlePermissionsIfNeeded(result)) {
                    result.success(mapOf("state" to blePermissionState()))
                }
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

    private fun handleVoicePcmPlayerCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val args = call.argumentsMap()
                val sampleRate = (args["sampleRate"] as? Number)?.toInt() ?: 24000
                val channels = (args["channels"] as? Number)?.toInt() ?: 1
                voiceAudioHandler.post {
                    startVoicePcmPlayback(sampleRate, channels, result)
                }
            }
            "write" -> {
                val bytes = (call.argumentsMap()["bytes"] as? ByteArray)?.copyOf()
                    ?: ByteArray(0)
                voiceAudioHandler.post {
                    writeVoicePcmChunk(bytes, result)
                }
            }
            "finish" -> {
                voiceAudioHandler.post {
                    finishVoicePcmPlayback(result)
                }
            }
            "stop" -> {
                voiceAudioHandler.post {
                    stopVoicePcmPlayback()
                    replyVoiceSuccess(result)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onDestroy() {
        if (::pumpAgentBackgroundRunner.isInitialized) {
            pumpAgentBackgroundRunner.stop()
        }
        pendingBlePermissionResult?.error(
            "permission_request_cancelled",
            "Bluetooth permission request was cancelled",
            null
        )
        pendingBlePermissionResult = null
        pendingNotificationPermissionResult?.error(
            "permission_request_cancelled",
            "Notification permission request was cancelled",
            null
        )
        pendingNotificationPermissionResult = null
        if (::voicePcmPlayerChannel.isInitialized) {
            voicePcmPlayerChannel.setMethodCallHandler(null)
        }
        if (::motionPosePlugin.isInitialized) {
            motionPosePlugin.dispose()
        }
        voiceAudioHandler.post {
            stopVoicePcmPlayback()
            voiceAudioThread.quitSafely()
        }
        stopBleScan()
        gatts.keys.toList().forEach(::closeGatt)
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            REQUEST_BLE_PERMISSIONS -> {
                pendingBlePermissionResult?.success(
                    mapOf("state" to blePermissionState())
                )
                pendingBlePermissionResult = null
            }
            REQUEST_NOTIFICATION_PERMISSION -> {
                pendingNotificationPermissionResult?.success(
                    mapOf("granted" to hasNotificationPermission())
                )
                pendingNotificationPermissionResult = null
            }
            else -> {
                if (::motionPosePlugin.isInitialized &&
                    motionPosePlugin.handlePermissionResult(requestCode)
                ) {
                    return
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleLaunchNavigationIntent(intent)
    }

    private fun handlePumpNotificationCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermission" -> {
                if (!requestNotificationPermissionIfNeeded(result)) {
                    result.success(mapOf("granted" to hasNotificationPermission()))
                }
            }
            "start",
            "update" -> {
                val active = call.argument<Boolean>("active") ?: true
                val state = call.argument<String>("state") ?: "running"
                val processAll = call.argument<Int>("processAll") ?: 0
                val elapsedSeconds = call.argument<Int>("elapsedSeconds") ?: 0
                if (active) {
                    PumpSessionForegroundService.startOrUpdate(
                        this,
                        state,
                        processAll,
                        elapsedSeconds,
                        call.argument<Int>("leftMilkMl"),
                        call.argument<Int>("rightMilkMl")
                    )
                    pumpAgentBackgroundRunner.startOrUpdate(state, elapsedSeconds)
                } else {
                    pumpAgentBackgroundRunner.stop()
                    PumpSessionForegroundService.stop(this)
                }
                result.success(null)
            }
            "stop" -> {
                pumpAgentBackgroundRunner.stop()
                PumpSessionForegroundService.stop(this)
                result.success(null)
            }
            "showCompletionNotice" -> {
                PumpSessionLocalNotice.showCompletion(this)
                result.success(null)
            }
            "showAutoEndNotice" -> {
                PumpSessionLocalNotice.showAutoEnd(
                    context = this,
                    title = call.argument<String>("title") ?: "",
                    body = call.argument<String>("body") ?: "",
                    path = call.argument<String>("path") ?: "/",
                    autoEndTeardown = call.argument<Boolean>("autoEndTeardown") ?: true
                )
                result.success(null)
            }
            "enqueuePendingNavigate" -> {
                val args = call.argumentsMap()
                PumpNavigationBridge.setPending(
                    args.stringValue("path"),
                    args.boolValue("autoEndTeardown"),
                    args.mapValue("notifyJson")?.toStringMap()
                )
                result.success(null)
            }
            "consumePendingNavigate" -> {
                result.success(PumpNavigationBridge.consumePending().toMap())
            }
            "restoreSnapshot" -> result.success(PumpSessionForegroundService.restoreSnapshot())
            else -> result.notImplemented()
        }
    }

    private fun handleLaunchNavigationIntent(intent: Intent?) {
        if (intent == null) return
        val path = intent.getStringExtra(EXTRA_NAV_PATH)
        val autoEndTeardown = intent.getBooleanExtra(EXTRA_AUTO_END_TEARDOWN, false)
        intent.removeExtra(EXTRA_NAV_PATH)
        intent.removeExtra(EXTRA_AUTO_END_TEARDOWN)
        if (!path.isNullOrBlank()) {
            val route = PumpNavigationBridge.PendingNavigate(path, autoEndTeardown)
            PumpNavigationBridge.setPending(
                route.path,
                route.autoEndTeardown,
                route.notifyJson
            )
            emitActiveRoute(route)
        }
    }

    private fun emitActiveRoute(route: PumpNavigationBridge.PendingNavigate) {
        if (!::pumpNotificationChannel.isInitialized) return
        pumpNotificationChannel.invokeMethod("activeRoute", route.toMap())
    }

    private fun requestBlePermissionsIfNeeded(result: MethodChannel.Result): Boolean {
        if (hasBlePermissions()) return false
        if (pendingBlePermissionResult != null) {
            result.error(
                "permission_request_in_progress",
                "Bluetooth permission request is already in progress",
                null
            )
            return true
        }
        pendingBlePermissionResult = result
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
        return true
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

    private fun requestNotificationPermissionIfNeeded(result: MethodChannel.Result): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return false
        if (hasNotificationPermission()) return false
        if (pendingNotificationPermissionResult != null) {
            result.error(
                "permission_request_in_progress",
                "Notification permission request is already in progress",
                null
            )
            return true
        }
        pendingNotificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_NOTIFICATION_PERMISSION
        )
        return true
    }

    private fun hasNotificationPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }

    private fun startVoicePcmPlayback(
        sampleRate: Int,
        requestedChannels: Int,
        result: MethodChannel.Result
    ) {
        val channels = if (requestedChannels == 2) 2 else 1
        val channelConfig = if (channels == 2) {
            AudioFormat.CHANNEL_OUT_STEREO
        } else {
            AudioFormat.CHANNEL_OUT_MONO
        }
        val minBuffer = AudioTrack.getMinBufferSize(
            sampleRate,
            channelConfig,
            AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuffer <= 0) {
            replyVoiceError(
                result,
                "voice_pcm_unavailable",
                "Unable to initialize PCM audio output"
            )
            return
        }
        stopVoicePcmPlayback()
        var track: AudioTrack? = null
        try {
            track = AudioTrack(
                AudioManager.STREAM_MUSIC,
                sampleRate,
                channelConfig,
                AudioFormat.ENCODING_PCM_16BIT,
                minBuffer.coerceAtLeast(sampleRate),
                AudioTrack.MODE_STREAM
            )
            if (track.state != AudioTrack.STATE_INITIALIZED) {
                track.release()
                replyVoiceError(
                    result,
                    "voice_pcm_unavailable",
                    "Unable to initialize PCM audio output"
                )
                return
            }
            track.play()
            voiceAudioTrackSampleRate = sampleRate
            voiceAudioTrackChannels = channels
            voiceAudioTrackWrittenFrames = 0L
            voiceAudioTrack = track
            replyVoiceSuccess(result)
        } catch (error: RuntimeException) {
            try {
                track?.release()
            } catch (_: RuntimeException) {
            }
            replyVoiceError(
                result,
                "voice_pcm_unavailable",
                error.message ?: "Unable to initialize PCM audio output"
            )
        }
    }

    private fun writeVoicePcmChunk(bytes: ByteArray, result: MethodChannel.Result) {
        val track = voiceAudioTrack
        if (track == null) {
            replyVoiceError(
                result,
                "voice_pcm_not_started",
                "PCM audio output is not started"
            )
            return
        }
        if (bytes.isNotEmpty()) {
            val writtenBytes = try {
                var offset = 0
                while (offset < bytes.size) {
                    val count = track.write(bytes, offset, bytes.size - offset)
                    if (count <= 0) {
                        throw IllegalStateException("Unable to write PCM audio output: $count")
                    }
                    offset += count
                }
                offset
            } catch (error: RuntimeException) {
                replyVoiceError(
                    result,
                    "voice_pcm_write_failed",
                    error.message ?: "Unable to write PCM audio output"
                )
                return
            }
            if (writtenBytes > 0) {
                voiceAudioTrackWrittenFrames +=
                    writtenBytes.toLong() / (2L * voiceAudioTrackChannels.coerceAtLeast(1))
            }
        }
        replyVoiceSuccess(result)
    }

    private fun finishVoicePcmPlayback(result: MethodChannel.Result) {
        val track = voiceAudioTrack
        if (track == null) {
            replyVoiceSuccess(result)
            return
        }
        val targetFrames = voiceAudioTrackWrittenFrames
        val sampleRate = voiceAudioTrackSampleRate.coerceAtLeast(1)
        val startedAtMs = SystemClock.uptimeMillis()
        val playedFrames = playbackHeadFrames(track)
        val remainingFrames = (voiceAudioTrackWrittenFrames - playedFrames).coerceAtLeast(0L)
        val expectedRemainingMs = (remainingFrames * 1000L) / sampleRate
        val maxDrainMs = (expectedRemainingMs + VOICE_PCM_FINISH_DRAIN_SLACK_MS)
            .coerceIn(VOICE_PCM_FINISH_MIN_DRAIN_MS, VOICE_PCM_FINISH_MAX_DRAIN_MS)
        fun completeFinish() {
            if (voiceAudioTrack === track) {
                stopVoicePcmPlayback()
            }
            replyVoiceSuccess(result)
        }

        fun pollPlaybackTail() {
            if (voiceAudioTrack !== track) {
                replyVoiceSuccess(result)
                return
            }
            val elapsedMs = SystemClock.uptimeMillis() - startedAtMs
            val playedNow = playbackHeadFrames(track)
            if (
                targetFrames <= 0L ||
                playedNow >= targetFrames ||
                elapsedMs >= maxDrainMs ||
                track.playState != AudioTrack.PLAYSTATE_PLAYING
            ) {
                completeFinish()
                return
            }
            voiceAudioHandler.postDelayed(::pollPlaybackTail, VOICE_PCM_FINISH_POLL_MS)
        }

        voiceAudioHandler.postDelayed(::pollPlaybackTail, VOICE_PCM_FINISH_POLL_MS)
    }

    private fun playbackHeadFrames(track: AudioTrack): Long {
        return track.playbackHeadPosition.toLong() and 0xffffffffL
    }

    private fun stopVoicePcmPlayback() {
        val track = voiceAudioTrack ?: return
        voiceAudioTrack = null
        voiceAudioTrackWrittenFrames = 0L
        try {
            track.stop()
        } catch (_: IllegalStateException) {
        }
        try {
            track.release()
        } catch (_: RuntimeException) {
        }
    }

    private fun replyVoiceSuccess(result: MethodChannel.Result) {
        voiceMainHandler.post {
            result.success(null)
        }
    }

    private fun replyVoiceError(
        result: MethodChannel.Result,
        code: String,
        message: String
    ) {
        voiceMainHandler.post {
            result.error(code, message, null)
        }
    }

    private fun MethodCall.argumentsMap(): Map<*, *> {
        return arguments as? Map<*, *> ?: emptyMap<String, Any?>()
    }

    private fun Map<*, *>.mapValue(key: String): Map<*, *>? {
        return this[key] as? Map<*, *>
    }

    private fun Map<*, *>.stringValue(key: String, fallback: String = ""): String {
        return this[key]?.toString()?.trim().takeUnless { it.isNullOrEmpty() } ?: fallback
    }

    private fun Map<*, *>.boolValue(key: String, fallback: Boolean = false): Boolean {
        return when (val value = this[key]) {
            is Boolean -> value
            is Number -> value.toInt() != 0
            is String -> value.equals("true", ignoreCase = true) || value == "1"
            else -> fallback
        }
    }

    private fun Map<*, *>.longValue(key: String, fallback: Long = 0L): Long {
        return when (val value = this[key]) {
            is Number -> value.toLong()
            is String -> value.toLongOrNull() ?: fallback
            else -> fallback
        }
    }

    private fun Map<*, *>.toStringMap(): Map<String, Any?> {
        return entries.associate { entry ->
            entry.key.toString() to entry.value
        }
    }

    companion object {
        private val CLIENT_CHARACTERISTIC_CONFIG =
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        private const val MMC_BLE_CHANNEL = "com.momcozymai.flutter/mmc_ble"
        private const val PUMP_NOTIFICATION_CHANNEL =
            "com.momcozymai.flutter/pump_session_notification"
        private const val PUMP_AGENT_UPLOAD_CHANNEL =
            "com.momcozymai.flutter/pump_agent_upload"
        private const val VOICE_PCM_PLAYER_CHANNEL =
            "com.momcozymai.flutter/voice_pcm_player"
        private const val VOICE_PCM_THREAD_NAME = "MomCozyVoicePcm"
        private const val VOICE_PCM_FINISH_POLL_MS = 40L
        private const val VOICE_PCM_FINISH_MIN_DRAIN_MS = 160L
        private const val VOICE_PCM_FINISH_DRAIN_SLACK_MS = 1200L
        private const val VOICE_PCM_FINISH_MAX_DRAIN_MS = 30000L
        private const val REQUEST_BLE_PERMISSIONS = 4101
        private const val REQUEST_NOTIFICATION_PERMISSION = 4102
        const val EXTRA_NAV_PATH = "momcozy.flutter.extra.NAV_PATH"
        const val EXTRA_AUTO_END_TEARDOWN = "momcozy.flutter.extra.AUTO_END_TEARDOWN"
    }
}
