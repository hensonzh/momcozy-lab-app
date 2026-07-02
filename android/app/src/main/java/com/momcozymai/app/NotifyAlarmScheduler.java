package com.momcozymai.app;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.util.Log;

import androidx.annotation.NonNull;

import org.json.JSONArray;
import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/**
 * 注册 / 取消 notify 闹钟；使用 {@link AlarmManager#setAlarmClock} 以在后台尽量准时触发。
 */
public final class NotifyAlarmScheduler {

    private static final String TAG = "NotifyAlarmScheduler";
    private static final String PREF_IDS = "mmc_scheduled_alarm_ids";
    private static final String PREF_NEXT_REQUEST_CODE = "mmc_next_alarm_request_code";
    private static final int BASE_REQUEST_CODE = 53_000;
    private static final int MAX_REQUEST_CODE = BASE_REQUEST_CODE + 1_000_000;
    private static final long MIN_SCHEDULE_LEAD_MS = 5_000L;

    private NotifyAlarmScheduler() {
    }

    public static void cancelAll(Context ctx) {
        Set<String> ids = readIdSet(ctx);
        AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        for (String sid : ids) {
            try {
                int id = Integer.parseInt(sid);
                PendingIntent pi = buildAlarmPendingIntent(ctx, id);
                am.cancel(pi);
                pi.cancel();
                NotifyAlarmPayloadStore.remove(ctx, id);
            } catch (Exception ignored) {
            }
        }
        BackgroundNotifyPrefs.prefs(ctx).edit().remove(PREF_IDS).apply();
    }

    static void markTriggered(Context ctx, int alarmId) {
        Set<String> ids = readIdSet(ctx);
        if (ids.remove(String.valueOf(alarmId))) {
            writeIdSet(ctx, ids);
        }
    }

    private static Set<String> readIdSet(Context ctx) {
        Set<String> raw = BackgroundNotifyPrefs.prefs(ctx).getStringSet(PREF_IDS, null);
        if (raw == null) return new HashSet<>();
        return new HashSet<>(raw);
    }

    private static void writeIdSet(Context ctx, Set<String> ids) {
        BackgroundNotifyPrefs.prefs(ctx).edit().putStringSet(PREF_IDS, new HashSet<>(ids)).apply();
    }

    private static PendingIntent buildAlarmPendingIntent(Context ctx, int alarmId) {
        Intent intent = new Intent(ctx, NotifyAlarmReceiver.class);
        intent.setPackage(ctx.getPackageName());
        intent.putExtra(NotifyAlarmReceiver.EXTRA_ALARM_ID, alarmId);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        return PendingIntent.getBroadcast(ctx, alarmId, intent, flags);
    }

    private static int allocateAlarmId(Context ctx) {
        int next = BackgroundNotifyPrefs.prefs(ctx).getInt(PREF_NEXT_REQUEST_CODE, BASE_REQUEST_CODE);
        if (next < BASE_REQUEST_CODE || next > MAX_REQUEST_CODE) {
            next = BASE_REQUEST_CODE;
        }
        BackgroundNotifyPrefs.prefs(ctx).edit().putInt(PREF_NEXT_REQUEST_CODE, next + 1).apply();
        return next;
    }

    /**
     * 根据接口 data 对象（已解包）重建闹钟。
     */
    public static void rescheduleFromNotifyData(Context ctx, JSONObject data) {
        cancelAll(ctx);
        if (data == null) return;
        JSONArray list = data.optJSONArray("notify_list");
        if (list == null || list.length() == 0) {
            return;
        }
        JSONArray annotated;
        try {
            annotated = NotifyMessageResolver.annotateWithGroupIndex(list);
        } catch (Exception e) {
            Log.e(TAG, "annotate notify_list failed", e);
            return;
        }

        AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        Calendar now = Calendar.getInstance();
        Set<String> newIds = new HashSet<>();
        List<Integer> scheduled = new ArrayList<>();

        for (int i = 0; i < annotated.length(); i++) {
            JSONObject row = annotated.optJSONObject(i);
            if (row == null) continue;
            String event = NotifyMessageResolver.normalizeEvent(row.optString("event", ""));
            if (event.isEmpty()) continue;
            String timeStr = row.optString("time", "").trim();
            int groupIdx = row.optInt("_mmc_group_index", 0);
            long when;
            if ("warning".equals(event)) {
                // time = 计划任务执行时刻（当日 HH:mm）；按当前时间选择下一档 40 / 90 / 150 分钟提醒。
                when = warningNotifyAtMillis(timeStr, now);
            } else if ("pump".equals(event)) {
                // time = 下一次任务执行 HH:mm；按当前时间选择下一档提前 20 / 5 分钟提醒。
                when = pumpNotifyAtMillis(timeStr, now);
            } else {
                when = nextWallClockMillis(timeStr, now);
            }
            if (when <= System.currentTimeMillis() + MIN_SCHEDULE_LEAD_MS) {
                continue;
            }
            String apiMsg = row.optString("message", "");
            String body;
            if ("warning".equals(event)) {
                long taskMs = wallClockTodayAtMillis(timeStr, now);
                body = NotifyMessageResolver.resolveWarningBody(taskMs, when, apiMsg);
            } else if ("pump".equals(event)) {
                long taskExec = nextWallClockMillis(timeStr, now);
                body = NotifyMessageResolver.resolvePumpBody(taskExec, when, apiMsg);
            } else {
                body = NotifyMessageResolver.resolveBody(event, groupIdx, apiMsg);
            }
            String title = NotifyMessageResolver.notificationTitle(event);
            String path = NotifyMessageResolver.navPathForEvent(event);
            String notifyJson = NotifyMessageResolver.buildNotifyJsonForWeb(event, body);

            int alarmId = allocateAlarmId(ctx);
            try {
                JSONObject payload = new JSONObject();
                payload.put("title", title);
                payload.put("body", body);
                payload.put("path", path);
                payload.put("notifyJson", notifyJson);
                payload.put("event", event);
                NotifyAlarmPayloadStore.save(ctx, alarmId, payload.toString());

                PendingIntent op = buildAlarmPendingIntent(ctx, alarmId);
                PendingIntent show = PendingIntent.getActivity(
                        ctx,
                        alarmId + 77_000,
                        new Intent(ctx, MainActivity.class).setFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
                );
                AlarmManager.AlarmClockInfo info = new AlarmManager.AlarmClockInfo(when, show);
                am.setAlarmClock(info, op);
                Log.i(
                        TAG,
                        "scheduled alarm"
                                + " alarmId=" + alarmId
                                + " event=" + event
                                + " title=" + PrivacyLog.textShape(title)
                                + " executeAt=" + formatLogTime(when)
                                + " body=" + PrivacyLog.textShape(body)
                );
                newIds.add(String.valueOf(alarmId));
                scheduled.add(alarmId);
            } catch (Exception e) {
                Log.e(TAG, "schedule alarm index " + i, e);
            }
        }
        writeIdSet(ctx, newIds);
        Log.i(TAG, "scheduled " + scheduled.size() + " alarms");
    }

