package com.momcozymai.app;

import android.content.Context;
import android.content.SharedPreferences;

/**
 * 系统级后台提醒：持久化 API 配置与功能开关（供 WorkManager / AlarmManager 读取）。
 */
public final class BackgroundNotifyPrefs {

    private static final String PREF = "mmc_background_notify";

    static final String KEY_ENABLED = "enabled";
    static final String KEY_API_BASE_URL = "api_base_url";
    static final String KEY_BEARER_TOKEN = "bearer_token";
    static final String KEY_USER_ID = "user_id";
    private static final String KEY_ALARM_IDS = "alarm_ids_v1";

    private BackgroundNotifyPrefs() {
    }

    public static SharedPreferences prefs(Context ctx) {
        return ctx.getApplicationContext().getSharedPreferences(PREF, Context.MODE_PRIVATE);
    }

    public static boolean isEnabled(Context ctx) {
        return prefs(ctx).getBoolean(KEY_ENABLED, false);
    }

    public static void setEnabled(Context ctx, boolean enabled) {
        prefs(ctx).edit().putBoolean(KEY_ENABLED, enabled).apply();
    }

    public static String getApiBaseUrl(Context ctx) {
        return prefs(ctx).getString(KEY_API_BASE_URL, "");
    }

    public static String getBearerToken(Context ctx) {
        return prefs(ctx).getString(KEY_BEARER_TOKEN, "");
    }

    public static String getUserId(Context ctx) {
        return prefs(ctx).getString(KEY_USER_ID, "");
    }

    public static void setConfig(Context ctx, String apiBaseUrl, String bearerToken, String userId) {
        prefs(ctx).edit()
                .putString(KEY_API_BASE_URL, apiBaseUrl != null ? apiBaseUrl.trim() : "")
                .putString(KEY_BEARER_TOKEN, bearerToken != null ? bearerToken.trim() : "")
                .putString(KEY_USER_ID, userId != null ? userId.trim() : "")
                .apply();
    }
}
