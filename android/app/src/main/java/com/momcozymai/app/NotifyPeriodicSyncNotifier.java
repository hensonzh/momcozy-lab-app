package com.momcozymai.app;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Build;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.content.ContextCompat;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.Calendar;

/**
 * 同步成功后展示「提醒摘要」通知。
 * 冷启动拉取（app_launch）成功时始终尝试展示；15 分钟周期任务成功时仅当
 * {@link BuildConfig#MMC_ENABLE_PERIODIC_NOTIFY_SYNC} 为 true 时展示。
 */
public final class NotifyPeriodicSyncNotifier {

    private static final String CHANNEL_ID = "mmc_periodic_notify_sync_v1";
    private static final String CHANNEL_NAME = "计划同步摘要";
    /** 固定 id，多次周期任务覆盖同一条通知，避免通知栏刷屏 */
    public static final int NOTIFICATION_ID = 41_200_001;

    private NotifyPeriodicSyncNotifier() {
    }

    /** @param fromAppOpen true：冷启动入队拉取后的摘要，标题区分于周期任务 */
    static void show(Context context, JSONObject data, boolean fromAppOpen) {
        if (context == null || data == null) return;
        if (Build.VERSION.SDK_INT >= 33) {
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)
                    != PackageManager.PERMISSION_GRANTED) {
                android.util.Log.w("NotifyPeriodicSyncNotifier", "POST_NOTIFICATIONS not granted, cannot show sync summary");
                return;
            }
        }
        ensureChannel(context);

        JSONArray list = data.optJSONArray("notify_list");
        String body = buildSummaryBody(list);
        if (body.isEmpty()) {
            body = "本次同步暂无待推送提醒。";
        }

        Intent tap = new Intent(context, MainActivity.class);
        tap.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        tap.putExtra(MainActivity.EXTRA_NAV_PATH, "/schedule?mmcNotify=1");
        PendingIntent tapPi = PendingIntent.getActivity(
                context,
                8801,
                tap,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        String title = fromAppOpen ? "打开应用：提醒已同步" : "计划提醒已更新";
        NotificationCompat.Builder b = new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_pump)
                .setContentTitle(title)
                .setContentText(body.length() > 120 ? body.substring(0, 120) + "…" : body)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setCategory(NotificationCompat.CATEGORY_STATUS)
                .setAutoCancel(true)
                .setContentIntent(tapPi)
                .setOnlyAlertOnce(true);

        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, b.build());
    }

    /** 用户关闭后台提醒时撤下周期同步摘要通知 */
    public static void cancelShown(Context context) {
        if (context == null) return;
        NotificationManagerCompat.from(context.getApplicationContext()).cancel(NOTIFICATION_ID);
    }

    private static String buildSummaryBody(JSONArray list) {
        if (list == null || list.length() == 0) {
            return "";
        }
        JSONArray annotated;
        try {
            annotated = NotifyMessageResolver.annotateWithGroupIndex(list);
        } catch (Exception e) {
            return fallbackRawLines(list);
        }
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < annotated.length(); i++) {
            JSONObject row = annotated.optJSONObject(i);
            if (row == null) continue;
            String event = NotifyMessageResolver.normalizeEvent(row.optString("event", ""));
            if (event.isEmpty()) continue;
            int gIdx = row.optInt("_mmc_group_index", 0);
            String apiMsg = row.optString("message", "");
            String time = row.optString("time", "").trim();
            String line;
            if ("warning".equals(event)) {
                Calendar cal = Calendar.getInstance();
                long taskMs = NotifyAlarmScheduler.wallClockTodayAtMillis(time, cal);
                line = NotifyMessageResolver.resolveWarningBody(taskMs, cal.getTimeInMillis(), apiMsg);
            } else if ("pump".equals(event)) {
                Calendar cal = Calendar.getInstance();
                long taskExec = NotifyAlarmScheduler.nextWallClockMillis(time, cal);
                line = NotifyMessageResolver.resolvePumpBody(taskExec, cal.getTimeInMillis(), apiMsg);
            } else {
                line = NotifyMessageResolver.resolveBody(event, gIdx, apiMsg);
            }
            String label = NotifyMessageResolver.notificationTitle(event);
            if (sb.length() > 0) sb.append("\n\n");
            sb.append("• ").append(label);
            if (!time.isEmpty()) {
                sb.append("（").append(time).append("）");
            }
            sb.append("\n").append(line);
        }
        return sb.toString().trim();
    }

    private static String fallbackRawLines(JSONArray list) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < list.length(); i++) {
            JSONObject row = list.optJSONObject(i);
            if (row == null) continue;
            String m = row.optString("message", "").trim();
            if (m.isEmpty()) continue;
            if (sb.length() > 0) sb.append("\n\n");
            sb.append("• ").append(m);
        }
        return sb.toString().trim();
    }

    private static void ensureChannel(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (manager == null) return;
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return;
        NotificationChannel ch = new NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT
        );
        ch.setDescription("同步成功后的提醒摘要（含打开应用时）；需通知权限。周期摘要另受 gradle mmcPeriodicNotifySync 控制。");
        manager.createNotificationChannel(ch);
    }
}