    private static String formatLogTime(long millis) {
        return new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(new Date(millis));
    }

    /**
     * 今日 {@code HH:mm} 的墙钟时间戳（可为过去时刻）。用于 warning 的「任务执行时间」。
     */
    static long wallClockTodayAtMillis(String hhmm, Calendar nowBase) {
        if (hhmm == null || hhmm.isEmpty()) return 0L;
        String[] p = hhmm.split(":");
        if (p.length < 2) return 0L;
        int h;
        int m;
        try {
            h = Integer.parseInt(p[0].trim());
            m = Integer.parseInt(p[1].trim().replaceAll("[^0-9].*", ""));
        } catch (NumberFormatException e) {
            return 0L;
        }
        Calendar c = (Calendar) nowBase.clone();
        c.set(Calendar.SECOND, 0);
        c.set(Calendar.MILLISECOND, 0);
        c.set(Calendar.HOUR_OF_DAY, h);
        c.set(Calendar.MINUTE, m);
        return c.getTimeInMillis();
    }

    /**
     * warning：在「任务执行时间」基础上按当前时间选择下一档 40 / 90 / 150 分钟提醒。
     */
    static long warningNotifyAtMillis(String hhmm, Calendar nowBase) {
        long task = wallClockTodayAtMillis(hhmm, nowBase);
        if (task <= 0L) return 0L;
        long minFuture = nowBase.getTimeInMillis() + MIN_SCHEDULE_LEAD_MS;
        int[] delays = {40, 90, 150};
        for (int delay : delays) {
            long candidate = task + delay * 60_000L;
            if (candidate > minFuture) {
                return candidate;
            }
        }
        return 0L;
    }

    /**
     * pump：{@code time} 为「下一次」任务执行的墙钟时刻；按当前时间选择下一档提前 20 / 5 分钟提醒。
     */
    static long pumpNotifyAtMillis(String timeStr, Calendar nowBase) {
        long taskExec = nextWallClockMillis(timeStr, nowBase);
        if (taskExec <= 0L) {
            return 0L;
        }
        long minFuture = nowBase.getTimeInMillis() + MIN_SCHEDULE_LEAD_MS;
        int[] leadMinutes = {20, 5};
        for (int lead : leadMinutes) {
            long candidate = taskExec - lead * 60_000L;
            if (candidate > minFuture) {
                return candidate;
            }
        }
        return 0L;
    }

    /**
     * 解析 HH:mm，若今天该时刻已过则取次日（用于 pump 任务时刻、summary 等到点提醒）。
     */
    static long nextWallClockMillis(String hhmm, Calendar nowBase) {
        if (hhmm == null || hhmm.isEmpty()) return 0L;
        String[] p = hhmm.split(":");
        if (p.length < 2) return 0L;
        int h;
        int m;
        try {
            h = Integer.parseInt(p[0].trim());
            m = Integer.parseInt(p[1].trim().replaceAll("[^0-9].*", ""));
        } catch (NumberFormatException e) {
            return 0L;
        }
        Calendar c = (Calendar) nowBase.clone();
        c.set(Calendar.SECOND, 0);
        c.set(Calendar.MILLISECOND, 0);
        c.set(Calendar.HOUR_OF_DAY, h);
        c.set(Calendar.MINUTE, m);
        if (c.getTimeInMillis() <= nowBase.getTimeInMillis()) {
            c.add(Calendar.DAY_OF_MONTH, 1);
        }
        return c.getTimeInMillis();
    }
}
