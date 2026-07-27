package com.momcozymai.app

import android.app.Activity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStream
import java.io.InputStreamReader
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

internal class PumpAgentUploadChannelHandler(
    private val activity: Activity,
    private val channel: MethodChannel
) {
    private val uploadKeyLock = Any()
    private val completedUploadKeys = mutableSetOf<String>()
    private val pendingUploadKeys = mutableSetOf<String>()
    private val leftState = PumpAgentSideState()
    private val rightState = PumpAgentSideState()

    private var apiBaseUrl = ""
    private var bearerToken = ""
    private var processL = 0
    private var processR = 0
    private var processAll = 0
    private var elapsedSeconds = 0
    private var deviceSnapshot: Map<*, *> = emptyMap<String, Any?>()
    private var workstateSignature = ""
    private var lastProcessUploadAt = 0L

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setConfig" -> {
                val args = call.argumentsMap()
                apiBaseUrl = args.stringValue("apiBaseUrl")
                bearerToken = args.stringValue("bearerToken")
                result.success(null)
            }
            "updateDeviceSnapshot" -> {
                synchronized(this) {
                    deviceSnapshot = call.argumentsMap().mapValue("snapshot") ?: emptyMap<String, Any?>()
                    sampleCurrentSnapshot()
                }
                result.success(null)
            }
            "sampleFromSnapshot" -> {
                val progress = synchronized(this) {
                    sampleCurrentSnapshot()
                    progressMap()
                }
                result.success(progress)
            }
            "resetProgress" -> {
                synchronized(this) {
                    processL = 0
                    processR = 0
                    processAll = 0
                    elapsedSeconds = 0
                    workstateSignature = ""
                    lastProcessUploadAt = 0L
                    leftState.reset()
                    rightState.reset()
                }
                synchronized(uploadKeyLock) {
                    completedUploadKeys.clear()
                    pendingUploadKeys.clear()
                }
                result.success(synchronized(this) { progressMap() })
            }
            "markStepStop" -> {
                synchronized(this) {
                    applySide(call.argumentsMap().stringValue("side", "both")) {
                        it.step = "stop"
                        it.stopMarked = true
                    }
                }
                result.success(null)
            }
            "markStepPause" -> {
                synchronized(this) {
                    applySide(call.argumentsMap().stringValue("side", "both")) {
                        it.step = "pause"
                        it.pauseMarked = true
                    }
                }
                result.success(null)
            }
            "setOperationSource" -> {
                val args = call.argumentsMap()
                val source = args.stringValue("source", "device")
                synchronized(this) {
                    applySide(args.stringValue("side", "both")) { it.source = source }
                }
                result.success(null)
            }
            "uploadWorkstate",
            "getProcessData",
            "uploadProcess",
            "uploadMilkRecord" -> upload(call, result)
            else -> result.notImplemented()
        }
    }

    fun sampleFromSnapshotForRunner(nextElapsedSeconds: Int): Map<String, Int> {
        val progress = synchronized(this) {
            elapsedSeconds = nextElapsedSeconds.coerceAtLeast(0)
            sampleCurrentSnapshot()
            progressMap()
        }
        emitProcessProgress(progress)
        return progress
    }

    fun runBackgroundNetworkTick(nowMs: Long = System.currentTimeMillis()): Map<String, Int> {
        nextWorkstateUpload()?.let { upload ->
            val response = postJson(upload.path, upload.body)
            if (response.isSuccessfulUploadResponse()) {
                synchronized(this) {
                    workstateSignature = upload.signature
                }
            }
        }
        nextProcessDataUpload()?.let { upload ->
            val response = postJson(upload.path, upload.body)
            val progress = synchronized(this) {
                applyProcessDataResponse(response)
                progressMap()
            }
            emitProcessProgress(progress)
        }
        nextProcessUpload(nowMs)?.let { upload ->
            val response = postJson(upload.path, upload.body)
            emitProcessReply(response)
        }
        return synchronized(this) { progressMap() }
    }

    private fun upload(call: MethodCall, result: MethodChannel.Result) {
        val body = synchronized(this) { buildBody(call) }
        val path = pathForMethod(call.method)
        val dedupeProtected = call.method != "getProcessData"
        val uploadKey = "${call.method}:${body.dedupeKey()}"

        if (dedupeProtected) {
            val deduped = synchronized(uploadKeyLock) {
                if (completedUploadKeys.contains(uploadKey) || pendingUploadKeys.contains(uploadKey)) {
                    true
                } else {
                    pendingUploadKeys.add(uploadKey)
                    false
                }
            }
            if (deduped) {
                result.success(
                    uploadResult(
                        body,
                        mapOf("error" to 0, "skipped" to true, "reason" to "deduped"),
                        deduped = true
                    )
                )
                return
            }
        }

        Thread(
            {
                try {
                    val response = postJson(path, body)
                    if (call.method == "getProcessData") {
                        synchronized(this) {
                            applyProcessDataResponse(response)
                        }
                    }
                    if (dedupeProtected && response.isSuccessfulUploadResponse()) {
                        synchronized(uploadKeyLock) {
                            completedUploadKeys.add(uploadKey)
                        }
                    }
                    activity.runOnUiThread {
                        result.success(uploadResult(body, response, deduped = false))
                    }
                } catch (error: Exception) {
                    val message = safeFailureMessage(error)
                    val failure = failureMap(call.method, path, error)
                    activity.runOnUiThread {
                        channel.invokeMethod("uploadFailure", failure)
                        result.success(
                            uploadResult(
                                body,
                                mapOf(
                                    "error" to -1,
                                    "message" to message
                                ),
                                deduped = false
                            )
                        )
                    }
                } finally {
                    if (dedupeProtected) {
                        synchronized(uploadKeyLock) {
                            pendingUploadKeys.remove(uploadKey)
                        }
                    }
                }
            },
            "PumpAgentUpload"
        ).start()
    }

    private fun postJson(path: String, body: Map<String, Any?>): Map<String, Any?> {
        if (path.isBlank()) {
            return mapOf("error" to 0, "skipped" to true, "reason" to "local_progress_projection")
        }
        val base = apiBaseUrl.trim().trimEnd('/')
        if (base.isEmpty()) {
            return mapOf("error" to 0, "skipped" to true, "reason" to "missing_api_base_url")
        }
        val token = bearerToken.trim()
        if (token.isEmpty()) {
            return mapOf("error" to 0, "skipped" to true, "reason" to "missing_bearer_token")
        }

        val conn = URL(base + path).openConnection() as HttpURLConnection
        try {
            conn.requestMethod = "POST"
            conn.connectTimeout = HTTP_TIMEOUT_MS
            conn.readTimeout = HTTP_TIMEOUT_MS
            conn.setRequestProperty("Accept", "application/json")
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            conn.setRequestProperty("Authorization", "Bearer $token")
            conn.setRequestProperty("Idempotency-Key", uploadIdempotencyKey(path, body))
            conn.doOutput = true
            val payload = JSONObject(body.toJsonMap()).toString().toByteArray(StandardCharsets.UTF_8)
            conn.outputStream.use { output: OutputStream -> output.write(payload) }

            val code = conn.responseCode
            val raw = readAll(if (code >= 400) conn.errorStream else conn.inputStream)
            if (code >= 400) throw PumpAgentUploadHttpException(code)
            if (raw.isBlank()) return mapOf("error" to 0)

            val root = JSONObject(raw)
            if (root.has("status") && root.has("data")) {
                val status = root.optInt("status", 0)
                if (status != 200) {
                    throw PumpAgentUploadHttpException(status)
                }
                return root.optJSONObject("data")?.toPlainMap() ?: emptyMap()
            }
            return root.toPlainMap()
        } finally {
            conn.disconnect()
        }
    }

    private fun buildBody(call: MethodCall): Map<String, Any?> {
        return buildBody(call.method, call.argumentsMap())
    }

    private fun buildBody(method: String, args: Map<*, *> = emptyMap<String, Any?>()): Map<String, Any?> {
        if (method == "getProcessData") sampleCurrentSnapshot()
        val left = snapshotDevice("L")
        val right = snapshotDevice("R")
        return when (method) {
            "uploadWorkstate" -> mapOf(
                "device_id" to telemetryDeviceId(left, right),
                "event_type" to "workstate",
                "occurred_at" to isoNow(),
                "payload" to mapOf(
                    "left" to workstateSide(left, leftState, processL),
                    "right" to workstateSide(right, rightState, processR)
                )
            )
            "getProcessData" -> mapOf(
                "device_left" to processDataSide(left, leftState),
                "device_right" to processDataSide(right, rightState)
            )
            "uploadProcess" -> mapOf(
                "device_id" to telemetryDeviceId(left, right),
                "event_type" to "process",
                "occurred_at" to isoNow(),
                "payload" to mapOf(
                    "left" to processSide(left, leftState, processL),
                    "right" to processSide(right, rightState, processR),
                    "progress" to progressMap()
                )
            )
            "uploadMilkRecord" -> {
                val endedAtMs = args.longValue("endedAtMs", System.currentTimeMillis())
                val durationSeconds = Math.max(0, elapsedSeconds)
                val startedAtMs = endedAtMs - durationSeconds * 1000L
                mapOf(
                    "pump_start_time" to isoAt(startedAtMs),
                    "pump_end_time" to isoAt(endedAtMs),
                    "milk_volume_ml" to roundedOneDecimal(displayedMilk(left) + displayedMilk(right)),
                    "pump_type" to "wearable",
                    "duration_seconds" to durationSeconds,
                    "source" to "device",
                    "title" to "Pump session"
                )
            }
            else -> emptyMap()
        }
    }

    private fun nextWorkstateUpload(): BackgroundUpload? {
        return synchronized(this) {
            if (!hasAnyDeviceConnected()) return@synchronized null
            val signature = workstateSignature()
            if (signature == workstateSignature) return@synchronized null
            BackgroundUpload(
                path = pathForMethod("uploadWorkstate"),
                body = buildBody("uploadWorkstate"),
                signature = signature
            )
        }
    }

    private fun nextProcessDataUpload(): BackgroundUpload? {
        return synchronized(this) {
            if (!shouldFetchProcessData()) return@synchronized null
            BackgroundUpload(
                path = pathForMethod("getProcessData"),
                body = buildBody("getProcessData")
            )
        }
    }

    private fun nextProcessUpload(nowMs: Long): BackgroundUpload? {
        return synchronized(this) {
            if (!hasAnyDeviceConnected()) return@synchronized null
            if (nowMs - lastProcessUploadAt < PROCESS_UPLOAD_INTERVAL_MS) {
                return@synchronized null
            }
            lastProcessUploadAt = nowMs
            BackgroundUpload(
                path = pathForMethod("uploadProcess"),
                body = buildBody("uploadProcess")
            )
        }
    }

    private fun workstateSide(
        device: Map<*, *>?,
        state: PumpAgentSideState,
        process: Int
    ): Map<String, Any?> {
        val now = isoNow()
        if (device == null) {
            return mapOf(
                "state" to 4,
                "process" to process,
                "timestamp" to now,
                "change_type" to state.source
            )
        }
        val timestamp = if (state.source == "device") {
            device.stringValue("lastDeviceWorkstateTs", now)
        } else {
            now
        }
        if (!device.boolValue("connected")) {
            return mapOf(
                "state" to 3,
                "process" to process,
                "timestamp" to timestamp,
                "change_type" to state.source
            )
        }
        val out = mutableMapOf<String, Any?>(
            "state" to if (device.intValue("pumpWorkState", 0) == 1) 1 else 0,
            "scene" to if (device.intValue("pumpScene", 0) == 1) "auto" else "manual",
            "process" to process,
            "timestamp" to timestamp,
            "change_type" to state.source
        )
        modeLabel(device.intValue("pumpMode", -1))?.let { out["mode"] = it }
        if (device.containsKey("gear")) out["level"] = device.intValue("gear", 0)
        return out
    }

    private fun processDataSide(device: Map<*, *>?, state: PumpAgentSideState): Map<String, Any?> {
        val now = isoNow()
        val connected = device?.boolValue("connected") ?: false
        if (!connected) {
            resolveStep(state, connected = false, running = false)
            return emptyProcessDataSide("offline", now)
        }
        val running = device?.intValue("pumpWorkState", 0) == 1
        if (!running) {
            return emptyProcessDataSide(
                resolveStep(state, connected = true, running = false),
                device?.stringValue("lastDeviceProcessTs", now) ?: now
            )
        }
        val lastFrame = state.frames.lastOrNull()
        return mapOf(
            "step" to resolveStep(state, connected = true, running = true),
            "cap_data" to capDataFrame(state),
            "time" to (lastFrame?.time ?: device?.stringValue("lastDeviceProcessTs", now)),
            "milk_reel" to (lastFrame?.milkReel ?: 0),
            "bandpower" to (lastFrame?.bandpower ?: 0),
            "milk" to (lastFrame?.milk ?: 0)
        )
    }

    private fun processSide(
        device: Map<*, *>?,
        state: PumpAgentSideState,
        process: Int
    ): Map<String, Any?> {
        if (device == null || !device.boolValue("connected")) {
            return zeroProcessSide(process, state)
        }
        syncProcessFields(state, device)
        return mapOf(
            "time" to state.time,
            "process" to process,
            "cap_data" to state.capData,
            "milk_reel" to state.milkReel,
            "bandpower" to state.bandpower,
            "milk" to state.milk
        )
    }

    private fun zeroProcessSide(process: Int, state: PumpAgentSideState): Map<String, Any?> {
        return mapOf(
            "time" to state.time.ifEmpty { isoNow() },
            "process" to process,
            "cap_data" to 0,
            "milk_reel" to 0,
            "bandpower" to 0,
            "milk" to 0
        )
    }

    private fun emptyProcessDataSide(step: String, time: String): Map<String, Any?> {
        return mapOf(
            "step" to step,
            "cap_data" to zeroFrame(),
            "time" to time,
            "milk_reel" to 0,
            "bandpower" to 0,
            "milk" to 0
        )
    }

    private fun applyProcessDataResponse(response: Map<String, Any?>) {
        if (response.intValue("error", 0) != 0) return
        processL = response.intValue("process_l", processL)
        processR = response.intValue("process_r", processR)
        processAll = response.intValue("process_all", processAll)
        leftState.frames.clear()
        rightState.frames.clear()
    }

    private fun uploadResult(
        body: Map<String, Any?>,
        response: Map<String, Any?>,
        deduped: Boolean
    ): Map<String, Any?> {
        return mapOf(
            "body" to body,
            "response" to response,
            "deduped" to deduped
        ) + progressMap()
    }

    private fun progressMap(): Map<String, Int> {
        return mapOf(
            "processL" to processL,
            "processR" to processR,
            "processAll" to processAll,
            "elapsedSeconds" to elapsedSeconds
        )
    }

    private fun failureMap(method: String, path: String, error: Exception): Map<String, Any?> {
        val httpError = error as? PumpAgentUploadHttpException
        return mapOf(
            "method" to method,
            "code" to if (httpError != null) "http_error" else "network_error",
            "message" to safeFailureMessage(error),
            "retryable" to (httpError?.retryable ?: true),
            "payload" to mapOf(
                "method" to method,
                "path" to path,
                "statusCode" to httpError?.statusCode
            )
        )
    }

    private fun safeFailureMessage(error: Exception): String {
        val httpError = error as? PumpAgentUploadHttpException
        return if (httpError != null) "HTTP ${httpError.statusCode}" else "native pump upload failed"
    }

    private fun emitProcessProgress(progress: Map<String, Int>) {
        activity.runOnUiThread {
            channel.invokeMethod("processProgress", progress)
        }
    }

    private fun emitProcessReply(response: Map<String, Any?>) {
        activity.runOnUiThread {
            channel.invokeMethod("processReply", response)
        }
    }

    private fun applySide(side: String, update: (PumpAgentSideState) -> Unit) {
        when (side) {
            "L" -> update(leftState)
            "R" -> update(rightState)
            else -> {
                update(leftState)
                update(rightState)
            }
        }
    }

    private fun snapshotDevice(side: String): Map<*, *>? {
        return deviceSnapshot[side] as? Map<*, *>
    }

    private fun hasAnyDeviceConnected(): Boolean {
        return isConnected(snapshotDevice("L")) || isConnected(snapshotDevice("R"))
    }

    private fun shouldFetchProcessData(): Boolean {
        return isRunning(snapshotDevice("L")) ||
            isRunning(snapshotDevice("R")) ||
            leftState.stopMarked ||
            rightState.stopMarked ||
            leftState.pauseMarked ||
            rightState.pauseMarked
    }

    private fun workstateSignature(): String {
        return mapOf(
            "L" to workstateSignatureSide(snapshotDevice("L")),
            "R" to workstateSignatureSide(snapshotDevice("R"))
        ).stableString()
    }

    private fun workstateSignatureSide(device: Map<*, *>?): Map<String, Any?> {
        return mapOf(
            "connected" to isConnected(device),
            "pumpWorkState" to (device?.intValue("pumpWorkState", -1) ?: -1),
            "pumpScene" to (device?.intValue("pumpScene", -1) ?: -1),
            "pumpMode" to (device?.intValue("pumpMode", -1) ?: -1),
            "gear" to (device?.intValue("gear", -1) ?: -1)
        )
    }

    private fun isConnected(device: Map<*, *>?): Boolean {
        return device?.boolValue("connected") ?: false
    }

    private fun isRunning(device: Map<*, *>?): Boolean {
        return isConnected(device) && device?.intValue("pumpWorkState", 0) == 1
    }

    private fun sampleCurrentSnapshot() {
        sampleSide(leftState, snapshotDevice("L"))
        sampleSide(rightState, snapshotDevice("R"))
    }

    private fun sampleSide(state: PumpAgentSideState, device: Map<*, *>?) {
        val connected = device?.boolValue("connected") ?: false
        if (connected && !state.prevConnected) {
            state.step = "stop"
            state.stopMarked = false
            state.pauseMarked = false
            state.frames.clear()
        }
        if (!connected && state.prevConnected) {
            state.step = "stop"
            state.pauseMarked = false
            state.frames.clear()
        }
        state.prevConnected = connected
        if (!connected || device == null) return

        syncProcessFields(state, device)
        state.frames.add(
            PumpProcessFrame(
                time = state.time,
                capData = state.capData,
                milkReel = state.milkReel,
                bandpower = state.bandpower,
                milk = state.milk
            )
        )
        while (state.frames.size > FRAME_SIZE) {
            state.frames.removeAt(0)
        }
    }

    private fun syncProcessFields(state: PumpAgentSideState, device: Map<*, *>) {
        state.time = if (state.source == "device") {
            device.stringValue("lastDeviceProcessTs", isoNow())
        } else {
            isoNow()
        }
        state.capData = Math.max(0.0, roundedTwoDecimals(device.doubleValue("flowFloat", state.capData)))
        state.milkReel = milkReel(device)
        state.bandpower = bandpower(device)
        state.milk = milk(device)
    }

    private fun resolveStep(
        state: PumpAgentSideState,
        connected: Boolean,
        running: Boolean
    ): String {
        if (state.stopMarked) {
            state.stopMarked = false
            state.step = "stop"
            return "stop"
        }
        if (state.pauseMarked) {
            state.pauseMarked = false
            state.step = "pause"
            return "pause"
        }
        if (!connected) {
            state.step = "stop"
            return "stop"
        }
        if (!running) {
            state.step = if (
                state.step == "running" ||
                state.step == "start" ||
                state.step == "pause"
            ) {
                "pause"
            } else {
                "stop"
            }
            return state.step
        }
        state.step = if (state.step == "stop") "start" else "running"
        return state.step
    }

    private fun modeLabel(mode: Int): String? {
        return when (mode) {
            0 -> "stimulate"
            1 -> "deep"
            2 -> "mix"
            else -> null
        }
    }

    private fun capDataFrame(state: PumpAgentSideState): List<Any> {
        val frames = state.frames.takeLast(FRAME_SIZE)
        val values = MutableList<Any>(Math.max(0, FRAME_SIZE - frames.size)) { 0 }
        values.addAll(frames.map { it.capData })
        return values
    }

    private fun milkReel(device: Map<*, *>?): Int {
        val milk = (device?.intValue("milkFlag", 0) ?: 0) and 0x01
        val mo = (device?.intValue("moFlag", 0) ?: 0) and 0x01
        return (mo shl 1) or milk
    }

    private fun bandpower(device: Map<*, *>?): Int {
        return Math.max(0, Math.round((device?.doubleValue("bandpower", 0.0) ?: 0.0).toFloat()))
    }

    private fun milk(device: Map<*, *>?): Int {
        return Math.max(0, Math.round((device?.doubleValue("milkMl", 0.0) ?: 0.0).toFloat()))
    }

    private fun displayedMilk(device: Map<*, *>?): Double {
        if (device == null || !device.boolValue("connected")) return 0.0
        return Math.max(0.0, device.doubleValue("milkMl", 0.0))
    }

    private fun roundedOneDecimal(value: Double): Double {
        return Math.round(value * 10.0) / 10.0
    }

    private fun roundedTwoDecimals(value: Double): Double {
        return Math.round(value * 100.0) / 100.0
    }

    private fun pathForMethod(method: String): String {
        return when (method) {
            "uploadWorkstate" -> "/v1/devices/pump-telemetry"
            "getProcessData" -> ""
            "uploadProcess" -> "/v1/devices/pump-telemetry"
            "uploadMilkRecord" -> "/v1/records/pumping"
            else -> "/"
        }
    }

    private fun Map<String, Any?>.isSuccessfulUploadResponse(): Boolean {
        if (this["skipped"] == true) return false
        val error = this["error"] ?: return true
        return numberToInt(error, 0) == 0
    }

    private fun Map<String, Any?>.dedupeKey(): String {
        return normalizedDedupeValue(this).stableString()
    }

    private fun normalizedDedupeValue(value: Any?): Any? {
        return when (value) {
            is Map<*, *> -> value.entries
                .filter { entry ->
                    val key = entry.key?.toString()
                    key != "timestamp" && key != "time"
                }
                .associate { entry -> entry.key.toString() to normalizedDedupeValue(entry.value) }
            is Iterable<*> -> value.map(::normalizedDedupeValue)
            else -> value
        }
    }

    private fun Any?.stableString(): String {
        return when (this) {
            is Map<*, *> -> entries
                .sortedBy { it.key.toString() }
                .joinToString("&") { entry -> "${entry.key}=${entry.value.stableString()}" }
            is Iterable<*> -> joinToString(",", prefix = "[", postfix = "]") { it.stableString() }
            else -> toString()
        }
    }

    private fun Map<*, *>.toJsonMap(): Map<String, Any?> {
        return entries.associate { entry ->
            entry.key.toString() to when (val value = entry.value) {
                is Map<*, *> -> value.toJsonMap()
                is Iterable<*> -> value.map { item ->
                    when (item) {
                        is Map<*, *> -> item.toJsonMap()
                        is Iterable<*> -> item.toList()
                        else -> item
                    }
                }
                else -> value
            }
        }
    }

    private fun JSONObject.toPlainMap(): Map<String, Any?> {
        val out = mutableMapOf<String, Any?>()
        val keys = keys()
        while (keys.hasNext()) {
            val key = keys.next()
            out[key] = when (val value = get(key)) {
                is JSONObject -> value.toPlainMap()
                is JSONArray -> value.toPlainList()
                JSONObject.NULL -> null
                else -> value
            }
        }
        return out
    }

    private fun JSONArray.toPlainList(): List<Any?> {
        return (0 until length()).map { index ->
            when (val value = get(index)) {
                is JSONObject -> value.toPlainMap()
                is JSONArray -> value.toPlainList()
                JSONObject.NULL -> null
                else -> value
            }
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

    private fun Map<*, *>.longValue(key: String, fallback: Long): Long {
        return when (val value = this[key]) {
            is Number -> value.toLong()
            is String -> value.toLongOrNull() ?: fallback
            else -> fallback
        }
    }

    private fun Map<*, *>.intValue(key: String, fallback: Int = 0): Int {
        return numberToInt(this[key], fallback)
    }

    private fun Map<*, *>.doubleValue(key: String, fallback: Double = 0.0): Double {
        return when (val value = this[key]) {
            is Number -> value.toDouble()
            is String -> value.toDoubleOrNull() ?: fallback
            else -> fallback
        }
    }

    private fun numberToInt(value: Any?, fallback: Int): Int {
        return when (value) {
            is Number -> value.toInt()
            is String -> value.toDoubleOrNull()?.toInt() ?: fallback
            else -> fallback
        }
    }

    private fun readAll(input: InputStream?): String {
        if (input == null) return ""
        return BufferedReader(InputStreamReader(input, StandardCharsets.UTF_8)).use { reader ->
            buildString {
                var line = reader.readLine()
                while (line != null) {
                    append(line)
                    line = reader.readLine()
                }
            }
        }
    }

    private fun zeroFrame(): List<Int> {
        return List(FRAME_SIZE) { 0 }
    }

    private fun isoNow(): String {
        return isoAt(System.currentTimeMillis())
    }

    private fun isoAt(epochMs: Long): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        return formatter.format(Date(epochMs))
    }

    private fun telemetryDeviceId(left: Map<*, *>?, right: Map<*, *>?): String {
        val leftId = left?.stringValue("deviceId")
        val rightId = right?.stringValue("deviceId")
        return when {
            !leftId.isNullOrBlank() && !rightId.isNullOrBlank() && leftId != rightId -> "$leftId+$rightId"
            !leftId.isNullOrBlank() -> leftId
            !rightId.isNullOrBlank() -> rightId
            else -> "native-pump-session"
        }.take(120)
    }

    private fun uploadIdempotencyKey(path: String, body: Map<String, Any?>): String {
        val raw = "$path:${body.dedupeKey()}"
        return "native-pump-${Math.abs(raw.hashCode())}"
    }

    private data class BackgroundUpload(
        val path: String,
        val body: Map<String, Any?>,
        val signature: String = ""
    )

    private data class PumpAgentSideState(
        var step: String = "stop",
        var source: String = "device",
        var stopMarked: Boolean = false,
        var pauseMarked: Boolean = false,
        var prevConnected: Boolean = false,
        var time: String = "",
        var capData: Double = 0.0,
        var milkReel: Int = 0,
        var bandpower: Int = 0,
        var milk: Int = 0,
        val frames: MutableList<PumpProcessFrame> = mutableListOf()
    ) {
        fun reset() {
            step = "stop"
            source = "device"
            stopMarked = false
            pauseMarked = false
            prevConnected = false
            time = ""
            capData = 0.0
            milkReel = 0
            bandpower = 0
            milk = 0
            frames.clear()
        }
    }

    private data class PumpProcessFrame(
        val time: String,
        val capData: Double,
        val milkReel: Int,
        val bandpower: Int,
        val milk: Int
    )

    private class PumpAgentUploadHttpException(
        val statusCode: Int
    ) : Exception("HTTP $statusCode") {
        val retryable: Boolean = statusCode == 408 || statusCode == 429 || statusCode >= 500
    }

    private companion object {
        private const val FRAME_SIZE = 20
        private const val HTTP_TIMEOUT_MS = 25_000
        private const val PROCESS_UPLOAD_INTERVAL_MS = 10_000L
    }
}
