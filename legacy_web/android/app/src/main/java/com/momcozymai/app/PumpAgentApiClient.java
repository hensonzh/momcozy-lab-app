package com.momcozymai.app;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

final class PumpAgentApiClient {
    private PumpAgentApiClient() {
    }

    static JSONObject post(String apiBaseUrl, String bearerToken, String path, JSONObject body) throws Exception {
        String base = apiBaseUrl != null ? apiBaseUrl.trim() : "";
        if (base.endsWith("/")) base = base.substring(0, base.length() - 1);
        if (base.isEmpty()) throw new IllegalStateException("api base url is empty");

        HttpURLConnection conn = (HttpURLConnection) new URL(base + path).openConnection();
        conn.setRequestMethod("POST");
        conn.setConnectTimeout(25_000);
        conn.setReadTimeout(25_000);
        conn.setRequestProperty("Accept", "application/json");
        conn.setRequestProperty("Content-Type", "application/json; charset=utf-8");
        if (bearerToken != null && !bearerToken.trim().isEmpty()) {
            conn.setRequestProperty("Authorization", "Bearer " + bearerToken.trim());
        }
        conn.setDoOutput(true);
        byte[] payload = body.toString().getBytes(StandardCharsets.UTF_8);
        try (OutputStream os = conn.getOutputStream()) {
            os.write(payload);
        }

        int code = conn.getResponseCode();
        InputStream is = code >= 400 ? conn.getErrorStream() : conn.getInputStream();
        if (is == null) throw new IllegalStateException("HTTP " + code + " empty body");
        String raw = readAll(is);
        conn.disconnect();
        JSONObject root = new JSONObject(raw);
        if (root.has("status") && root.has("data")) {
            int status = root.optInt("status", 0);
            if (status != 200) {
                throw new IllegalStateException("api status " + status + " " + root.optString("message", ""));
            }
            JSONObject data = root.optJSONObject("data");
            return data != null ? data : new JSONObject();
        }
        return root;
    }

    private static String readAll(InputStream is) throws Exception {
        BufferedReader br = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8));
        StringBuilder sb = new StringBuilder();
        String line;
        while ((line = br.readLine()) != null) sb.append(line);
        return sb.toString();
    }
}
