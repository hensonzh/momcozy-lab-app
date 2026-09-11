package com.momcozymai.momcozy_flutter_app

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class NotificationPermissionPlugin(private val activity: Activity, messenger: BinaryMessenger) {
    private val preferences = activity.getSharedPreferences("momcozy_notification_permission", Context.MODE_PRIVATE)
    private var pending: MethodChannel.Result? = null
    private val channel = MethodChannel(messenger, "momcozy/notifications_permission")

    init {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = activity.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(NotificationChannel("service_updates", "Service updates", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Appointment and service notifications"
                setShowBadge(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
            })
        }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPermission" -> result.success(permission())
                "requestPermission" -> request(result)
                "openSettings" -> {
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                    } else {
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${activity.packageName}"))
                    }
                    activity.startActivity(intent)
                    result.success(null)
                }
                "clearNotifications" -> {
                    // Do not remove the independent pump foreground-service notification.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val manager = activity.getSystemService(NotificationManager::class.java)
                        manager.activeNotifications.filter {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) it.notification.channelId == "service_updates"
                            else it.tag?.matches(Regex("[0-9a-fA-F-]{36}")) == true
                        }.forEach { manager.cancel(it.tag, it.id) }
                    }
                    result.success(null)
                }
                // Android launcher badges follow active notifications. The App
                // renders the authoritative unread count independently.
                "setBadge" -> result.success(null)
                else -> result.notImplemented()
            }
        }
    }

    fun permission(): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            return if (preferences.getBoolean("requested", false) || activity.shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)) "denied" else "not_determined"
        }
        if (!NotificationManagerCompat.from(activity).areNotificationsEnabled()) return "denied"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            activity.getSystemService(NotificationManager::class.java).getNotificationChannel("service_updates")?.importance == NotificationManager.IMPORTANCE_NONE) return "denied"
        return "authorized"
    }

    fun notePermissionRequested() { preferences.edit().putBoolean("requested", true).apply() }

    private fun request(result: MethodChannel.Result) {
        if (permission() != "not_determined" || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(permission())
            return
        }
        if (pending != null) {
            result.error("permission_request_active", "A permission request is already active.", null)
            return
        }
        notePermissionRequested()
        pending = result
        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE)
    }

    fun handlePermissionResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_CODE) return false
        pending?.success(permission())
        pending = null
        return true
    }

    companion object { private const val REQUEST_CODE = 8873 }
}
