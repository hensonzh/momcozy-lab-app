package com.momcozymai.app;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;

final class NotificationIconHelper {

    private NotificationIconHelper() {
    }

    static NotificationCompat.Builder applyMaiIcons(
            @NonNull Context context,
            @NonNull NotificationCompat.Builder builder
    ) {
        Bitmap largeIcon = BitmapFactory.decodeResource(
                context.getResources(),
                R.drawable.ic_mai_notification_large
        );
        return builder
                .setSmallIcon(R.drawable.ic_stat_pump)
                .setLargeIcon(largeIcon);
    }
}
