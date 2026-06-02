package com.momcozymai.app;

import android.content.Context;
import android.content.Intent;

import androidx.core.content.ContextCompat;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "DeviceReminderWebSocket")
public class DeviceReminderWebSocketPlugin extends Plugin {
    private static DeviceReminderWebSocketPlugin instance;

    @Override
    public void load() {
        instance = this;
    }

    @Override
    protected void handleOnDestroy() {
        if (instance == this) instance = null;
        super.handleOnDestroy();
    }

    @PluginMethod
    public void start(PluginCall call) {
        Context context = getContext().getApplicationContext();
        DeviceReminderWebSocketPrefs.setConfig(
                context,
                call.getString("wsUrl", DeviceReminderWebSocketPrefs.DEFAULT_WS_URL),
                call.getString("apiBaseUrl", ""),
                call.getString("bearerToken", ""),
                call.getString("userId", DeviceReminderWebSocketPrefs.DEFAULT_USER_ID)
        );
        DeviceReminderWebSocketPrefs.setEnabled(context, true);
        Intent intent = new Intent(context, DeviceReminderWebSocketService.class);
        intent.setAction(DeviceReminderWebSocketService.ACTION_START);
        ContextCompat.startForegroundService(context, intent);
        call.resolve();
    }

    @PluginMethod
    public void stop(PluginCall call) {
        Context context = getContext().getApplicationContext();
        DeviceReminderWebSocketPrefs.setEnabled(context, false);
        Intent intent = new Intent(context, DeviceReminderWebSocketService.class);
        intent.setAction(DeviceReminderWebSocketService.ACTION_STOP);
        context.startService(intent);
        call.resolve();
    }

    public static void notifyReminderHandled(String reminderType, String actionKey, String notifyJson) {
        DeviceReminderWebSocketPlugin plugin = instance;
        if (plugin == null) return;
        JSObject data = new JSObject();
        data.put("reminderType", reminderType);
        data.put("actionKey", actionKey);
        data.put("notifyJson", notifyJson != null ? notifyJson : "");
        plugin.notifyListeners("deviceReminderHandled", data);
    }
}
