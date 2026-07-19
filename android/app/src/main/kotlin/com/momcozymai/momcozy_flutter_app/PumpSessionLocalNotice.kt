package com.momcozymai.momcozy_flutter_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

internal object PumpSessionLocalNotice {
    private const val COMPLETION_CHANNEL_ID = "momcozy_flutter_pump_completion"
    private const val AUTO_END_CHANNEL_ID = "momcozy_flutter_pump_auto_end"
    private const val COMPLETION_NOTIFICATION_ID = 21003
    private const val AUTO_END_NOTIFICATION_ID = 21004

    fun showCompletion(context: Context) {
        ensureChannel(
            context,
            COMPLETION_CHANNEL_ID,
            "Pump completion",
            "Pump session completion reminders"
        )
        show(
            context = context,
            channelId = COMPLETION_CHANNEL_ID,
            notificationId = COMPLETION_NOTIFICATION_ID,
            requestCode = 10021,
            title = "Pump session complete",
            body = "You can return to the pump session to review or finish.",
            path = "/pump",
            autoEndTeardown = false
        )
    }

    fun showAutoEnd(
        context: Context,
        title: String,
        body: String,
        path: String,
        autoEndTeardown: Boolean
    ) {
        ensureChannel(
            context,
            AUTO_END_CHANNEL_ID,
            "Pump auto end",
            "Pump session auto-end reminders"
        )
        show(
            context = context,
            channelId = AUTO_END_CHANNEL_ID,
            notificationId = AUTO_END_NOTIFICATION_ID,
            requestCode = 10022,
            title = title.ifBlank { "Pump session ended" },
            body = body.ifBlank { "Open Momcozy to complete the session." },
            path = path.ifBlank { "/" },
            autoEndTeardown = autoEndTeardown
        )
    }

    fun cancelAll(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(COMPLETION_NOTIFICATION_ID)
        manager.cancel(AUTO_END_NOTIFICATION_ID)
    }

    private fun show(
        context: Context,
        channelId: String,
        notificationId: Int,
        requestCode: Int,
        title: String,
        body: String,
        path: String,
        autoEndTeardown: Boolean
    ) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(
            notificationId,
            buildNotification(
                context,
                channelId,
                requestCode,
                title,
                body,
                path,
                autoEndTeardown
            )
        )
    }

    private fun buildNotification(
        context: Context,
        channelId: String,
        requestCode: Int,
        title: String,
        body: String,
        path: String,
        autoEndTeardown: Boolean
    ): Notification {
        val launchIntent = Intent(context, MainActivity::class.java)
        launchIntent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        launchIntent.putExtra(MainActivity.EXTRA_NAV_PATH, path)
        launchIntent.putExtra(MainActivity.EXTRA_AUTO_END_TEARDOWN, autoEndTeardown)
        val pendingIntent = PendingIntent.getActivity(
            context,
            requestCode,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or noticeImmutablePendingIntentFlag()
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        return builder
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setPriority(Notification.PRIORITY_DEFAULT)
            .build()
    }

    private fun ensureChannel(
        context: Context,
        channelId: String,
        channelName: String,
        channelDescription: String
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(channelId) != null) return
        val channel = NotificationChannel(
            channelId,
            channelName,
            NotificationManager.IMPORTANCE_DEFAULT
        )
        channel.description = channelDescription
        channel.setShowBadge(true)
        manager.createNotificationChannel(channel)
    }
}

private fun noticeImmutablePendingIntentFlag(): Int {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        PendingIntent.FLAG_IMMUTABLE
    } else {
        0
    }
}
