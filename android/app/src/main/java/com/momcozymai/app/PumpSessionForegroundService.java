package com.momcozymai.app;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

public class PumpSessionForegroundService extends Service {
    private static final String TAG = "PumpSessionFG";
    public static final String ACTION_START_OR_UPDATE = "pump.session.notification.START_OR_UPDATE";
    public static final String ACTION_STOP = "pump.session.notification.STOP";
    public static final String EXTRA_STATE = "state";
    public static final String EXTRA_PROCESS_ALL = "process_all";

    /** Low importance：尽量避免抬头弹窗，仅在下拉抽屉中常驻。 */
    private static final String CHANNEL_ID = "pump_session_progress_channel_v6";
    private static final String CHANNEL_NAME = "吸乳会话进度";
    private static final String CHANNEL_DESCRIPTION = "进行中会话的吸乳进度与状态";
    private static final int NOTIFICATION_ID = 21002;

    private boolean foregroundStarted = false;

    @Override
    public void onCreate() {
        super.onCreate();
        ensureChannel();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        final String action = intent != null ? intent.getAction() : null;
        Log.i(TAG, "onStartCommand action=" + action);
        if (ACTION_STOP.equals(action)) {
            Log.i(TAG, "stop foreground requested");
            stopForegroundNotificationAndQuit();
            return START_NOT_STICKY;
        }

        final String state = safeState(intent != null ? intent.getStringExtra(EXTRA_STATE) : null);
        int processAll = intent != null ? intent.getIntExtra(EXTRA_PROCESS_ALL, 0) : 0;
        processAll = clampProgress(processAll);
        Log.i(TAG, "build notification state=" + state + ", processAll=" + processAll);

        final Notification n = buildProgressNotification(state, processAll);
        if (!foregroundStarted) {
            startForeground(NOTIFICATION_ID, n);
            foregroundStarted = true;
            Log.i(TAG, "startForeground id=" + NOTIFICATION_ID);
        } else {
            NotificationManagerCompat.from(this).notify(NOTIFICATION_ID, n);
            Log.i(TAG, "notify updated id=" + NOTIFICATION_ID);
        }
        return START_STICKY;
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    /**
     * 用户从多任务划掉应用卡片时触发：仅原生移除前台通知与服务，不涉及 Web/JS。
     * （部分 OEM 行为差异下仍可能先于进程结束未回调，此为系统常见限制。）
     */
    @Override
    public void onTaskRemoved(Intent rootIntent) {
        super.onTaskRemoved(rootIntent);
        Log.i(TAG, "onTaskRemoved: cleared recent task → remove FG notification");
        stopForegroundNotificationAndQuit();
    }

    private void stopForegroundNotificationAndQuit() {
        try {
            stopForeground(STOP_FOREGROUND_REMOVE);
        } catch (RuntimeException e) {
            Log.w(TAG, "stopForeground failed (may not have been FG)", e);
        }
        NotificationManagerCompat.from(this).cancel(NOTIFICATION_ID);
        PumpCompletionNotice.cancel(this);
        PumpAutoEndNotice.cancel(this);
        foregroundStarted = false;
        stopSelf();
    }

    private void ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        final NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (manager == null) return;
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return;
        final NotificationChannel ch = new NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
        );
        ch.setDescription(CHANNEL_DESCRIPTION);
        ch.setShowBadge(false);
        ch.enableVibration(false);
        ch.enableLights(false);
        manager.createNotificationChannel(ch);
    }

    private Notification buildProgressNotification(String state, int processAll) {
        final Intent launchIntent = new Intent(this, MainActivity.class);
        launchIntent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        launchIntent.putExtra(MainActivity.EXTRA_NAV_PATH, "/pump");
        final PendingIntent contentIntent = PendingIntent.getActivity(
                this,
                1001,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        final String stateText = stateText(state);
        final String title = "当前吸乳进程：" + processAll + "%";
        final String body = "会话状态：" + stateText;

        return new NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_pump)
                .setContentTitle(title)
                .setContentText(body)
                .setSubText("MaiMomCozy")
                .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setSilent(true)
                .setContentIntent(contentIntent)
                .setProgress(100, processAll, false)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
                .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
                .build();
    }

    private static int clampProgress(int progress) {
        if (progress < 0) return 0;
        return Math.min(progress, 100);
    }

    private static String safeState(String state) {
        if ("running".equals(state) || "paused".equals(state)) {
            return state;
        }
        return "running";
    }

    private static String stateText(String state) {
        if ("paused".equals(state)) return "已暂停";
        return "进行中";
    }
}
