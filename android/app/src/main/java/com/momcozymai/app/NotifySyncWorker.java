package com.momcozymai.app;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import org.json.JSONArray;
import org.json.JSONObject;

import android.util.Log;

/**
 * 周期拉取 /v1/notify/query 并刷新 AlarmManager 闹钟（与宏无关，始终执行）。
 * 编译宏 {@link BuildConfig#MMC_ENABLE_PERIODIC_NOTIFY_SYNC} 仅控制：15 分钟周期任务成功后是否弹出摘要通知；
 * 冷启动（{@link #TRIGGER_APP_LAUNCH}）成功后始终尝试弹出摘要通知（仍受系统通知权限限制）。
 */
public class NotifySyncWorker extends Worker {

    private static final String TAG = "NotifySyncWorker";

    /** {@link androidx.work.Data} 中区分周期任务与一次性任务 */
    public static final String KEY_TRIGGER = "mmc_trigger";
    public static final String TRIGGER_PERIODIC = "periodic";
    public static final String TRIGGER_ONESHOT = "oneshot";
    /** 冷启动 MainActivity 入队，与手动 {@link NotifyWorkScheduler#enqueueOneShot} 区分 */
    public static final String TRIGGER_APP_LAUNCH = "app_launch";

    public NotifySyncWorker(@NonNull Context context, @NonNull WorkerParameters workerParams) {
        super(context, workerParams);
    }

    @NonNull
    @Override
    public Result doWork() {
        Context ctx = getApplicationContext();
        String rawTrigger = getInputData().getString(KEY_TRIGGER);
        Log.i(
                TAG,
                "doWork START workId=" + getId()
                        + " runAttempt=" + getRunAttemptCount()
                        + " rawTrigger=" + (rawTrigger == null ? "null" : rawTrigger)
                        + " enabled=" + BackgroundNotifyPrefs.isEnabled(ctx)
        );
        if (!BackgroundNotifyPrefs.isEnabled(ctx)) {
            Log.i(TAG, "doWork END result=success reason=background_notify_disabled");
            return Result.success();
        }
        String base = BackgroundNotifyPrefs.getApiBaseUrl(ctx);
        String userId = BackgroundNotifyPrefs.getUserId(ctx);
        if (base == null || base.isEmpty() || userId == null || userId.isEmpty()) {
            Log.w(TAG, "doWork END result=success reason=missing_config baseEmpty=" + (base == null || base.isEmpty())
                    + " userIdEmpty=" + (userId == null || userId.isEmpty()));
            return Result.success();
        }
        String trigger = rawTrigger;
        if (trigger == null || trigger.isEmpty()) {
            trigger = TRIGGER_ONESHOT;
        }
        boolean isPeriodicRun = TRIGGER_PERIODIC.equals(trigger);
        boolean isAppLaunch = TRIGGER_APP_LAUNCH.equals(trigger);
        Log.i(
                TAG,
                "doWork proceed trigger=" + trigger
                        + " isPeriodic=" + isPeriodicRun
                        + " isAppLaunch=" + isAppLaunch
                        + " mmcPeriodicNotifySummary=" + BuildConfig.MMC_ENABLE_PERIODIC_NOTIFY_SYNC
        );
        try {
            JSONObject data = NotifyApiClient.fetchNotifyQuery(
                    base,
                    BackgroundNotifyPrefs.getBearerToken(ctx),
                    userId
            );
            int err = data.optInt("error", 0);
            if (err != 0) {
                Log.w(TAG, "doWork END result=retry reason=notify_query_error code=" + err);
                return Result.retry();
            }
            JSONArray notifyList = data.optJSONArray("notify_list");
            int listLen = notifyList != null ? notifyList.length() : 0;
            Log.i(TAG, "doWork notify/query ok notify_list.length=" + listLen + " rescheduling alarms");
            NotifyAlarmScheduler.rescheduleFromNotifyData(ctx, data);
            if (BuildConfig.MMC_ENABLE_PERIODIC_NOTIFY_SYNC && isPeriodicRun) {
                Log.i(TAG, "doWork showing periodic sync summary notification");
                NotifyPeriodicSyncNotifier.show(ctx, data, false);
            } else if (isPeriodicRun) {
                Log.i(TAG, "doWork skip periodic summary (mmcPeriodicNotifySync macro false)");
            }
            if (isAppLaunch) {
                Log.i(TAG, "doWork showing app-launch sync summary notification");
                NotifyPeriodicSyncNotifier.show(ctx, data, true);
            }
            Log.i(TAG, "doWork END result=success");
            if (isPeriodicRun) {
                NotifyWorkScheduler.logPeriodicWorkStatus(ctx, "NotifySyncWorker.after_periodic_success");
            }
            return Result.success();
        } catch (Exception e) {
            Log.e(TAG, "doWork END result=retry reason=exception", e);
            return Result.retry();
        }
    }
}
