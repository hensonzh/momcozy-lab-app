package com.momcozymai.app;

import android.content.Context;
import android.os.PowerManager;
import android.util.Log;

import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "PumpSessionKeepAlive")
public class PumpSessionKeepAlivePlugin extends Plugin {
    private static final String TAG = "PumpSessionKeepAlive";
    private static final String WAKE_LOCK_TAG = "Momcozy:PumpSession";
    private static final long MAX_WAKE_LOCK_MS = 60_000L;
    private static PowerManager.WakeLock wakeLock;

    @PluginMethod
    public void acquire(PluginCall call) {
        final long requestedMs = call.getLong("timeoutMs", MAX_WAKE_LOCK_MS);
        final long timeoutMs = clampTimeout(requestedMs);
        acquireWakeLock(getContext().getApplicationContext(), timeoutMs);
        call.resolve();
    }

    @PluginMethod
    public void release(PluginCall call) {
        releaseWakeLock();
        call.resolve();
    }

    private static synchronized void acquireWakeLock(Context context, long timeoutMs) {
        releaseWakeLock();
        final PowerManager powerManager = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
        if (powerManager == null) {
            Log.w(TAG, "PowerManager unavailable; skip wake lock");
            return;
        }
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG);
        wakeLock.setReferenceCounted(false);
        wakeLock.acquire(timeoutMs);
        Log.i(TAG, "acquired partial wake lock for " + timeoutMs + "ms");
    }

    private static synchronized void releaseWakeLock() {
        if (wakeLock == null) return;
        try {
            if (wakeLock.isHeld()) {
                wakeLock.release();
                Log.i(TAG, "released partial wake lock");
            }
        } catch (RuntimeException e) {
            Log.w(TAG, "release wake lock failed", e);
        } finally {
            wakeLock = null;
        }
    }

    private static long clampTimeout(long timeoutMs) {
        if (timeoutMs <= 0L) return MAX_WAKE_LOCK_MS;
        return Math.min(timeoutMs, MAX_WAKE_LOCK_MS);
    }
}
