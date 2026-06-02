package com.momcozymai.app;

import android.content.Context;
import android.content.SharedPreferences;

import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;

public final class DeviceReminderWebSocketPrefs {
    private static final String PREF = "mmc_device_reminder_websocket";
    private static final String KEY_ENABLED = "enabled";
    private static final String KEY_WS_URL = "ws_url";
    private static final String KEY_API_BASE_URL = "api_base_url";
    private static final String KEY_BEARER_TOKEN = "bearer_token";
    private static final String KEY_USER_ID = "user_id";

    public static final String DEFAULT_WS_URL = "ws://192.168.204.127:8767/api/ws?token=websocket-token";
    public static final String DEFAULT_USER_ID = "u-demo-001";

    private DeviceReminderWebSocketPrefs() {
    }

    private static SharedPreferences prefs(Context context) {
        return context.getApplicationContext().getSharedPreferences(PREF, Context.MODE_PRIVATE);
    }

    public static void setConfig(Context context, String wsUrl, String apiBaseUrl, String bearerToken, String userId) {
        prefs(context).edit()
                .putString(KEY_WS_URL, normalize(wsUrl, DEFAULT_WS_URL))
                .putString(KEY_API_BASE_URL, normalize(apiBaseUrl, ""))
                .putString(KEY_BEARER_TOKEN, normalize(bearerToken, ""))
                .putString(KEY_USER_ID, normalize(userId, DEFAULT_USER_ID))
                .apply();
    }

    public static void setEnabled(Context context, boolean enabled) {
        prefs(context).edit().putBoolean(KEY_ENABLED, enabled).apply();
    }

    public static boolean isEnabled(Context context) {
        return prefs(context).getBoolean(KEY_ENABLED, false);
    }

    public static String getWsUrl(Context context) {
        String raw = prefs(context).getString(KEY_WS_URL, DEFAULT_WS_URL);
        return appendUserId(raw, getUserId(context));
    }

    public static String getApiBaseUrl(Context context) {
        String configured = prefs(context).getString(KEY_API_BASE_URL, "");
        if (configured != null && !configured.trim().isEmpty()) return configured.trim();
        return httpBaseFromWsUrl(getWsUrl(context));
    }

    public static String getBearerToken(Context context) {
        return prefs(context).getString(KEY_BEARER_TOKEN, "");
    }

    public static String getUserId(Context context) {
        return prefs(context).getString(KEY_USER_ID, DEFAULT_USER_ID);
    }

    private static String normalize(String value, String fallback) {
        String trimmed = value != null ? value.trim() : "";
        return trimmed.isEmpty() ? fallback : trimmed;
    }

    private static String httpBaseFromWsUrl(String wsUrl) {
        String trimmed = wsUrl != null ? wsUrl.trim() : "";
        if (trimmed.startsWith("ws://")) trimmed = "http://" + trimmed.substring("ws://".length());
        else if (trimmed.startsWith("wss://")) trimmed = "https://" + trimmed.substring("wss://".length());
        int queryIndex = trimmed.indexOf('?');
        if (queryIndex >= 0) trimmed = trimmed.substring(0, queryIndex);
        int pathIndex = trimmed.indexOf("/api/ws");
        if (pathIndex >= 0) trimmed = trimmed.substring(0, pathIndex);
        return trimmed;
    }

    private static String appendUserId(String wsUrl, String userId) {
        String url = wsUrl != null ? wsUrl.trim() : "";
        String uid = userId != null ? userId.trim() : "";
        if (url.isEmpty() || uid.isEmpty() || containsQueryKey(url, "user_id")) return url;
        String separator = url.contains("?") ? "&" : "?";
        return url + separator + "user_id=" + encodeQueryValue(uid);
    }

    private static boolean containsQueryKey(String url, String key) {
        int queryIndex = url.indexOf('?');
        if (queryIndex < 0 || queryIndex >= url.length() - 1) return false;
        String query = url.substring(queryIndex + 1);
        String[] pairs = query.split("&");
        for (String pair : pairs) {
            int eqIndex = pair.indexOf('=');
            String name = eqIndex >= 0 ? pair.substring(0, eqIndex) : pair;
            if (key.equals(name)) return true;
        }
        return false;
    }

    private static String encodeQueryValue(String value) {
        try {
            return URLEncoder.encode(value, "UTF-8");
        } catch (UnsupportedEncodingException e) {
            return value;
        }
    }
}
