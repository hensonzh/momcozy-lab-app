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
 * 吸乳会话自动结束（全离线 / 暂停超时）且用户不在吸乳页时的可清除本地消息。
 */
public final class PumpAutoEndNotice {

    private static final String CHANNEL_ID = "pump_session_auto_end_channel_v1";
    private static final String CHANNEL_NAME = "吸乳会话结束";
    public static final int NOTIFICATION_ID = 21004;

    private PumpAutoEndNotice() {
    }

    public static void show(Context context, String title, String body, String navPath, boolean autoEndTeardown) {
        if (context == null) return;
        ensureChannel(context);
        final Intent launchIntent = new Intent(context, MainActivity.class);
        launchIntent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        launchIntent.putExtra(MainActivity.EXTRA_NAV_PATH, navPath != null ? navPath : "/");
        launchIntent.putExtra(MainActivity.EXTRA_AUTO_END_TEARDOWN, autoEndTeardown);
        final PendingIntent contentIntent = PendingIntent.getActivity(
                context,
                1003,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        final String t = title != null ? title : "";
        final String b = body != null ? body : "";

        final NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_pump)
                .setContentTitle(t)
                .setContentText(b)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(b))
                .setContentIntent(contentIntent)
                .setAutoCancel(true)
                .setOnlyAlertOnce(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE);
        NotificationIconHelper.applyMaiIcons(context, builder);

        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, builder.build());
    }

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
        ch.setDescription("设备离线或长时间暂停等会话结束提醒");
        ch.setShowBadge(true);
        manager.createNotificationChannel(ch);
    }
}
