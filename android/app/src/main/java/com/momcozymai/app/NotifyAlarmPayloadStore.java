package com.momcozymai.app;

import android.content.Context;
import android.content.SharedPreferences;

import androidx.annotation.Nullable;

/**
 * 闹钟触发前将展示数据写入 SharedPreferences，避免 Intent 体积过大。
 */
public final class NotifyAlarmPayloadStore {

    private static final String PREF = "mmc_notify_alarm_payload";

    private NotifyAlarmPayloadStore() {
    }

    private static SharedPreferences p(Context ctx) {
        return ctx.getApplicationContext().getSharedPreferences(PREF, Context.MODE_PRIVATE);
    }

    static void save(Context ctx, int alarmId, String jsonPayload) {
        p(ctx).edit().putString("k_" + alarmId, jsonPayload != null ? jsonPayload : "").apply();
    }

    @Nullable
    static String consume(Context ctx, int alarmId) {
        String key = "k_" + alarmId;
        String v = p(ctx).getString(key, null);
        if (v != null) {
            p(ctx).edit().remove(key).apply();
        }
        return v;
    }

    /** 不移除，供全屏 Activity 读取 */
    @Nullable
    static String peek(Context ctx, int alarmId) {
        return p(ctx).getString("k_" + alarmId, null);
    }

    static void remove(Context ctx, int alarmId) {
        p(ctx).edit().remove("k_" + alarmId).apply();
    }
}
