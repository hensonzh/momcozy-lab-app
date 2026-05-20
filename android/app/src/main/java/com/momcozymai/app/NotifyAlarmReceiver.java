package com.momcozymai.app;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.util.Log;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

import org.json.JSONObject;

/**
 * AlarmManager 触发：高优先级通知；应用不在前台时再附加全屏提醒页（近似悬浮）。
 */
public class NotifyAlarmReceiver extends BroadcastReceiver {

    private static final String TAG = "NotifyAlarmReceiver";
    public static final String EXTRA_ALARM_ID = "com.momcozymai.app.EXTRA_NOTIFY_ALARM_ID";

    static final String CHANNEL_ID = "mmc_background_notify_v1";
    private static final String CHANNEL_NAME = "计划与奶量提醒";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null) return;
        String action = intent.getAction();
        if (PumpCompletionNotice.ACTION_CONTINUE.equals(action)) {
            PumpCompletionNotice.cancel(context);
            return;
        }
        if (PumpCompletionNotice.ACTION_STOP.equals(action)) {
            PumpCompletionNotice.cancel(context);
            Intent launchIntent = new Intent(context, MainActivity.class);
            launchIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            launchIntent.putExtra(MainActivity.EXTRA_NAV_PATH, "/pump");
            context.startActivity(launchIntent);
            return;
        }
        if (!BackgroundNotifyPrefs.isEnabled(context)) return;
        int alarmId = intent.getIntExtra(EXTRA_ALARM_ID, -1);
        if (alarmId < 0) return;

        String raw = NotifyAlarmPayloadStore.peek(context, alarmId);
        if (raw == null || raw.isEmpty()) {
            Log.w(TAG, "missing payload for alarm " + alarmId);
            return;
        }
        NotifyAlarmScheduler.markTriggered(context, alarmId);
        try {
            JSONObject payload = new JSONObject(raw);
            String title = payload.optString("title", "提醒");
            String body = payload.optString("body", "");
            ensureChannel(context);
            int nid = 41_000_000 + alarmId;
            boolean appInForeground = MainActivity.isAppInForeground();
            PendingIntent fullPi = null;
            if (!appInForeground) {
                Intent full = new Intent(context, NotifyReminderActivity.class);
                full.putExtra(NotifyReminderActivity.EXTRA_ALARM_ID, alarmId);
                full.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                fullPi = PendingIntent.getActivity(
                        context,
                        nid + 1,
                        full,
                        PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
                );
            }

            Intent tap = new Intent(context, MainActivity.class);
            tap.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            tap.putExtra(MainActivity.EXTRA_NAV_PATH, payload.optString("path", "/"));
            String nj = payload.optString("notifyJson", "");
            if (!nj.isEmpty()) {
                tap.putExtra(MainActivity.EXTRA_NOTIFY_JSON, nj);
            }
            tap.putExtra(MainActivity.EXTRA_NOTIFY_ALARM_CLEANUP, alarmId);
            PendingIntent tapPi = PendingIntent.getActivity(
                    context,
                    nid + 2,
                    tap,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );

            NotificationCompat.Builder b = new NotificationCompat.Builder(context, CHANNEL_ID)
                    .setSmallIcon(R.drawable.ic_stat_pump)
                    .setContentTitle(title)
                    .setContentText(body.length() > 80 ? body.substring(0, 80) + "…" : body)
                    .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .setAutoCancel(true)
                    .setContentIntent(tapPi);

            if (fullPi != null) {
                b.setFullScreenIntent(fullPi, true);
            }

            NotificationManagerCompat.from(context).notify(nid, b.build());
        } catch (Exception e) {
            Log.e(TAG, "show notify", e);
        }
    }

    static void ensureChannel(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (manager == null) return;
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return;
        NotificationChannel ch = new NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
        );
        ch.setDescription("吸奶/喂养、风险预警、生长数据与每日小结等系统提醒");
        ch.setLockscreenVisibility(android.app.Notification.VISIBILITY_PUBLIC);
        manager.createNotificationChannel(ch);
    }
}
