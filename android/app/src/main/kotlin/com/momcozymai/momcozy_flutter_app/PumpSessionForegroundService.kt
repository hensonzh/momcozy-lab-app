package com.momcozymai.momcozy_flutter_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

class PumpSessionForegroundService : Service() {
    override fun onCreate() {
        super.onCreate()
        ensureChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForegroundNotification()
            return START_NOT_STICKY
        }

        val state = safeState(intent?.getStringExtra(EXTRA_STATE))
        val processAll = clampProgress(intent?.getIntExtra(EXTRA_PROCESS_ALL, 0) ?: 0)
        val elapsedSeconds = (intent?.getIntExtra(EXTRA_ELAPSED_SECONDS, 0) ?: 0).coerceAtLeast(0)
        val leftMilkMl = (intent?.getIntExtra(EXTRA_LEFT_MILK_ML, 0) ?: 0).coerceAtLeast(0)
        val rightMilkMl = (intent?.getIntExtra(EXTRA_RIGHT_MILK_ML, 0) ?: 0).coerceAtLeast(0)
        updateSnapshot(state, elapsedSeconds, leftMilkMl, rightMilkMl)
        startForeground(
            NOTIFICATION_ID,
            buildProgressNotification(state, processAll, elapsedSeconds)
        )
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun stopForegroundNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(NOTIFICATION_ID)
        PumpSessionLocalNotice.cancelAll(this)
        clearSnapshot()
        stopSelf()
    }

    private fun buildProgressNotification(
        state: String,
        processAll: Int,
        elapsedSeconds: Int
    ): Notification {
        val launchIntent = Intent(this, MainActivity::class.java)
        launchIntent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        launchIntent.putExtra(MainActivity.EXTRA_NAV_PATH, "/pump")
        val pendingIntent = PendingIntent.getActivity(
            this,
            1001,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutablePendingIntentFlag()
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val stateText = if (state == "paused") "Paused" else "Running"
        val body = "State: $stateText, progress $processAll%, elapsed ${elapsedSeconds}s"
        return builder
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentTitle("Pump session in progress")
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setContentIntent(pendingIntent)
            .setCategory(Notification.CATEGORY_STATUS)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setPriority(Notification.PRIORITY_LOW)
            .build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW
        )
        channel.description = CHANNEL_DESCRIPTION
        channel.setShowBadge(false)
        channel.enableVibration(false)
        channel.enableLights(false)
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val ACTION_START_OR_UPDATE =
            "com.momcozymai.flutter.PUMP_SESSION_START_OR_UPDATE"
        const val ACTION_STOP = "com.momcozymai.flutter.PUMP_SESSION_STOP"
        const val EXTRA_STATE = "state"
        const val EXTRA_PROCESS_ALL = "process_all"
        const val EXTRA_ELAPSED_SECONDS = "elapsed_seconds"
        const val EXTRA_LEFT_MILK_ML = "left_milk_ml"
        const val EXTRA_RIGHT_MILK_ML = "right_milk_ml"

        private const val CHANNEL_ID = "momcozy_flutter_pump_session_progress"
        private const val CHANNEL_NAME = "Pump session progress"
        private const val CHANNEL_DESCRIPTION = "Foreground pump session progress"
        private const val NOTIFICATION_ID = 21002
        private val SNAPSHOT_LOCK = Any()
        private var snapshotActive = false
        private var snapshotElapsedSeconds = 0
        private var snapshotLeftMilkMl = 0
        private var snapshotRightMilkMl = 0
        private var snapshotPaused = false

        fun startOrUpdate(
            context: Context,
            state: String,
            processAll: Int,
            elapsedSeconds: Int,
            leftMilkMl: Int? = null,
            rightMilkMl: Int? = null
        ) {
            updateSnapshot(
                safeState(state),
                elapsedSeconds.coerceAtLeast(0),
                leftMilkMl,
                rightMilkMl
            )
            val intent = Intent(context, PumpSessionForegroundService::class.java)
            intent.action = ACTION_START_OR_UPDATE
            intent.putExtra(EXTRA_STATE, safeState(state))
            intent.putExtra(EXTRA_PROCESS_ALL, clampProgress(processAll))
            intent.putExtra(EXTRA_ELAPSED_SECONDS, elapsedSeconds.coerceAtLeast(0))
            intent.putExtra(EXTRA_LEFT_MILK_ML, leftMilkMl ?: snapshotField("leftMilkMl"))
            intent.putExtra(EXTRA_RIGHT_MILK_ML, rightMilkMl ?: snapshotField("rightMilkMl"))
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, PumpSessionForegroundService::class.java)
            intent.action = ACTION_STOP
            clearSnapshot()
            context.startService(intent)
        }

        fun restoreSnapshot(): Map<String, Any?>? {
            return synchronized(SNAPSHOT_LOCK) {
                if (!snapshotActive) {
                    null
                } else {
                    mapOf(
                        "active" to true,
                        "elapsedSeconds" to snapshotElapsedSeconds,
                        "leftMilkMl" to snapshotLeftMilkMl,
                        "rightMilkMl" to snapshotRightMilkMl,
                        "paused" to snapshotPaused
                    )
                }
            }
        }

        private fun updateSnapshot(
            state: String,
            elapsedSeconds: Int,
            leftMilkMl: Int?,
            rightMilkMl: Int?
        ) {
            synchronized(SNAPSHOT_LOCK) {
                snapshotActive = true
                snapshotElapsedSeconds = elapsedSeconds.coerceAtLeast(0)
                snapshotLeftMilkMl = leftMilkMl?.coerceAtLeast(0) ?: snapshotLeftMilkMl
                snapshotRightMilkMl = rightMilkMl?.coerceAtLeast(0) ?: snapshotRightMilkMl
                snapshotPaused = safeState(state) == "paused"
            }
        }

        private fun clearSnapshot() {
            synchronized(SNAPSHOT_LOCK) {
                snapshotActive = false
                snapshotElapsedSeconds = 0
                snapshotLeftMilkMl = 0
                snapshotRightMilkMl = 0
                snapshotPaused = false
            }
        }

        private fun snapshotField(name: String): Int {
            return synchronized(SNAPSHOT_LOCK) {
                when (name) {
                    "leftMilkMl" -> snapshotLeftMilkMl
                    "rightMilkMl" -> snapshotRightMilkMl
                    else -> 0
                }
            }
        }

        private fun safeState(state: String?): String {
            return if (state == "paused") "paused" else "running"
        }

        private fun clampProgress(progress: Int): Int {
            return progress.coerceIn(0, 100)
        }
    }
}

private fun immutablePendingIntentFlag(): Int {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        PendingIntent.FLAG_IMMUTABLE
    } else {
        0
    }
}
