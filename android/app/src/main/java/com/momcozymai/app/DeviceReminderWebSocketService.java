package com.momcozymai.app;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.IOException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import okhttp3.WebSocket;
import okhttp3.WebSocketListener;

public class DeviceReminderWebSocketService extends Service {
    public static final String ACTION_START = "device.reminder.websocket.START";
    public static final String ACTION_STOP = "device.reminder.websocket.STOP";

    private static final String TAG = "DeviceReminderWS";
    private static final String CHANNEL_ID = "device_reminder_websocket_channel_v1";
    private static final String CHANNEL_NAME = "提醒长连接";
    private static final int NOTIFICATION_ID = 23001;
    private static final MediaType JSON_MEDIA_TYPE = MediaType.get("application/json; charset=utf-8");
    private static final String TASK_REMINDER_MESSAGE = "妈妈，吸奶/喂养时间还有15分钟就到咯，可以提前准备一下哦～";
    private static final long[] RECONNECT_DELAYS_MS = new long[]{1000L, 3000L, 5000L, 10000L, 15000L};

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final OkHttpClient client = new OkHttpClient.Builder().build();
    private final ExecutorService executor = Executors.newSingleThreadExecutor();

    private WebSocket webSocket;
    private boolean stopped = true;
    private int reconnectAttempt = 0;

