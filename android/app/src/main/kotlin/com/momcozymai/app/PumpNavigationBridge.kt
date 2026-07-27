package com.momcozymai.app

internal object PumpNavigationBridge {
    private var pendingPath: String = ""
    private var pendingAutoEndTeardown: Boolean = false
    private var pendingNotifyJson: Map<String, Any?>? = null

    data class PendingNavigate(
        val path: String,
        val autoEndTeardown: Boolean = false,
        val notifyJson: Map<String, Any?>? = null
    ) {
        fun toMap(): Map<String, Any?> {
            return mapOf(
                "path" to path,
                "autoEndTeardown" to autoEndTeardown,
                "notifyJson" to notifyJson
            )
        }
    }

    @Synchronized
    fun setPending(
        path: String,
        autoEndTeardown: Boolean = false,
        notifyJson: Map<String, Any?>? = null
    ) {
        if (path.isBlank()) return
        pendingPath = path
        pendingAutoEndTeardown = autoEndTeardown
        pendingNotifyJson = notifyJson
    }

    @Synchronized
    fun consumePending(): PendingNavigate {
        val next = PendingNavigate(
            path = pendingPath,
            autoEndTeardown = pendingAutoEndTeardown,
            notifyJson = pendingNotifyJson
        )
        pendingPath = ""
        pendingAutoEndTeardown = false
        pendingNotifyJson = null
        return next
    }
}
