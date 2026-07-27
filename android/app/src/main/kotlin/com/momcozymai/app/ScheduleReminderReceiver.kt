package com.momcozymai.app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build

class ScheduleReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val requestCode = intent?.getIntExtra(EXTRA_REQUEST_CODE, -1) ?: -1
        if (requestCode < 0) return
        val reminder = ScheduleReminderScheduler.consumeTriggered(context, requestCode) ?: return
        if (!hasNotificationPermission(context)) return

        ensureChannel(context)
        val path = Uri.Builder()
            .path("/schedule")
            .appendQueryParameter("date", reminder.date)
            .appendQueryParameter("task_id", reminder.taskId)
            .build()
            .toString()
        val launchIntent = Intent(context, MainActivity::class.java)
            .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            .putExtra(MainActivity.EXTRA_NAV_PATH, path)
        val contentIntent = PendingIntent.getActivity(
            context,
            requestCode,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableSchedulePendingIntentFlag(),
        )
        val notification = notificationBuilder(context)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(DEFAULT_TITLE)
            .setContentText(DEFAULT_BODY)
            .setStyle(Notification.BigTextStyle().bigText(DEFAULT_BODY))
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPriority(Notification.PRIORITY_DEFAULT)
            .build()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        manager.notify(NOTIFICATION_ID_BASE + requestCode, notification)
    }

    private fun notificationBuilder(context: Context): Notification.Builder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "计划提醒",
            NotificationManager.IMPORTANCE_DEFAULT,
        )
        channel.description = "计划任务的本地系统提醒"
        channel.lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        channel.setShowBadge(true)
        manager.createNotificationChannel(channel)
    }

    companion object {
        internal const val EXTRA_REQUEST_CODE = "momcozy.schedule.extra.REQUEST_CODE"
        internal const val EXTRA_TASK_ID = "momcozy.schedule.extra.TASK_ID"
        internal const val EXTRA_DATE = "momcozy.schedule.extra.DATE"
        private const val CHANNEL_ID = "momcozy_schedule_reminders_v1"
        private const val NOTIFICATION_ID_BASE = 42000000
        private const val DEFAULT_TITLE = "计划提醒"
        private const val DEFAULT_BODY = "你有一项计划即将开始，打开 Momcozy 查看详情。"
    }
}

class ScheduleReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        ScheduleReminderScheduler.reschedulePersisted(context)
    }
}

private fun hasNotificationPermission(context: Context): Boolean {
    return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
        context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
}

private fun immutableSchedulePendingIntentFlag(): Int {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        PendingIntent.FLAG_IMMUTABLE
    } else {
        0
    }
}
