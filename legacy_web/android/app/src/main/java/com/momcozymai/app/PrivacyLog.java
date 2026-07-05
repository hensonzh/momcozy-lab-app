package com.momcozymai.app;

import org.json.JSONObject;

import java.util.Iterator;

final class PrivacyLog {
    private PrivacyLog() {
    }

    static String shortHash(String value) {
        String normalized = value != null ? value.trim() : "";
        if (normalized.isEmpty()) return "empty";
        return "hash:" + Integer.toHexString(normalized.hashCode());
    }

    static String jsonShape(JSONObject payload) {
        if (payload == null) return "null";
        StringBuilder sb = new StringBuilder("JSONObject{");
        Iterator<String> keys = payload.keys();
        int count = 0;
        while (keys.hasNext()) {
            String key = keys.next();
            if (count > 0) sb.append(',');
            sb.append(key).append('=').append(valueShape(payload.opt(key)));
            count += 1;
        }
        sb.append("} fields=").append(count);
        return sb.toString();
    }

    static String textShape(String text) {
        String normalized = text != null ? text : "";
        return "textLength=" + normalized.length();
    }

    private static String valueShape(Object value) {
        if (value == null || value == JSONObject.NULL) return "null";
        if (value instanceof JSONObject) return "object";
        if (value instanceof org.json.JSONArray) return "array";
        if (value instanceof Number) return "number";
        if (value instanceof Boolean) return "boolean";
        return "stringLength=" + value.toString().length();
    }
}
