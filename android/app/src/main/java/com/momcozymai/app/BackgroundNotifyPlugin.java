package com.momcozymai.app;

import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.app.PendingIntent;
import android.os.Build;
import android.os.PowerManager;
import android.provider.Settings;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.content.ContextCompat;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "BackgroundNotify")
public class BackgroundNotifyPlugin extends Plugin {

    @PluginMethod
    public void setConfig(PluginCall call) {
        String base = call.getString("apiBaseUrl", "");
        String token = call.getString("bearerToken", "");
        String userId = call.getString("userId", "");
        BackgroundNotifyPrefs.setConfig(getContext(), base, token, userId);
        call.resolve();
    }

    @PluginMethod
    public void setEnabled(PluginCall call) {
        boolean enabled = call.getBoolean("enabled", false);
        Context ctx = getContext().getApplicationContext();
        BackgroundNotifyPrefs.setEnabled(ctx, enabled);
        if (enabled) {
            NotifyWorkScheduler.enqueuePeriodic(ctx);
            NotifyWorkScheduler.enqueueOneShot(ctx);
        } else {
            NotifyWorkScheduler.cancelPeriodic(ctx);
            NotifyAlarmScheduler.cancelAll(ctx);
            NotifyPeriodicSyncNotifier.cancelShown(ctx);
        }
        call.resolve();
    }

    @PluginMethod
    public void isEnabled(PluginCall call) {
        JSObject ret = new JSObject();
        ret.put("enabled", BackgroundNotifyPrefs.isEnabled(getContext()));
        call.resolve(ret);
    }

    @PluginMethod
    public void syncNow(PluginCall call) {
        NotifyWorkScheduler.enqueueOneShot(getContext().getApplicationContext());
        call.resolve();
    }

    @PluginMethod
    public void showReminder(PluginCall call) {
        String title = call.getString("title", "提醒");
        String body = call.getString("body", "");
        String path = call.getString("path", "/");
        String notifyJson = call.getString("notifyJson", "");
        Context context = getContext().getApplicationContext();
        if (Build.VERSION.SDK_INT >= 33) {
            if (ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS)
                    != PackageManager.PERMISSION_GRANTED) {
                call.reject("POST_NOTIFICATIONS not granted");
                return;
            }
        }
        try {
            NotifyAlarmReceiver.ensureChannel(context);
            int alarmId = (int) (System.currentTimeMillis() & 0x3FFFFFFF);
            int nid = 41_000_000 + alarmId;

            JSObject payload = new JSObject();
            payload.put("title", title);
            payload.put("body", body);
            payload.put("path", path);
            payload.put("notifyJson", notifyJson);
            NotifyAlarmPayloadStore.save(context, alarmId, payload.toString());

            PendingIntent fullPi = null;
            if (!MainActivity.isAppInForeground()) {
                Intent full = new Intent(context, NotifyReminderActivity.class);
                full.putExtra(NotifyReminderActivity.EXTRA_ALARM_ID, alarmId);
                full.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                fullPi = PendingIntent.getActivity(
                        context,
                        nid + 1,
                        full,
                        PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
                );
            }

            Intent tap = new Intent(context, MainActivity.class);
            tap.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            tap.putExtra(MainActivity.EXTRA_NAV_PATH, path);
            if (notifyJson != null && !notifyJson.isEmpty()) {
                tap.putExtra(MainActivity.EXTRA_NOTIFY_JSON, notifyJson);
            }
            tap.putExtra(MainActivity.EXTRA_NOTIFY_ALARM_CLEANUP, alarmId);
            PendingIntent tapPi = PendingIntent.getActivity(
                    context,
                    nid + 2,
                    tap,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );

            NotificationCompat.Builder b = new NotificationCompat.Builder(context, NotifyAlarmReceiver.CHANNEL_ID)
                    .setSmallIcon(R.drawable.ic_stat_pump)
                    .setContentTitle(title)
                    .setContentText(body.length() > 80 ? body.substring(0, 80) + "…" : body)
                    .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .setAutoCancel(true)
                    .setContentIntent(tapPi);
            NotificationIconHelper.applyMaiIcons(context, b);
            if (fullPi != null) {
                b.setFullScreenIntent(fullPi, true);
            }
            NotificationManagerCompat.from(context).notify(nid, b.build());
            call.resolve();
        } catch (Exception e) {
            call.reject("showReminder failed", e);
        }
    }

    @PluginMethod
    public void openExactAlarmSettings(PluginCall call) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Intent i = new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM);
            i.setData(Uri.parse("package:" + getContext().getPackageName()));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
        }
        call.resolve();
    }

    @PluginMethod
    public void openOverlaySettings(PluginCall call) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Intent i = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:" + getContext().getPackageName()));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
        }
        call.resolve();
    }

    @PluginMethod
    public void openBatteryOptimizationSettings(PluginCall call) {
        Intent i = new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        getContext().startActivity(i);
        call.resolve();
    }

    @PluginMethod
    public void openAppNotificationSettings(PluginCall call) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent i = new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS);
            i.putExtra(Settings.EXTRA_APP_PACKAGE, getContext().getPackageName());
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
        } else {
            Intent i = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
            i.setData(Uri.parse("package:" + getContext().getPackageName()));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
        }
        call.resolve();
    }

    @PluginMethod
    public void isIgnoringBatteryOptimizations(PluginCall call) {
        boolean ok = true;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PowerManager pm = (PowerManager) getContext().getSystemService(Context.POWER_SERVICE);
            ok = pm != null && pm.isIgnoringBatteryOptimizations(getContext().getPackageName());
        }
        JSObject r = new JSObject();
        r.put("ignoring", ok);
        call.resolve(r);
    }

    @PluginMethod
    public void canDrawOverlays(PluginCall call) {
        boolean ok = true;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            ok = Settings.canDrawOverlays(getContext());
        }
        JSObject r = new JSObject();
        r.put("granted", ok);
        call.resolve(r);
    }

    @PluginMethod
    public void canScheduleExactAlarms(PluginCall call) {
        boolean ok = true;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            android.app.AlarmManager am = (android.app.AlarmManager) getContext().getSystemService(Context.ALARM_SERVICE);
            ok = am != null && am.canScheduleExactAlarms();
        }
        JSObject r = new JSObject();
        r.put("granted", ok);
        call.resolve(r);
    }
}
