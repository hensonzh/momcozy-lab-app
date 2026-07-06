package com.momcozymai.app;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Locale;

/**
 * 原生 GET /v1/notify/query，与 Web 信封解析逻辑对齐。
 */
public final class NotifyApiClient {

    private NotifyApiClient() {
    }

    public static JSONObject fetchNotifyQuery(String apiBaseUrl, String bearerToken, String userId) throws Exception {
        String base = apiBaseUrl != null ? apiBaseUrl.trim() : "";
        if (base.endsWith("/")) {
            base = base.substring(0, base.length() - 1);
        }
        String ts = Instant.now().toString();
        String q = String.format(Locale.US, "user_id=%s&timestamp=%s",
                java.net.URLEncoder.encode(userId != null ? userId : "", StandardCharsets.UTF_8.name()),
                java.net.URLEncoder.encode(ts, StandardCharsets.UTF_8.name()));
        String urlStr = base + "/v1/notify/query?" + q;

        HttpURLConnection conn = (HttpURLConnection) new URL(urlStr).openConnection();
        conn.setRequestMethod("GET");
        conn.setConnectTimeout(25_000);
        conn.setReadTimeout(25_000);
        conn.setRequestProperty("Accept", "application/json");
        if (bearerToken != null && !bearerToken.trim().isEmpty()) {
            conn.setRequestProperty("Authorization", "Bearer " + bearerToken.trim());
        }

        int code = conn.getResponseCode();
        InputStream is = code >= 400 ? conn.getErrorStream() : conn.getInputStream();
        if (is == null) {
            throw new IllegalStateException("HTTP " + code + " empty body");
        }
        String body = readAll(is);
        conn.disconnect();

        JSONObject root = new JSONObject(body);
        JSONObject data;
        if (root.has("status") && root.has("data")) {
            int status = root.optInt("status", 0);
            if (status != 200) {
                throw new IllegalStateException("api status " + status + " " + root.optString("message", ""));
            }
            data = root.getJSONObject("data");
        } else {
            data = root;
        }
        return data;
    }

    private static String readAll(InputStream is) throws Exception {
        BufferedReader br = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8));
        StringBuilder sb = new StringBuilder();
        String line;
        while ((line = br.readLine()) != null) {
            sb.append(line);
        }
        return sb.toString();
    }
}
