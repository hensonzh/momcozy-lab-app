package com.momcozymai.app;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * 开机后若功能开启：刷新 15 分钟周期任务（UPDATE）并补拉一次提醒列表、重建闹钟。
 */
public class NotifyBootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || intent.getAction() == null) return;
        if (!Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) return;
        if (!BackgroundNotifyPrefs.isEnabled(context)) return;
        Context app = context.getApplicationContext();
        NotifyWorkScheduler.enqueuePeriodic(app);
        NotifyWorkScheduler.enqueueOneShot(app);
    }
}
