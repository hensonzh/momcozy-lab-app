package com.momcozymai.app;

import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.provider.Settings;

import androidx.core.content.ContextCompat;

final class PumpSessionNativeController {
    private static final Object LOCK = new Object();
    private static final long WAKE_LOCK_MS = 60_000L;
    private static boolean active;
    private static boolean appForeground = true;
    private static String state = "idle";
    private static int processAll;
    private static int elapsedSeconds;
    private static long lastElapsedTickMs;

    private PumpSessionNativeController() {
    }

    static void updateSession(Context context, String nextState, int nextProcessAll) {
        Context app = context.getApplicationContext();
        String normalizedState = normalizeState(nextState);
        int normalizedProcess = clampProcess(nextProcessAll);
        long now = System.currentTimeMillis();
        synchronized (LOCK) {
            boolean wasActive = active;
            state = normalizedState;
            processAll = normalizedProcess;
            active = isActiveState(normalizedState);
            if (active && !wasActive) {
                elapsedSeconds = Math.max(elapsedSeconds, DeviceNativeStateStore.maxRunningDurationSeconds());
                lastElapsedTickMs = now;
            } else if (!"running".equals(normalizedState)) {
                lastElapsedTickMs = now;
            }
        }
        if (!isActiveState(normalizedState)) {
            stopAll(app);
            return;
        }
        startForegroundNotification(app, normalizedState, normalizedProcess);
        syncOverlayAndBackgroundSideEffects(app);
    }

    static void stopAll(Context context) {
        Context app = context.getApplicationContext();
        synchronized (LOCK) {
            active = false;
            state = "idle";
            processAll = 0;
            elapsedSeconds = 0;
            lastElapsedTickMs = 0;
        }
        stopForegroundNotification(app);
        hideOverlay(app);
        PumpSessionKeepAlivePlugin.releaseWakeLock();
    }

    static int tickElapsedFromNative() {
        long now = System.currentTimeMillis();
        boolean anyRunning = DeviceNativeStateStore.hasAnyRunningDevice();
        int protocolDuration = DeviceNativeStateStore.maxRunningDurationSeconds();
        synchronized (LOCK) {
            if (!active) {
                lastElapsedTickMs = now;
                return elapsedSeconds;
            }
            if (protocolDuration > elapsedSeconds) {
                elapsedSeconds = protocolDuration;
            }
            if ("running".equals(state) && anyRunning) {
                if (lastElapsedTickMs <= 0) lastElapsedTickMs = now;
                long deltaSeconds = Math.max(0, (now - lastElapsedTickMs) / 1000L);
                if (deltaSeconds > 0) {
                    elapsedSeconds = clampElapsed(elapsedSeconds + deltaSeconds);
                    lastElapsedTickMs += deltaSeconds * 1000L;
                }
            } else {
                lastElapsedTickMs = now;
            }
            return elapsedSeconds;
        }
    }

    static int currentElapsedSeconds() {
        synchronized (LOCK) {
            return elapsedSeconds;
        }
    }

    static void updateProcessFromNative(Context context, int nextProcessAll) {
        Context app = context.getApplicationContext();
        String snapshotState;
        int snapshotProcess;
        boolean snapshotActive;
        boolean foreground;
        synchronized (LOCK) {
            processAll = clampProcess(nextProcessAll);
            snapshotActive = active;
            snapshotState = state;
            snapshotProcess = processAll;
            foreground = appForeground;
        }
        if (!snapshotActive) return;
        if (!foreground && canDrawOverlays(app)) {
            startOverlay(app, snapshotState, snapshotProcess);
        }
    }

    static void onAppForegroundChanged(Context context, boolean foreground) {
        synchronized (LOCK) {
            appForeground = foreground;
        }
        syncOverlayAndBackgroundSideEffects(context.getApplicationContext());
    }

    static void showOverlayIfActive(Context context) {
        Context app = context.getApplicationContext();
        String snapshotState;
        int snapshotProcess;
        boolean snapshotActive;
        synchronized (LOCK) {
            snapshotActive = active;
            snapshotState = state;
            snapshotProcess = processAll;
        }
        if (!snapshotActive || !canDrawOverlays(app)) return;
        startOverlay(app, snapshotState, snapshotProcess);
    }

    static void hideOverlayOnly(Context context) {
        hideOverlay(context.getApplicationContext());
    }

    private static void syncOverlayAndBackgroundSideEffects(Context context) {
        String snapshotState;
        int snapshotProcess;
        boolean snapshotActive;
        boolean foreground;
        synchronized (LOCK) {
            snapshotActive = active;
            snapshotState = state;
            snapshotProcess = processAll;
            foreground = appForeground;
        }
        if (!snapshotActive) {
            hideOverlay(context);
            PumpSessionKeepAlivePlugin.releaseWakeLock();
            return;
        }
        if (foreground) {
            PumpSessionKeepAlivePlugin.releaseWakeLock();
            return;
        }
        if (canDrawOverlays(context)) {
            startOverlay(context, snapshotState, snapshotProcess);
        }
        PumpSessionKeepAlivePlugin.acquireWakeLock(context, WAKE_LOCK_MS);
    }

    private static void startForegroundNotification(Context context, String state, int processAll) {
        Intent intent = new Intent(context, PumpSessionForegroundService.class);
        intent.setAction(PumpSessionForegroundService.ACTION_START_OR_UPDATE);
        intent.putExtra(PumpSessionForegroundService.EXTRA_STATE, normalizeState(state));
        intent.putExtra(PumpSessionForegroundService.EXTRA_PROCESS_ALL, clampProcess(processAll));
        ContextCompat.startForegroundService(context, intent);
    }

    private static void stopForegroundNotification(Context context) {
        Intent intent = new Intent(context, PumpSessionForegroundService.class);
        intent.setAction(PumpSessionForegroundService.ACTION_STOP);
        context.startService(intent);
    }

    private static void startOverlay(Context context, String state, int processAll) {
        Intent intent = new Intent(context, PumpSessionOverlayService.class);
        intent.setAction(PumpSessionOverlayService.ACTION_UPDATE);
        intent.putExtra(PumpSessionOverlayService.EXTRA_STATE, normalizeState(state));
        intent.putExtra(PumpSessionOverlayService.EXTRA_PROCESS_ALL, clampProcess(processAll));
        context.startService(intent);
    }

    private static void hideOverlay(Context context) {
        Intent intent = new Intent(context, PumpSessionOverlayService.class);
        intent.setAction(PumpSessionOverlayService.ACTION_HIDE);
        context.startService(intent);
    }

    private static boolean canDrawOverlays(Context context) {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context);
    }

    private static boolean isActiveState(String state) {
        return "running".equals(state) || "paused".equals(state);
    }

    private static String normalizeState(String state) {
        if ("running".equals(state) || "paused".equals(state)) return state;
        return "idle";
    }

    private static int clampProcess(int processAll) {
        if (processAll < 0) return 0;
        return Math.min(processAll, 100);
    }

    private static int clampElapsed(long seconds) {
        if (seconds < 0) return 0;
        return seconds > Integer.MAX_VALUE ? Integer.MAX_VALUE : (int) seconds;
    }
}
