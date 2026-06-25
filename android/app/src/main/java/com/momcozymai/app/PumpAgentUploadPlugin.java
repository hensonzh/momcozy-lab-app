package com.momcozymai.app;

import android.content.Context;
import android.util.Log;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import org.json.JSONObject;

@CapacitorPlugin(name = "PumpAgentUpload")
public class PumpAgentUploadPlugin extends Plugin {
    private static final String TAG = "PumpAgentUpload";
    private static PumpAgentUploadPlugin instance;

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
    public void setConfig(PluginCall call) {
        String base = call.getString("apiBaseUrl", "");
        String token = call.getString("bearerToken", "");
        String userId = call.getString("userId", "");
        BackgroundNotifyPrefs.setConfig(getContext(), base, token, userId);
        call.resolve();
    }

    @PluginMethod
    public void sampleFromSnapshot(PluginCall call) {
        PumpAgentNativeStore.sampleFromSnapshot();
        PumpSessionNativeController.tickElapsedFromNative();
        call.resolve(progressResult());
    }

    @PluginMethod
    public void resetProgress(PluginCall call) {
        PumpAgentNativeStore.resetProgress();
        call.resolve(progressResult());
    }

    @PluginMethod
    public void markStepStop(PluginCall call) {
        PumpAgentNativeStore.markStepStop(call.getString("side", "both"));
        call.resolve();
    }

    @PluginMethod
    public void markStepPause(PluginCall call) {
        PumpAgentNativeStore.markStepPause(call.getString("side", "both"));
        call.resolve();
    }

    @PluginMethod
    public void setOperationSource(PluginCall call) {
        PumpAgentNativeStore.setOperationSource(
                call.getString("side", "both"),
                call.getString("source", "device")
        );
        call.resolve();
    }

    @PluginMethod
    public void uploadWorkstate(PluginCall call) {
        runAsync(call, () -> {
            Context ctx = getContext().getApplicationContext();
            JSONObject body = PumpAgentNativeStore.buildWorkstateBody(resolveUserId(ctx, call));
            JSONObject data = PumpAgentApiClient.post(
                    BackgroundNotifyPrefs.getApiBaseUrl(ctx),
                    BackgroundNotifyPrefs.getBearerToken(ctx),
                    "/v1/pump/workstate",
                    body
            );
            JSObject ret = new JSObject();
            ret.put("body", body);
            ret.put("response", data);
            return ret;
        });
    }

    @PluginMethod
    public void getProcessData(PluginCall call) {
        runAsync(call, () -> {
            Context ctx = getContext().getApplicationContext();
            JSONObject body = PumpAgentNativeStore.buildProcessDataBody(resolveUserId(ctx, call));
            Log.i(TAG, "get pump process data request body=" + body);
            JSONObject data = PumpAgentApiClient.post(
                    BackgroundNotifyPrefs.getApiBaseUrl(ctx),
                    BackgroundNotifyPrefs.getBearerToken(ctx),
                    "/v1/pump/process/data",
                    body
            );
            PumpAgentNativeStore.applyProcessDataResponse(data, body);
            JSObject ret = progressResult();
            ret.put("body", body);
            ret.put("response", data);
            return ret;
        });
    }

    @PluginMethod
    public void uploadProcess(PluginCall call) {
        runAsync(call, () -> {
            Context ctx = getContext().getApplicationContext();
            JSONObject body = PumpAgentNativeStore.buildProcessBody(resolveUserId(ctx, call));
            Log.i(TAG, "upload pump process request body=" + body);
            JSONObject data = PumpAgentApiClient.post(
                    BackgroundNotifyPrefs.getApiBaseUrl(ctx),
                    BackgroundNotifyPrefs.getBearerToken(ctx),
                    "/v1/pump/process",
                    body
            );
            JSObject ret = new JSObject();
            ret.put("body", body);
            ret.put("response", data);
            return ret;
        });
    }

    @PluginMethod
    public void uploadMilkRecord(PluginCall call) {
        runAsync(call, () -> {
            Context ctx = getContext().getApplicationContext();
            long endedAt = Math.round(call.getDouble("endedAtMs", (double) System.currentTimeMillis()));
            JSONObject body = PumpAgentNativeStore.buildMilkUploadBody(resolveUserId(ctx, call), endedAt);
            JSONObject data = PumpAgentApiClient.post(
                    BackgroundNotifyPrefs.getApiBaseUrl(ctx),
                    BackgroundNotifyPrefs.getBearerToken(ctx),
                    "/v1/pump-milk/upload",
                    body
            );
            JSObject ret = new JSObject();
            ret.put("body", body);
            ret.put("response", data);
            return ret;
        });
    }

    private String resolveUserId(Context ctx, PluginCall call) {
        String fromCall = call.getString("userId", "");
        if (fromCall != null && !fromCall.trim().isEmpty()) return fromCall.trim();
        return BackgroundNotifyPrefs.getUserId(ctx);
    }

    private JSObject progressResult() {
        JSObject ret = new JSObject();
        try {
            JSONObject progress = PumpAgentNativeStore.progressJson();
            ret.put("processL", progress.optInt("processL", 0));
            ret.put("processR", progress.optInt("processR", 0));
            ret.put("processAll", progress.optInt("processAll", 0));
            ret.put("elapsedSeconds", PumpSessionNativeController.currentElapsedSeconds());
        } catch (Exception ignored) {
            ret.put("processL", 0);
            ret.put("processR", 0);
            ret.put("processAll", 0);
            ret.put("elapsedSeconds", 0);
        }
        return ret;
    }

    static void emitNativeProcessProgress(JSONObject progress) {
        PumpAgentUploadPlugin plugin = instance;
        if (plugin == null) return;
        JSObject ret = new JSObject();
        ret.put("processL", progress.optInt("processL", 0));
        ret.put("processR", progress.optInt("processR", 0));
        ret.put("processAll", progress.optInt("processAll", 0));
        if (progress.has("elapsedSeconds")) {
            ret.put("elapsedSeconds", progress.optInt("elapsedSeconds", 0));
        }
        plugin.notifyListeners("nativeProcessProgress", ret);
    }

    static void emitNativeProcessReply(JSONObject response) {
        PumpAgentUploadPlugin plugin = instance;
        if (plugin == null) return;
        JSObject ret = new JSObject();
        ret.put("response", response);
        plugin.notifyListeners("nativeProcessReply", ret);
    }

    private interface Task {
        JSObject run() throws Exception;
    }

    private void runAsync(PluginCall call, Task task) {
        new Thread(() -> {
            try {
                call.resolve(task.run());
            } catch (Exception e) {
                Log.e(TAG, "native pump upload failed", e);
                call.reject(e.getMessage() != null ? e.getMessage() : "native pump upload failed", e);
            }
        }, "PumpAgentUpload").start();
    }
}
