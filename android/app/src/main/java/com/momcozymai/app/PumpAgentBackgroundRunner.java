package com.momcozymai.app;

import android.content.Context;
import android.util.Log;

import org.json.JSONObject;

final class PumpAgentBackgroundRunner {
    interface Listener {
        void onProgress(int processAll);
    }

    private static final String TAG = "PumpAgentBgRunner";
    private static final long PROCESS_DATA_INTERVAL_MS = 1_000L;
    private static final long PROCESS_UPLOAD_INTERVAL_MS = 10_000L;

    private static final Object LOCK = new Object();
    private static boolean running;
    private static Thread worker;
    private static String workstateSignature = "";
    private static long lastProcessUploadAt;
    private static Listener listener;

    private PumpAgentBackgroundRunner() {
    }

    static void start(Context context, Listener nextListener) {
        final Context app = context.getApplicationContext();
        synchronized (LOCK) {
            listener = nextListener;
            if (running) return;
            running = true;
            worker = new Thread(() -> runLoop(app), "PumpAgentBgRunner");
            worker.start();
        }
    }

    static void stop() {
        Thread toJoin;
        synchronized (LOCK) {
            running = false;
            listener = null;
            toJoin = worker;
            worker = null;
        }
        if (toJoin != null) {
            toJoin.interrupt();
        }
    }

    private static void runLoop(Context context) {
        Log.i(TAG, "background pump agent loop started");
        while (isRunning()) {
            long startedAt = System.currentTimeMillis();
            try {
                tick(context);
            } catch (Exception e) {
                Log.w(TAG, "background pump agent tick failed", e);
            }
            long elapsed = System.currentTimeMillis() - startedAt;
            long sleepMs = Math.max(100L, PROCESS_DATA_INTERVAL_MS - elapsed);
            try {
                Thread.sleep(sleepMs);
            } catch (InterruptedException ignored) {
                Thread.currentThread().interrupt();
            }
        }
        Log.i(TAG, "background pump agent loop stopped");
    }

    private static boolean isRunning() {
        synchronized (LOCK) {
            return running;
        }
    }

    private static void tick(Context context) throws Exception {
        PumpAgentNativeStore.sampleFromSnapshot();
        uploadWorkstateIfChanged(context);
        fetchProcessDataIfNeeded(context);
        uploadProcessIfNeeded(context);
    }

    private static void uploadWorkstateIfChanged(Context context) throws Exception {
        if (!PumpAgentNativeStore.hasAnyDeviceConnected()) return;
        String nextSignature = PumpAgentNativeStore.workstateSignature();
        if (nextSignature.equals(workstateSignature)) return;
        JSONObject body = PumpAgentNativeStore.buildWorkstateBody(BackgroundNotifyPrefs.getUserId(context));
        PumpAgentApiClient.post(
                BackgroundNotifyPrefs.getApiBaseUrl(context),
                BackgroundNotifyPrefs.getBearerToken(context),
                "/v1/pump/workstate",
                body
        );
        workstateSignature = nextSignature;
    }

    private static void fetchProcessDataIfNeeded(Context context) throws Exception {
        if (!PumpAgentNativeStore.shouldFetchProcessData()) return;
        JSONObject body = PumpAgentNativeStore.buildProcessDataBody(BackgroundNotifyPrefs.getUserId(context));
        JSONObject data = PumpAgentApiClient.post(
                BackgroundNotifyPrefs.getApiBaseUrl(context),
                BackgroundNotifyPrefs.getBearerToken(context),
                "/v1/pump/process/data",
                body
        );
        PumpAgentNativeStore.applyProcessDataResponse(data, body);
        JSONObject progress = PumpAgentNativeStore.progressJson();
        int processAll = progress.optInt("processAll", 0);
        PumpAgentUploadPlugin.emitNativeProcessProgress(progress);
        Listener current;
        synchronized (LOCK) {
            current = listener;
        }
        if (current != null) current.onProgress(processAll);
    }

    private static void uploadProcessIfNeeded(Context context) throws Exception {
        if (!PumpAgentNativeStore.hasAnyDeviceConnected()) return;
        long now = System.currentTimeMillis();
        if (now - lastProcessUploadAt < PROCESS_UPLOAD_INTERVAL_MS) return;
        lastProcessUploadAt = now;
        JSONObject body = PumpAgentNativeStore.buildProcessBody(BackgroundNotifyPrefs.getUserId(context));
        JSONObject data = PumpAgentApiClient.post(
                BackgroundNotifyPrefs.getApiBaseUrl(context),
                BackgroundNotifyPrefs.getBearerToken(context),
                "/v1/pump/process",
                body
        );
        PumpAgentUploadPlugin.emitNativeProcessReply(data);
    }
}
