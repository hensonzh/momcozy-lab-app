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

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setConfig" -> {
                val args = call.argumentsMap()
                apiBaseUrl = args.stringValue("apiBaseUrl")
                bearerToken = args.stringValue("bearerToken")
                configuredUserId = args.stringValue("userId")
                result.success(null)
            }
            "sampleFromSnapshot" -> result.success(progressMap())
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
                applySide(call.argumentsMap().stringValue("side", "both")) { it.step = "stop" }
                result.success(null)
            }
            "markStepPause" -> {
                applySide(call.argumentsMap().stringValue("side", "both")) { it.step = "pause" }
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
        return when (call.method) {
            "uploadWorkstate" -> mapOf(
                "user_id" to userId,
                "device_left" to workstateSide(leftState, processL),
                "device_right" to workstateSide(rightState, processR)
            )
            "getProcessData" -> mapOf(
                "user_id" to userId,
                "device_left" to processDataSide(leftState),
                "device_right" to processDataSide(rightState)
            )
            "uploadProcess" -> mapOf(
                "user_id" to userId,
                "process_left" to processSide(processL),
                "process_right" to processSide(processR)
            )
            "uploadMilkRecord" -> {
                val endedAtMs = args.longValue("endedAtMs", System.currentTimeMillis())
                mapOf(
                    "user_id" to userId,
                    "pump_type" to 0,
                    "pump_source" to 0,
                    "pump_time" to pumpTime(endedAtMs),
                    "pump_milk_volum" to 0
                )
            }
            else -> emptyMap()
        }
    }

    private fun workstateSide(state: PumpAgentSideState, process: Int): Map<String, Any?> {
        return mapOf(
            "state" to 4,
            "process" to process,
            "timestamp" to isoNow(),
            "change_type" to state.source
        )
    }

    private fun processDataSide(state: PumpAgentSideState): Map<String, Any?> {
        return mapOf(
            "step" to state.step,
            "cap_data" to zeroFrame(),
            "time" to isoNow(),
            "milk_reel" to 0,
            "bandpower" to 0,
            "milk" to 0
        )
    }

    private fun processSide(process: Int): Map<String, Any?> {
        return mapOf(
            "time" to isoNow(),
            "process" to process,
            "cap_data" to 0,
            "milk_reel" to 0,
            "bandpower" to 0,
            "milk" to 0
        )
    }

    private fun applyProcessDataResponse(response: Map<String, Any?>) {
        processL = response.intValue("process_l", processL)
        processR = response.intValue("process_r", processR)
        processAll = response.intValue("process_all", processAll)
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

    private fun Map<*, *>.stringValue(key: String, fallback: String = ""): String {
        return this[key]?.toString()?.trim().takeUnless { it.isNullOrEmpty() } ?: fallback
    }

    private fun Map<*, *>.longValue(key: String, fallback: Long): Long {
        return when (val value = this[key]) {
            is Number -> value.toLong()
            is String -> value.toLongOrNull() ?: fallback
            else -> fallback
        }
    }

    private fun Map<String, Any?>.intValue(key: String, fallback: Int): Int {
        return numberToInt(this[key], fallback)
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
        var source: String = "device"
    ) {
        fun reset() {
            step = "stop"
            source = "device"
        }
    }

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
