package com.momcozymai.app;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.work.Constraints;
import androidx.work.Data;
import androidx.work.ExistingPeriodicWorkPolicy;
import androidx.work.ExistingWorkPolicy;
import androidx.work.NetworkType;
import androidx.work.OneTimeWorkRequest;
import androidx.work.PeriodicWorkRequest;
import androidx.work.WorkInfo;
import androidx.work.WorkManager;

import com.google.common.util.concurrent.ListenableFuture;

import java.util.List;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

/**
 * 注册 / 注销 15 分钟周期同步任务。
 * 使用 {@link ExistingPeriodicWorkPolicy#UPDATE}，避免旧版本用 KEEP 留下的周期任务缺少
 * {@link NotifySyncWorker#KEY_TRIGGER}，导致 Worker 误判为 oneshot、周期摘要永不弹出。
 */
public final class NotifyWorkScheduler {

    public static final String UNIQUE_PERIODIC = "mmc_notify_periodic_sync_v1";

    /** Logcat 过滤：周期任务入队 / WorkManager 状态 */
    private static final String TAG_WM = "MmcNotifyPeriodicWM";

    private static final ExecutorService WM_STATUS_LOG_EXEC = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "mmc-wm-periodic-status");
        t.setDaemon(true);
        return t;
    });

    private NotifyWorkScheduler() {
    }

    /**
     * 异步查询 {@link #UNIQUE_PERIODIC} 在 WorkManager 中的 {@link WorkInfo}，便于分析周期任务是否入队、当前状态、下次调度等。
     */
    public static void logPeriodicWorkStatus(@NonNull Context ctx, @NonNull String reason) {
        final Context app = ctx.getApplicationContext();
        WM_STATUS_LOG_EXEC.execute(() -> {
            try {
                ListenableFuture<List<WorkInfo>> future =
                        WorkManager.getInstance(app).getWorkInfosForUniqueWork(UNIQUE_PERIODIC);
                List<WorkInfo> infos = future.get(20, TimeUnit.SECONDS);
                if (infos == null || infos.isEmpty()) {
                    Log.w(TAG_WM, "[" + reason + "] unique=" + UNIQUE_PERIODIC + " → no WorkInfo (未注册或已被取消)");
                    return;
                }
                for (int i = 0; i < infos.size(); i++) {
                    WorkInfo wi = infos.get(i);
                    StringBuilder sb = new StringBuilder();
                    sb.append("[").append(reason).append("] unique=").append(UNIQUE_PERIODIC);
                    sb.append(" #").append(i);
                    sb.append(" state=").append(wi.getState());
                    sb.append(" id=").append(wi.getId());
                    sb.append(" runAttempt=").append(wi.getRunAttemptCount());
                    sb.append(" tags=").append(wi.getTags());
                    try {
                        sb.append(" nextScheduleMs=").append(wi.getNextScheduleTimeMillis());
                    } catch (Throwable ignored) {
                    }
                    Log.i(TAG_WM, sb.toString());
                }
            } catch (TimeoutException e) {
                Log.e(TAG_WM, "[" + reason + "] getWorkInfosForUniqueWork timeout", e);
            } catch (ExecutionException e) {
                Log.e(TAG_WM, "[" + reason + "] getWorkInfosForUniqueWork failed", e);
            } catch (InterruptedException e) {
                Log.e(TAG_WM, "[" + reason + "] getWorkInfosForUniqueWork interrupted", e);
                Thread.currentThread().interrupt();
            }
        });
    }

    public static void enqueuePeriodic(Context ctx) {
        Constraints constraints = new Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build();
        Data input = new Data.Builder()
                .putString(NotifySyncWorker.KEY_TRIGGER, NotifySyncWorker.TRIGGER_PERIODIC)
                .build();
        PeriodicWorkRequest req = new PeriodicWorkRequest.Builder(
                NotifySyncWorker.class,
                15,
                TimeUnit.MINUTES
        )
                .setConstraints(constraints)
                .setInputData(input)
                .build();
        WorkManager.getInstance(ctx.getApplicationContext())
                .enqueueUniquePeriodicWork(UNIQUE_PERIODIC, ExistingPeriodicWorkPolicy.UPDATE, req);
        Log.i(
                TAG_WM,
                "enqueueUniquePeriodicWork name=" + UNIQUE_PERIODIC
                        + " policy=UPDATE interval=15min network=CONNECTED trigger=periodic"
        );
    }

    public static void cancelPeriodic(Context ctx) {
        WorkManager.getInstance(ctx.getApplicationContext()).cancelUniqueWork(UNIQUE_PERIODIC);
    }

    public static void enqueueOneShot(@NonNull Context ctx) {
        Data input = new Data.Builder()
                .putString(NotifySyncWorker.KEY_TRIGGER, NotifySyncWorker.TRIGGER_ONESHOT)
                .build();
        OneTimeWorkRequest once = new OneTimeWorkRequest.Builder(NotifySyncWorker.class)
                .setInputData(input)
                .build();
        WorkManager.getInstance(ctx.getApplicationContext()).enqueue(once);
    }

    /**
     * 打开应用时拉取一次（与 {@link #enqueueOneShot} 区分），成功后可弹「打开应用：提醒已同步」摘要。
     * 使用 unique + REPLACE，避免短时间内重复入队；需网络，与接口一致。
     */
    public static void enqueueAppLaunchOneShot(@NonNull Context ctx) {
        Constraints constraints = new Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build();
        Data input = new Data.Builder()
                .putString(NotifySyncWorker.KEY_TRIGGER, NotifySyncWorker.TRIGGER_APP_LAUNCH)
                .build();
        OneTimeWorkRequest once = new OneTimeWorkRequest.Builder(NotifySyncWorker.class)
                .setConstraints(constraints)
                .setInputData(input)
                .build();
        WorkManager.getInstance(ctx.getApplicationContext())
                .enqueueUniqueWork("mmc_notify_app_launch_sync_v1", ExistingWorkPolicy.REPLACE, once);
    }
}
