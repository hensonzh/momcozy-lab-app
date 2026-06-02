package com.momcozymai.app;

import android.Manifest;
import android.os.Build;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "PumpSessionNotification")
public class PumpSessionNotificationPlugin extends Plugin {

    /**
     * 供 Web 读取：通知 / Intent 拉起时写入的一条待跳转路径。
     */
    @PluginMethod
    public void consumePendingNavigate(PluginCall call) {
        final PumpNavigationBridge.PendingNavigate n = PumpNavigationBridge.consumePendingNavigate();
        final JSObject ret = new JSObject();
        ret.put("path", n.path);
        ret.put("autoEndTeardown", n.autoEndTeardown);
        ret.put("notifyJson", n.notifyJson);
        call.resolve(ret);
    }

    @PluginMethod
    public void start(PluginCall call) {
        String state = normalizeState(call.getString("state"));
        int processAll = clampProcess(call.getInt("processAll", 0));
        PumpSessionNativeController.updateSession(getContext(), state, processAll);
        call.resolve();
    }

    @PluginMethod
    public void update(PluginCall call) {
        start(call);
    }

    @PluginMethod
    public void stop(PluginCall call) {
        PumpSessionNativeController.stopAll(getContext());
        call.resolve();
    }

    /**
     * 进度达 100% 且用户不在吸乳页：一条可清除的本地消息，点击进 /pump（与前台进度通知独立）。
     */
    @PluginMethod
    public void showCompletionNotice(PluginCall call) {
        PumpCompletionNotice.show(getContext());
        call.resolve();
    }

    /**
     * 自动结束吸乳且用户不在吸乳页：可清除消息，点击进智能体主页并可触发 Web 收尾（小结 + BLE）。
     */
    @PluginMethod
    public void showAutoEndNotice(PluginCall call) {
        final String title = call.getString("title", "");
        final String body = call.getString("body", "");
        final String path = call.getString("path", "/");
        final boolean autoEndTeardown = call.getBoolean("autoEndTeardown", true);
        PumpAutoEndNotice.show(getContext(), title, body, path, autoEndTeardown);
        call.resolve();
    }

    @PluginMethod
    public void requestPermission(PluginCall call) {
        JSObject result = new JSObject();
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.put("granted", true);
            call.resolve(result);
            return;
        }
        boolean granted = getContext().checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                == android.content.pm.PackageManager.PERMISSION_GRANTED;
        result.put("granted", granted);
        call.resolve(result);
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