    @Override
    public void onCreate() {
        super.onCreate();
        ensureChannel(this);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String action = intent != null ? intent.getAction() : null;
        if (ACTION_STOP.equals(action)) {
            stopWebSocket();
            stopForeground(true);
            stopSelf();
            return START_NOT_STICKY;
        }

        if (!DeviceReminderWebSocketPrefs.isEnabled(this)) {
            stopSelf();
            return START_NOT_STICKY;
        }

        startForeground(NOTIFICATION_ID, buildForegroundNotification());
        startWebSocket();
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        stopWebSocket();
        executor.shutdownNow();
        super.onDestroy();
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private synchronized void startWebSocket() {
        if (!stopped && webSocket != null) return;
        stopped = false;
        connect();
    }

    private synchronized void stopWebSocket() {
        stopped = true;
        mainHandler.removeCallbacksAndMessages(null);
        if (webSocket != null) {
            webSocket.close(1000, "service stop");
            webSocket = null;
        }
    }

    private void connect() {
        if (stopped || !DeviceReminderWebSocketPrefs.isEnabled(this)) return;
        String wsUrl = DeviceReminderWebSocketPrefs.getWsUrl(this);
        try {
            Request request = new Request.Builder().url(wsUrl).build();
            webSocket = client.newWebSocket(request, new WebSocketListener() {
                @Override
                public void onOpen(WebSocket webSocket, Response response) {
                    reconnectAttempt = 0;
                    Log.i(TAG, "connected");
                }

                @Override
                public void onMessage(WebSocket webSocket, String text) {
                    handleWebSocketMessage(text);
                }

                @Override
                public void onFailure(WebSocket webSocket, Throwable t, Response response) {
                    Log.w(TAG, "websocket failure", t);
                    scheduleReconnect();
                }

                @Override
                public void onClosed(WebSocket webSocket, int code, String reason) {
                    Log.w(TAG, "websocket closed code=" + code + " reason=" + reason);
                    scheduleReconnect();
                }
            });
        } catch (Exception e) {
            Log.w(TAG, "connect failed", e);
            scheduleReconnect();
        }
    }

    private void scheduleReconnect() {
        if (stopped || !DeviceReminderWebSocketPrefs.isEnabled(this)) return;
        synchronized (this) {
            webSocket = null;
        }
        long delay = RECONNECT_DELAYS_MS[Math.min(reconnectAttempt, RECONNECT_DELAYS_MS.length - 1)];
        reconnectAttempt += 1;
        mainHandler.postDelayed(this::connect, delay);
    }

    private void handleWebSocketMessage(String raw) {
        try {
            Object payload = parseJsonFrame(raw);
            String reminderType = findReminderType(payload);
            if (reminderType == null || reminderType.isEmpty()) {
                Log.w(TAG, "ignore message without supported reminder_type");
                return;
            }
            executor.execute(() -> executeReminder(reminderType));
        } catch (Exception e) {
            Log.w(TAG, "parse websocket message failed", e);
        }
    }

    private Object parseJsonFrame(String raw) throws Exception {
        String text = raw != null ? raw.trim() : "";
        if (text.isEmpty()) return null;
        if (!text.startsWith("data:")) return parseJsonValue(text);

        StringBuilder payload = new StringBuilder();
        String[] lines = text.split("\\r?\\n");
        for (String line : lines) {
            String trimmed = line.trim();
            if (!trimmed.startsWith("data:")) continue;
            if (payload.length() > 0) payload.append('\n');
            payload.append(trimmed.substring("data:".length()).trim());
        }
        String value = payload.toString().trim();
        if (value.isEmpty() || "[DONE]".equals(value)) return null;
        return parseJsonValue(value);
    }

    private Object parseJsonValue(String text) throws Exception {
        String trimmed = text != null ? text.trim() : "";
        if (trimmed.startsWith("{")) return new JSONObject(trimmed);
        if (trimmed.startsWith("[")) return new JSONArray(trimmed);
        return trimmed;
    }

    private String findReminderType(Object payload) {
        if (payload instanceof JSONObject) {
            JSONObject object = (JSONObject) payload;
            String value = object.optString("reminder_type", "");
            if (isSupportedReminderType(value)) return value;

            String[] keys = new String[]{"data", "payload", "message", "body"};
            for (String key : keys) {
                Object child = object.opt(key);
                String found = findReminderType(normalizeJsonChild(child));
                if (found != null) return found;
            }
            return null;
        }

        if (payload instanceof JSONArray) {
            JSONArray array = (JSONArray) payload;
            for (int i = 0; i < array.length(); i++) {
                String found = findReminderType(normalizeJsonChild(array.opt(i)));
                if (found != null) return found;
            }
            return null;
        }

        if (payload instanceof String) {
            String text = ((String) payload).trim();
            if (isSupportedReminderType(text)) return text;
            if (text.startsWith("{") || text.startsWith("[")) {
                try {
                    return findReminderType(parseJsonValue(text));
                } catch (Exception ignored) {
                    return null;
                }
            }
        }
        return null;
    }

    private Object normalizeJsonChild(Object value) {
        return JSONObject.NULL.equals(value) ? null : value;
    }

    private boolean isSupportedReminderType(String value) {
        return "task_reminder".equals(value)
                || "lactation_feeding_reminder".equals(value)
                || "daily_summary_reminder".equals(value)
                || "milk_analysis_reminder".equals(value)
                || "baby_growth_update_reminder".equals(value)
                || "health_issue_reminder".equals(value);
    }

    private void executeReminder(String reminderType) {
        try {
            switch (reminderType) {
                case "task_reminder":
                    showReminder("任务提醒", TASK_REMINDER_MESSAGE, "/schedule?mmcNotify=1", "");
                    notifyWeb(reminderType, "task_reminder", "");
                    return;
                case "baby_growth_update_reminder": {
                    String notifyJson = new JSONObject().put("event", "grown").toString();
                    showReminder(
                            "生长发育更新提醒",
                            "建议更新一下宝宝生长数据哦～这样能更好地帮你进行奶量管理",
                            "/status?mmcNotify=growth",
                            notifyJson
                    );
                    notifyWeb(reminderType, "growth_update", notifyJson);
                    return;
                }
                case "health_issue_reminder": {
                    String message = "嗨，我发现你的乳汁电导率有点异常，可以和你聊聊吗";
                    String notifyJson = new JSONObject()
                            .put("event", "health_issue")
                            .put("body", message)
                            .put("chatMessageId", "notification-health_issue-" + System.currentTimeMillis())
                            .toString();
                    showReminder("健康问题通知", message, "/", notifyJson);
                    notifyWeb(reminderType, "health_issue", notifyJson);
                    return;
                }
                case "daily_summary_reminder":
                    executeAnalysisReminder(reminderType, "daily_summary", "每日奶量总结", "summary");
                    return;
                case "lactation_feeding_reminder":
                    executeAnalysisReminder(reminderType, "mom_baby", "每日泌乳建议", "mom_baby");
                    return;
                case "milk_analysis_reminder":
                    executeAnalysisReminder(reminderType, "milk_analysis", "奶量分析", "milk_analysis");
                    return;
                default:
                    Log.w(TAG, "unsupported reminder_type=" + reminderType);
            }
        } catch (Exception e) {
            Log.w(TAG, "execute reminder failed type=" + reminderType, e);
        }
    }

    private void executeAnalysisReminder(String reminderType, String analysisType, String title, String notifyEvent) throws Exception {
        JSONObject data = createAnalysis(analysisType);
        String message = data.optString("message", fallbackAnalysisMessage(analysisType));
        String chatMessageId = "analysis-" + analysisType + "-" + System.currentTimeMillis();
        JSONObject notifyJson = new JSONObject()
                .put("event", notifyEvent)
                .put("body", message)
                .put("chatMessageId", chatMessageId);
        JSONObject analysisCard = data.optJSONObject("analysis_card");
        if (analysisCard != null) notifyJson.put("analysis_card", analysisCard);
        JSONObject analysisContext = data.optJSONObject("analysis_context");
        if (analysisContext != null) notifyJson.put("analysis_context", analysisContext);
        String notifyJsonText = notifyJson.toString();
        showReminder(title, message, "/", notifyJsonText);
        notifyWeb(reminderType, analysisType, notifyJsonText);
    }

    private String fallbackAnalysisMessage(String analysisType) {
        if ("daily_summary".equals(analysisType)) return "已生成每日奶量总结。";
        if ("milk_analysis".equals(analysisType)) return "已生成奶量分析。";
        return "已生成每日泌乳建议。";
    }

    private JSONObject createAnalysis(String type) throws Exception {
        String base = DeviceReminderWebSocketPrefs.getApiBaseUrl(this);
        if (base == null || base.trim().isEmpty()) {
            throw new IllegalStateException("apiBaseUrl is empty");
        }
        String url = trimTrailingSlash(base) + "/v1/analysis/create";
        JSONObject bodyJson = new JSONObject()
                .put("user_id", DeviceReminderWebSocketPrefs.getUserId(this))
                .put("type", type);
        Request.Builder builder = new Request.Builder()
                .url(url)
                .post(RequestBody.create(bodyJson.toString(), JSON_MEDIA_TYPE));
        String token = DeviceReminderWebSocketPrefs.getBearerToken(this);
        if (token != null && !token.trim().isEmpty()) {
            builder.header("Authorization", "Bearer " + token.trim());
        }

        try (Response response = client.newCall(builder.build()).execute()) {
            String raw = response.body() != null ? response.body().string() : "";
            if (!response.isSuccessful()) {
                throw new IOException("HTTP " + response.code() + ": " + raw);
            }
            JSONObject root = raw != null && raw.trim().startsWith("{") ? new JSONObject(raw) : new JSONObject();
            JSONObject data = root.optJSONObject("data");
            int error = data != null && data.has("error")
                    ? data.optInt("error")
                    : root.has("error")
                    ? root.optInt("error")
                    : root.optInt("status", 0);
            String message = data != null ? data.optString("message", root.optString("message", "")) : root.optString("message", "");
            if (error != 0) throw new IOException(message.isEmpty() ? "分析请求失败" : message);
            JSONObject result = data != null ? data : root;
            if (!result.has("message") && !message.isEmpty()) result.put("message", message);
            return result;
        }
    }

    private String trimTrailingSlash(String value) {
        String text = value != null ? value.trim() : "";
        while (text.endsWith("/")) text = text.substring(0, text.length() - 1);
        return text;
    }

    private void showReminder(String title, String body, String path, String notifyJson) throws Exception {
        NotifyAlarmReceiver.ensureChannel(this);
        int alarmId = (int) (System.currentTimeMillis() & 0x3FFFFFFF);
        int nid = 41_000_000 + alarmId;

        JSONObject payload = new JSONObject()
                .put("title", title)
                .put("body", body)
                .put("path", path)
                .put("notifyJson", notifyJson != null ? notifyJson : "");
        NotifyAlarmPayloadStore.save(this, alarmId, payload.toString());

        PendingIntent fullPi = null;
        if (!MainActivity.isAppInForeground()) {
            Intent full = new Intent(this, NotifyReminderActivity.class);
            full.putExtra(NotifyReminderActivity.EXTRA_ALARM_ID, alarmId);
            full.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            fullPi = PendingIntent.getActivity(
                    this,
                    nid + 1,
                    full,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );
        }

        Intent tap = new Intent(this, MainActivity.class);
        tap.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        tap.putExtra(MainActivity.EXTRA_NAV_PATH, path);
        if (notifyJson != null && !notifyJson.isEmpty()) {
            tap.putExtra(MainActivity.EXTRA_NOTIFY_JSON, notifyJson);
        }
        tap.putExtra(MainActivity.EXTRA_NOTIFY_ALARM_CLEANUP, alarmId);
        PendingIntent tapPi = PendingIntent.getActivity(
                this,
                nid + 2,
                tap,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, NotifyAlarmReceiver.CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_pump)
                .setContentTitle(title)
                .setContentText(body.length() > 80 ? body.substring(0, 80) + "…" : body)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setAutoCancel(true)
                .setContentIntent(tapPi);
        NotificationIconHelper.applyMaiIcons(this, builder);
        if (fullPi != null) builder.setFullScreenIntent(fullPi, true);
        NotificationManagerCompat.from(this).notify(nid, builder.build());
    }

    private void notifyWeb(String reminderType, String actionKey, String notifyJson) {
        DeviceReminderWebSocketPlugin.notifyReminderHandled(reminderType, actionKey, notifyJson);
    }

    private Notification buildForegroundNotification() {
        Intent tap = new Intent(this, MainActivity.class);
        tap.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent tapPi = PendingIntent.getActivity(
                this,
                NOTIFICATION_ID,
                tap,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_pump)
                .setContentTitle("提醒监听运行中")
                .setContentText("正在接收任务、泌乳、奶量分析、每日小结与宝宝生长提醒")
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setSilent(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .setContentIntent(tapPi);
        NotificationIconHelper.applyMaiIcons(this, builder);
        return builder.build();
    }

    private static void ensureChannel(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (manager == null || manager.getNotificationChannel(CHANNEL_ID) != null) return;
        NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
        );
        channel.setDescription("WebSocket 长连接状态通知");
        channel.setShowBadge(false);
        channel.enableVibration(false);
        channel.enableLights(false);
        manager.createNotificationChannel(channel);
    }
}
