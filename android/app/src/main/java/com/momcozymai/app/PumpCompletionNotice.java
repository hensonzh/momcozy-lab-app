package com.momcozymai.app;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

/**
 * 吸乳进度达 100% 时的一条可清除本地消息（与前台进度通知分离，方案 B）。
 */
public final class PumpCompletionNotice {

    private static final String CHANNEL_ID = "pump_session_completion_channel_v1";
    private static final String CHANNEL_NAME = "吸乳提醒";
    /** 与 {@link #cancel(Context)} 一致，供划多任务 / 停会话时一并移除。 */
    public static final int NOTIFICATION_ID = 21003;

    private PumpCompletionNotice() {
    }

    public static void show(Context context) {
        if (context == null) return;
        ensureChannel(context);
        final Intent launchIntent = new Intent(context, MainActivity.class);
        launchIntent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        launchIntent.putExtra(MainActivity.EXTRA_NAV_PATH, "/pump");
        final PendingIntent contentIntent = PendingIntent.getActivity(
                context,
                1002,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        final String title = "吸奶已完成！";
        final String text = "如感觉还有硬块或发胀，可以再吸一会帮助排空～";

        final NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_pump)
                .setContentTitle(title)
                .setContentText(text)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(text))
                .setContentIntent(contentIntent)
                .setAutoCancel(true)
                .setOnlyAlertOnce(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE);

        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, builder.build());
    }

    /** 划掉多任务卡片或结束吸乳会话停 FGS 时调用，移除「吸奶已完成」本地消息。 */
    public static void cancel(Context context) {
        if (context == null) return;
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID);
    }

    private static void ensureChannel(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        final NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (manager == null) return;
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return;
        final NotificationChannel ch = new NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT
        );
        ch.setDescription("吸乳进度完成等提醒");
        ch.setShowBadge(true);
        manager.createNotificationChannel(ch);
    }
}
