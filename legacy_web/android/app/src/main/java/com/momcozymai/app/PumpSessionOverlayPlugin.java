package com.momcozymai.app;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "PumpSessionOverlay")
public class PumpSessionOverlayPlugin extends Plugin {
    private static final Object SNAPSHOT_LOCK = new Object();
    private static boolean cachedActive = false;
    private static String cachedState = "running";
    private static int cachedProcessAll = 0;

    @PluginMethod
    public void canDrawOverlays(PluginCall call) {
        JSObject result = new JSObject();
        result.put("granted", canDrawOverlaysInternal());
        call.resolve(result);
    }

    @PluginMethod
    public void openOverlaySettings(PluginCall call) {
        Intent intent = new Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:" + getContext().getPackageName())
        );
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        getContext().startActivity(intent);
        call.resolve();
    }

    @PluginMethod
    public void snapshot(PluginCall call) {
        String state = call.getString("state");
        int processAll = clampProcess(call.getInt("processAll", 0));
        updateCachedSnapshot(state, processAll);
        PumpSessionNativeController.updateSession(getContext(), state, processAll);
        call.resolve();
    }

    @PluginMethod
    public void update(PluginCall call) {
        if (!canDrawOverlaysInternal()) {
            call.reject("SYSTEM_ALERT_WINDOW permission is not granted");
            return;
        }
        String state = normalizeState(call.getString("state"));
        int processAll = clampProcess(call.getInt("processAll", 0));
        updateCachedSnapshot(state, processAll);
        PumpSessionNativeController.updateSession(getContext(), state, processAll);
        PumpSessionNativeController.showOverlayIfActive(getContext());
        call.resolve();
    }

    @PluginMethod
    public void hide(PluginCall call) {
        PumpSessionNativeController.hideOverlayOnly(getContext());
        call.resolve();
    }

    public static void showCachedOverlayIfActive(Context context) {
        if (!canDrawOverlays(context)) return;

        String state;
        int processAll;
        synchronized (SNAPSHOT_LOCK) {
            if (!cachedActive) return;
            state = cachedState;
            processAll = cachedProcessAll;
        }
        PumpSessionNativeController.showOverlayIfActive(context);
    }

    private boolean canDrawOverlaysInternal() {
        return canDrawOverlays(getContext());
    }

    private static boolean canDrawOverlays(Context context) {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context);
    }

    private static void updateCachedSnapshot(String state, int processAll) {
        synchronized (SNAPSHOT_LOCK) {
            cachedActive = "running".equals(state) || "paused".equals(state);
            cachedState = normalizeState(state);
            cachedProcessAll = clampProcess(processAll);
        }
    }

    private static void startOverlayService(Context context, String state, int processAll) {
        Intent intent = new Intent(context, PumpSessionOverlayService.class);
        intent.setAction(PumpSessionOverlayService.ACTION_UPDATE);
        intent.putExtra(PumpSessionOverlayService.EXTRA_STATE, normalizeState(state));
        intent.putExtra(PumpSessionOverlayService.EXTRA_PROCESS_ALL, clampProcess(processAll));
        context.startService(intent);
    }

    private static String normalizeState(String state) {
        if ("running".equals(state) || "paused".equals(state)) {
            return state;
        }
        return "running";
    }

    private static int clampProcess(int processAll) {
        if (processAll < 0) return 0;
        return Math.min(processAll, 100);
    }
}
