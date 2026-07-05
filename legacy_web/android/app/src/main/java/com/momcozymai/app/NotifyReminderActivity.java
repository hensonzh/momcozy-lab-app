package com.momcozymai.app;

import android.app.KeyguardManager;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.TextView;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import org.json.JSONObject;

/**
 * 闹钟触发的全屏/悬浮风格提醒（高优先级通知的 fullScreenIntent 目标页）。
 */
public class NotifyReminderActivity extends AppCompatActivity {

    public static final String EXTRA_ALARM_ID = "com.momcozymai.app.EXTRA_NOTIFY_REMINDER_ALARM_ID";

    private int alarmId = -1;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true);
            setTurnScreenOn(true);
            KeyguardManager km = (KeyguardManager) getSystemService(Context.KEYGUARD_SERVICE);
            if (km != null) {
                km.requestDismissKeyguard(this, null);
            }
        } else {
            getWindow().addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                            | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                            | WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            );
        }
        setContentView(R.layout.activity_notify_reminder);
        alarmId = getIntent().getIntExtra(EXTRA_ALARM_ID, -1);
        String raw = alarmId >= 0 ? NotifyAlarmPayloadStore.peek(this, alarmId) : null;
        if (raw == null || raw.isEmpty()) {
            finish();
            return;
        }
        try {
            JSONObject payload = new JSONObject(raw);
            TextView t = findViewById(R.id.mmc_notify_title);
            TextView b = findViewById(R.id.mmc_notify_body);
            Button open = findViewById(R.id.mmc_notify_open);
            t.setText(payload.optString("title", "提醒"));
            b.setText(payload.optString("body", ""));
            open.setOnClickListener(v -> openMain(payload));
        } catch (Exception e) {
            finish();
        }
    }

    private void openMain(JSONObject payload) {
        Intent i = new Intent(this, MainActivity.class);
        i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        i.putExtra(MainActivity.EXTRA_NAV_PATH, payload.optString("path", "/"));
        String nj = payload.optString("notifyJson", "");
        if (!nj.isEmpty()) {
            i.putExtra(MainActivity.EXTRA_NOTIFY_JSON, nj);
        }
        if (alarmId >= 0) {
            i.putExtra(MainActivity.EXTRA_NOTIFY_ALARM_CLEANUP, alarmId);
        }
        startActivity(i);
        finish();
    }

    @Override
    protected void onDestroy() {
        if (alarmId >= 0) {
            String left = NotifyAlarmPayloadStore.peek(this, alarmId);
            if (left != null && !left.isEmpty()) {
                NotifyAlarmPayloadStore.consume(this, alarmId);
            }
        }
        super.onDestroy();
    }
}
