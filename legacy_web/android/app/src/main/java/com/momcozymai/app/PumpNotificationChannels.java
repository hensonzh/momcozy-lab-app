package com.momcozymai.app;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.os.Build;

/**
 * 吸乳相关通知渠道在应用启动时一次性注册，使用户在「应用通知管理」中即可看到全部分类；
 * 否则 Android 仅在首次向某渠道 post 通知后才创建该渠道（与 {@link PumpSessionForegroundService}、
 * {@link PumpCompletionNotice}、{@link PumpAutoEndNotice} 中的 channel id 保持一致）。
 */
public final class PumpNotificationChannels {

    /** 与 {@link PumpSessionForegroundService} 一致 */
    private static final String PROGRESS_ID = "pump_session_progress_channel_v6";
    private static final String PROGRESS_NAME = "吸乳会话进度";

    /** 与 {@link PumpCompletionNotice} 一致 */
    private static final String COMPLETION_ID = "pump_session_completion_channel_v1";
    private static final String COMPLETION_NAME = "吸乳进度100%提醒";

    /** 与 {@link PumpAutoEndNotice} 一致 */
    private static final String AUTO_END_ID = "pump_session_auto_end_channel_v1";
    private static final String AUTO_END_NAME = "吸乳会话结束";

    private PumpNotificationChannels() {
    }

    public static void registerAll(Context context) {
        if (context == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        final NotificationManager manager =
                (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (manager == null) return;

        if (manager.getNotificationChannel(PROGRESS_ID) == null) {
            final NotificationChannel ch = new NotificationChannel(
                    PROGRESS_ID,
                    PROGRESS_NAME,
                    NotificationManager.IMPORTANCE_LOW
            );
            ch.setDescription("进行中会话的吸乳进度与状态");
            ch.setShowBadge(false);
            ch.enableVibration(false);
            ch.enableLights(false);
            manager.createNotificationChannel(ch);
        }

        if (manager.getNotificationChannel(COMPLETION_ID) == null) {
            final NotificationChannel ch = new NotificationChannel(
                    COMPLETION_ID,
                    COMPLETION_NAME,
                    NotificationManager.IMPORTANCE_DEFAULT
            );
            ch.setDescription("吸乳进度完成等提醒");
            ch.setShowBadge(true);
            manager.createNotificationChannel(ch);
        }

        if (manager.getNotificationChannel(AUTO_END_ID) == null) {
            final NotificationChannel ch = new NotificationChannel(
                    AUTO_END_ID,
                    AUTO_END_NAME,
                    NotificationManager.IMPORTANCE_DEFAULT
            );
            ch.setDescription("设备离线或长时间暂停等会话结束提醒");
            ch.setShowBadge(true);
            manager.createNotificationChannel(ch);
        }
    }
}
