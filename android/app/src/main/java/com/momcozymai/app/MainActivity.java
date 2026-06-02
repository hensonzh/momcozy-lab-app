package com.momcozymai.app;

import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.webkit.WebView;

import com.getcapacitor.Bridge;
import com.getcapacitor.BridgeActivity;

import androidx.activity.OnBackPressedCallback;

/**
 * 点击携带 EXTRA_NAV_PATH 的通知时，在 onNewIntent 写入待消费路由。
 * 前台时下拉通知再点击不会触发 Web 端 visibility/focus，故用 evaluateJavascript 触发一次导航消费。
 */
public class MainActivity extends BridgeActivity {

    /** 额外路径，供通知 PendingIntent 跳转到 Web 路由（React Router pathname）。 */
    public static final String EXTRA_NAV_PATH = "com.momcozymai.app.EXTRA_NAV_PATH";
    /** 为 true 时 Web 消费导航后需执行吸乳自动结束收尾（小结 + BLE 停泵）。 */
    public static final String EXTRA_AUTO_END_TEARDOWN = "com.momcozymai.app.EXTRA_AUTO_END_TEARDOWN";
    /** 可选 JSON 字符串，供 Web 展示后台提醒（如每日小结）。 */
    public static final String EXTRA_NOTIFY_JSON = "com.momcozymai.app.EXTRA_NOTIFY_JSON";
    /** 点击通知清理闹钟 payload 缓存（值为 alarmId int）。 */
    public static final String EXTRA_NOTIFY_ALARM_CLEANUP = "com.momcozymai.app.EXTRA_NOTIFY_ALARM_CLEANUP";

    /** 与 Web 端 PumpNotificationNavigateSync 中 window 事件名一致 */
    private static final String JS_NOTIFY =
            "window.dispatchEvent(new Event(\"mmc-pump-native-nav\")); void 0;";

    private static volatile boolean appInForeground;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private int notifyAttempts;

    public static boolean isAppInForeground() {
        return appInForeground;
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(PumpSessionNotificationPlugin.class);
        registerPlugin(PumpSessionOverlayPlugin.class);
        registerPlugin(PumpSessionKeepAlivePlugin.class);
        registerPlugin(BackgroundNotifyPlugin.class);
        registerPlugin(DeviceReminderWebSocketPlugin.class);
        super.onCreate(savedInstanceState);
        // PumpNotificationChannels.registerAll(this);
        /** 进程内首次创建：仅输出 WorkManager 周期任务状态日志，不在此刷新/入队周期任务。 */
        if (savedInstanceState == null) {
            NotifyWorkScheduler.logPeriodicWorkStatus(getApplicationContext(), "MainActivity.onCreate_start");
            if (!BackgroundNotifyPrefs.isEnabled(getApplicationContext())) {
                android.util.Log.i(
                        "MmcNotifyPeriodicWM",
                        "[MainActivity.onCreate] background_notify disabled (enqueuePeriodic 仍仅在 setEnabled 等路径注册)"
                );
            }
            mainHandler.postDelayed(
                    () -> NotifyWorkScheduler.logPeriodicWorkStatus(
                            getApplicationContext(),
                            "MainActivity.onCreate_delayed_2s"
                    ),
                    2000L
            );
        }
        handleLaunchNavigationIntent(getIntent());
        disableInAppSystemBack();
    }

    @Override
    public void onResume() {
        super.onResume();
        appInForeground = true;
    }

    @Override
    public void onPause() {
        appInForeground = false;
        super.onPause();
    }

    @Override
    protected void onUserLeaveHint() {
        PumpSessionOverlayPlugin.showCachedOverlayIfActive(this);
        super.onUserLeaveHint();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleLaunchNavigationIntent(intent);
    }

    private void handleLaunchNavigationIntent(Intent intent) {
        if (intent == null) return;
        final String path = intent.getStringExtra(EXTRA_NAV_PATH);
        final boolean autoTeardown = intent.getBooleanExtra(EXTRA_AUTO_END_TEARDOWN, false);
        final String notifyJson = intent.getStringExtra(EXTRA_NOTIFY_JSON);
        final int alarmCleanup = intent.getIntExtra(EXTRA_NOTIFY_ALARM_CLEANUP, -1);
        intent.removeExtra(EXTRA_NAV_PATH);
        intent.removeExtra(EXTRA_AUTO_END_TEARDOWN);
        intent.removeExtra(EXTRA_NOTIFY_JSON);
        intent.removeExtra(EXTRA_NOTIFY_ALARM_CLEANUP);
        if (alarmCleanup >= 0) {
            NotifyAlarmPayloadStore.consume(getApplicationContext(), alarmCleanup);
        }
        if (path != null && !path.isEmpty()) {
            PumpNavigationBridge.setPending(path, autoTeardown, notifyJson);
            scheduleNotifyWebToConsumeNav();
        } else if (notifyJson != null && !notifyJson.isEmpty()) {
            PumpNavigationBridge.setPending("/", false, notifyJson);
            scheduleNotifyWebToConsumeNav();
        }
    }

    private void scheduleNotifyWebToConsumeNav() {
        notifyAttempts = 0;
        tryNotifyWebToConsumeNavRecursive();
    }

    private void disableInAppSystemBack() {
        getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
            @Override
            public void handleOnBackPressed() {
                // Consume Android back gestures/buttons inside this app only.
            }
        });
    }

    private void tryNotifyWebToConsumeNavRecursive() {
        if (tryNotifyWebToConsumeNavOnce()) return;
        if (notifyAttempts++ >= 40) return;
        mainHandler.postDelayed(this::tryNotifyWebToConsumeNavRecursive, 50);
    }

    private boolean tryNotifyWebToConsumeNavOnce() {
        final Bridge bridge = getBridge();
        if (bridge == null) return false;
        final WebView wv = bridge.getWebView();
        if (wv == null) return false;
        wv.evaluateJavascript(JS_NOTIFY, null);
        return true;
    }
}
