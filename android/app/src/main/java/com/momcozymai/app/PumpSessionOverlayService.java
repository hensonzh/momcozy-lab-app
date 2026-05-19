package com.momcozymai.app;

import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.IBinder;
import android.provider.Settings;
import android.view.Gravity;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

import androidx.annotation.Nullable;

public class PumpSessionOverlayService extends Service {
    public static final String ACTION_UPDATE = "pump.session.overlay.UPDATE";
    public static final String ACTION_HIDE = "pump.session.overlay.HIDE";
    public static final String EXTRA_STATE = "state";
    public static final String EXTRA_PROCESS_ALL = "process_all";

    private WindowManager windowManager;
    private View overlayView;
    private TextView titleText;
    private TextView stateText;
    private ProgressBar progressBar;

    @Override
    public void onCreate() {
        super.onCreate();
        windowManager = (WindowManager) getSystemService(Context.WINDOW_SERVICE);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String action = intent != null ? intent.getAction() : null;
        if (ACTION_HIDE.equals(action)) {
            hideOverlay();
            stopSelf();
            return START_NOT_STICKY;
        }

        if (!canDrawOverlays()) {
            hideOverlay();
            stopSelf();
            return START_NOT_STICKY;
        }

        String state = normalizeState(intent != null ? intent.getStringExtra(EXTRA_STATE) : null);
        int processAll = clampProgress(intent != null ? intent.getIntExtra(EXTRA_PROCESS_ALL, 0) : 0);
        showOrUpdateOverlay(state, processAll);
        return START_STICKY;
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onDestroy() {
        hideOverlay();
        super.onDestroy();
    }

    private void showOrUpdateOverlay(String state, int processAll) {
        if (windowManager == null) return;
        if (overlayView == null) {
            overlayView = buildOverlayView();
            windowManager.addView(overlayView, buildLayoutParams());
        }
        titleText.setText("吸乳进程 " + processAll + "%");
        stateText.setText("paused".equals(state) ? "已暂停" : "进行中");
        progressBar.setProgress(processAll);
    }

    private View buildOverlayView() {
        int height = dp(46);
        int horizontalPadding = dp(12);

        FrameLayout root = new FrameLayout(this);
        root.setPadding(horizontalPadding, dp(4), horizontalPadding, dp(4));

        GradientDrawable background = new GradientDrawable(
                GradientDrawable.Orientation.LEFT_RIGHT,
                new int[]{Color.rgb(35, 35, 42), Color.rgb(69, 52, 58)}
        );
        background.setCornerRadius(dp(14));
        root.setBackground(background);
        root.setAlpha(0.96f);
        root.setClickable(true);
        root.setOnClickListener(v -> openPumpSessionPage());

        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setGravity(Gravity.CENTER_VERTICAL);

        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);

        titleText = new TextView(this);
        titleText.setTextColor(Color.WHITE);
        titleText.setTextSize(13);
        titleText.setTypeface(Typeface.DEFAULT_BOLD);

        stateText = new TextView(this);
        stateText.setTextColor(Color.argb(220, 255, 255, 255));
        stateText.setTextSize(11);
        stateText.setGravity(Gravity.RIGHT);

        row.addView(titleText, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
        row.addView(stateText, new LinearLayout.LayoutParams(dp(64), LinearLayout.LayoutParams.WRAP_CONTENT));

        progressBar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        progressBar.setMax(100);
        progressBar.setProgress(0);

        content.addView(row, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
        ));
        LinearLayout.LayoutParams progressParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(7)
        );
        progressParams.topMargin = dp(5);
        content.addView(progressBar, progressParams);

        root.addView(content, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                height,
                Gravity.CENTER
        ));
        return root;
    }

    private WindowManager.LayoutParams buildLayoutParams() {
        int type = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                : WindowManager.LayoutParams.TYPE_PHONE;
        int flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN;
        WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                dp(54),
                type,
                flags,
                PixelFormat.TRANSLUCENT
        );
        params.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
        params.x = 0;
        params.y = getStatusBarInset();
        return params;
    }

    private int getStatusBarInset() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            WindowInsets insets = null;
            try {
                View decor = overlayView;
                if (decor != null) {
                    insets = decor.getRootWindowInsets();
                }
            } catch (RuntimeException ignored) {
                insets = null;
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && insets != null) {
                return insets.getInsets(WindowInsets.Type.statusBars()).top;
            }
        }
        int resourceId = getResources().getIdentifier("status_bar_height", "dimen", "android");
        if (resourceId > 0) {
            return getResources().getDimensionPixelSize(resourceId);
        }
        return dp(24);
    }

    private void hideOverlay() {
        if (windowManager != null && overlayView != null) {
            try {
                windowManager.removeView(overlayView);
            } catch (RuntimeException ignored) {
                // Already detached.
            }
        }
        overlayView = null;
        titleText = null;
        stateText = null;
        progressBar = null;
    }

    private void openPumpSessionPage() {
        hideOverlay();
        Intent launchIntent = new Intent(this, MainActivity.class);
        launchIntent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_NEW_TASK);
        launchIntent.putExtra(MainActivity.EXTRA_NAV_PATH, "/pump");
        startActivity(launchIntent);
    }

    private boolean canDrawOverlays() {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this);
    }

    private int dp(int value) {
        return (int) (value * getResources().getDisplayMetrics().density + 0.5f);
    }

    private static int clampProgress(int progress) {
        if (progress < 0) return 0;
        return Math.min(progress, 100);
    }

    private static String normalizeState(String state) {
        if ("running".equals(state) || "paused".equals(state)) {
            return state;
        }
        return "running";
    }
}
