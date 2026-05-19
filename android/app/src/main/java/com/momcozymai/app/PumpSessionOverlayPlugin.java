package com.momcozymai.app;

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
    public void update(PluginCall call) {
        if (!canDrawOverlaysInternal()) {
            call.reject("SYSTEM_ALERT_WINDOW permission is not granted");
            return;
        }
        String state = normalizeState(call.getString("state"));
        int processAll = clampProcess(call.getInt("processAll", 0));
        Intent intent = new Intent(getContext(), PumpSessionOverlayService.class);
        intent.setAction(PumpSessionOverlayService.ACTION_UPDATE);
        intent.putExtra(PumpSessionOverlayService.EXTRA_STATE, state);
        intent.putExtra(PumpSessionOverlayService.EXTRA_PROCESS_ALL, processAll);
        getContext().startService(intent);
        call.resolve();
    }

    @PluginMethod
    public void hide(PluginCall call) {
        Intent intent = new Intent(getContext(), PumpSessionOverlayService.class);
        intent.setAction(PumpSessionOverlayService.ACTION_HIDE);
        getContext().startService(intent);
        call.resolve();
    }

    private boolean canDrawOverlaysInternal() {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(getContext());
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
