package com.momcozymai.momcozy_flutter_app

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
    private var configuredUserId = ""
    private var processL = 0
    private var processR = 0
    private var processAll = 0
    private var elapsedSeconds = 0
    private var deviceSnapshot: Map<*, *> = emptyMap<String, Any?>()

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setConfig" -> {
                val args = call.argumentsMap()
                apiBaseUrl = args.stringValue("apiBaseUrl")
                bearerToken = args.stringValue("bearerToken")
                configuredUserId = args.stringValue("userId")
                result.success(null)
            }
            "updateDeviceSnapshot" -> {
                deviceSnapshot = call.argumentsMap().mapValue("snapshot") ?: emptyMap<String, Any?>()
                sampleCurrentSnapshot()
                result.success(null)
            }
            "sampleFromSnapshot" -> {
                sampleCurrentSnapshot()
                result.success(progressMap())
            }
            "resetProgress" -> {
                processL = 0
                processR = 0
                processAll = 0
                elapsedSeconds = 0
                leftState.reset()
                rightState.reset()
                synchronized(uploadKeyLock) {
                    completedUploadKeys.clear()
                    pendingUploadKeys.clear()
                }
                result.success(progressMap())
            }
            "markStepStop" -> {
                applySide(call.argumentsMap().stringValue("side", "both")) {
                    it.step = "stop"
                    it.stopMarked = true
                }
                result.success(null)
            }
            "markStepPause" -> {
                applySide(call.argumentsMap().stringValue("side", "both")) {
                    it.step = "pause"
                    it.pauseMarked = true
                }
                result.success(null)
            }
            "setOperationSource" -> {
                val args = call.argumentsMap()
                val source = args.stringValue("source", "device")
                applySide(args.stringValue("side", "both")) { it.source = source }
                result.success(null)
            }
            "uploadWorkstate",
            "getProcessData",
            "uploadProcess",
            "uploadMilkRecord" -> upload(call, result)
            else -> result.notImplemented()
        }
    }

    private fun upload(call: MethodCall, result: MethodChannel.Result) {
        val body = buildBody(call)
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
                    if (call.method == "getProcessData") applyProcessDataResponse(response)
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
        val base = apiBaseUrl.trim().trimEnd('/')
        if (base.isEmpty()) {
            return mapOf("error" to 0, "skipped" to true, "reason" to "missing_api_base_url")
        }

        val conn = URL(base + path).openConnection() as HttpURLConnection
        try {
            conn.requestMethod = "POST"
            conn.connectTimeout = HTTP_TIMEOUT_MS
            conn.readTimeout = HTTP_TIMEOUT_MS
            conn.setRequestProperty("Accept", "application/json")
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            if (bearerToken.trim().isNotEmpty()) {
                conn.setRequestProperty("Authorization", "Bearer ${bearerToken.trim()}")
            }
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
        val args = call.argumentsMap()
        val userId = args.stringValue("userId", configuredUserId)
        if (call.method == "getProcessData") sampleCurrentSnapshot()
        val left = snapshotDevice("L")
        val right = snapshotDevice("R")
        return when (call.method) {
            "uploadWorkstate" -> mapOf(
                "user_id" to userId,
                "device_left" to workstateSide(left, leftState, processL),
                "device_right" to workstateSide(right, rightState, processR)
            )
            "getProcessData" -> mapOf(
                "user_id" to userId,
                "device_left" to processDataSide(left, leftState),
                "device_right" to processDataSide(right, rightState)
            )
            "uploadProcess" -> mapOf(
                "user_id" to userId,
                "process_left" to processSide(left, leftState, processL),
                "process_right" to processSide(right, rightState, processR)
            )
            "uploadMilkRecord" -> {
                val endedAtMs = args.longValue("endedAtMs", System.currentTimeMillis())
                mapOf(
                    "user_id" to userId,
                    "pump_type" to 0,
                    "pump_source" to 0,
                    "pump_time" to pumpTime(endedAtMs),
                    "pump_milk_volum" to roundedOneDecimal(displayedMilk(left) + displayedMilk(right))
                )
            }
            else -> emptyMap()
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
            "uploadWorkstate" -> "/v1/pump/workstate"
            "getProcessData" -> "/v1/pump/process/data"
            "uploadProcess" -> "/v1/pump/process"
            "uploadMilkRecord" -> "/v1/pump-milk/upload"
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
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        return formatter.format(Date())
    }

    private fun pumpTime(endedAtMs: Long): String {
        return SimpleDateFormat("HH:mm", Locale.US).format(Date(endedAtMs))
    }

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
    }
}
