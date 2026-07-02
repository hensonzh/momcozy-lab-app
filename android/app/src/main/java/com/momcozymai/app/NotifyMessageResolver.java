package com.momcozymai.app;

import androidx.annotation.NonNull;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/**
 * 将 /v1/notify/query 的 notify_list 转为展示文案与跳转路径。
 * <p>
 * pump：任务执行时刻为「下一次」{@code HH:mm}（与闹钟计算一致）；闹钟在任务前 20 / 5 分钟，文案见 {@link #resolvePumpBody(long, long, String)}。
 * warning：闹钟与摘要应使用 {@link #resolveWarningBody(long, long, String)}，按「任务 time」与「闹钟响铃时刻」
 * 或「当前时刻」的间隔（分钟）选择 40 / 90 / 150 档文案；{@link #resolveBody} 中 warning 分支仅作无时间上下文时的回退。
 */
public final class NotifyMessageResolver {

    /** 吸奶/喂养：提前约 20 分钟提醒 */
    private static final String PUMP_BEFORE_20 =
            "妈妈，吸奶/喂养时间快到了，可以提前准备一下哦～";
    /** 吸奶/喂养：提前约 5 分钟提醒 */
    private static final String PUMP_BEFORE_5 =
            "妈妈，该吸奶/喂养了！建议准备开始";

    private static final String WARN_40 =
            "已延迟40分钟，建议尽快安排吸奶/亲喂，避免乳房不适";
    private static final String WARN_90 =
            "延迟较久(90分钟)！可能引起胀痛或不适，建议尽快安排一次吸奶/亲喂";
    private static final String WARN_150 =
            "长时间未吸奶(150分钟)！可能增加堵奶或乳腺炎风险，建议优先安排排空乳房";

    private static final String GROWN =
            "建议更新一下宝宝生长数据哦~这样能更好地帮你进行奶量管理";
    private static final String HEALTH_ISSUE =
            "嗨，我发现你的乳汁电导率有点异常，可以和你聊聊吗";

    private NotifyMessageResolver() {
    }

    static String normalizeEvent(String raw) {
        if (raw == null) return "";
        return raw.trim().toLowerCase(Locale.ROOT);
    }

    /**
     * warning：根据「计划任务执行时刻」与「本闹钟计划触发时刻」（或同步时的当前时刻）的间隔选档。
     * 间隔 &lt; 65 分钟 → 40 档；&lt; 120 分钟 → 90 档；否则 150 档（与 {@code task+40/90/150} 闹钟对齐，含少量时钟误差）。
     *
     * @param taskMillis     当日任务 time（毫秒），无效时用接口文案回退
     * @param referenceMillis 闹钟触发时刻，或构建摘要时的 {@link System#currentTimeMillis()}
     */
    @NonNull
    static String resolveWarningBody(long taskMillis, long referenceMillis, String apiMessage) {
        final String fallback = apiMessage != null ? apiMessage : "";
        if (taskMillis <= 0L || referenceMillis <= 0L) {
            return !fallback.isEmpty() ? fallback : WARN_40;
        }
        long deltaMin = (referenceMillis - taskMillis) / 60_000L;
        if (deltaMin < 0L) {
            deltaMin = 0L;
        }
        if (deltaMin < 65L) {
            return WARN_40;
        }
        if (deltaMin < 120L) {
            return WARN_90;
        }
        return WARN_150;
    }

    /**
     * pump：根据「任务执行时刻」与「参考时刻」（闹钟响铃时刻，或摘要构建时的当前时刻）的间隔选文案。
     * 提前量 ≥ 12 分钟（介于 5 与 20 的中点）→ 20 分钟档；否则 → 5 分钟档。
     */
    @NonNull
    static String resolvePumpBody(long taskExecMillis, long referenceMillis, String apiMessage) {
        final String fallback = apiMessage != null ? apiMessage : "";
        if (taskExecMillis <= 0L || referenceMillis <= 0L) {
            return !fallback.isEmpty() ? fallback : PUMP_BEFORE_5;
        }
        long leadMin = (taskExecMillis - referenceMillis) / 60_000L;
        if (leadMin < 0L) {
            leadMin = 0L;
        }
        if (leadMin >= 12L) {
            return PUMP_BEFORE_20;
        }
        return PUMP_BEFORE_5;
    }

    /**
     * @param event       已 normalize
     * @param indexInGroup 同 event 在本次列表中的序号，从 0 开始
     * @param apiMessage  接口 message，作回退
     */
    @NonNull
    static String resolveBody(@NonNull String event, int indexInGroup, String apiMessage) {
        final String fallback = apiMessage != null ? apiMessage : "";
        switch (event) {
            case "summary":
                return fallback;
            case "pump":
                // 无任务/闹钟时间上下文时按序号回退（闹钟路径应走 resolvePumpBody）
                if (indexInGroup == 0) return PUMP_BEFORE_20;
                if (indexInGroup == 1) return PUMP_BEFORE_5;
                return !fallback.isEmpty() ? fallback : PUMP_BEFORE_5;
            case "warning":
                // 无任务/闹钟时间时回退（新代码应走 resolveWarningBody）
                if (indexInGroup == 0) return WARN_40;
                if (indexInGroup == 1) return WARN_90;
                if (indexInGroup == 2) return WARN_150;
                return !fallback.isEmpty() ? fallback : WARN_150;
            case "grown":
                return GROWN;
            case "health_issue":
                return !fallback.isEmpty() ? fallback : HEALTH_ISSUE;
            default:
                return fallback;
        }
    }

    @NonNull
    static String notificationTitle(@NonNull String event) {
        switch (event) {
            case "pump":
                return "吸奶/喂养提醒";
            case "warning":
                return "风险预警";
            case "grown":
                return "宝宝生长指标";
            case "summary":
                return "每日奶量小结";
            case "health_issue":
                return "健康问题通知";
            default:
                return "Momcozy 提醒";
        }
    }

    @NonNull
    static String navPathForEvent(@NonNull String event) {
        switch (event) {
            case "pump":
            case "warning":
                return "/schedule?mmcNotify=1";
            case "grown":
                return "/status?mmcNotify=growth";
            case "summary":
            case "health_issue":
                return "/";
            default:
                return "/schedule?mmcNotify=1";
        }
    }

    /**
     * 供 Web/Flutter 侧消费：pending route 只携带事件类型，完整业务正文仅用于通知展示。
     */
    @NonNull
    static String buildNotifyJsonForWeb(@NonNull String event, @NonNull String body) {
        try {
            JSONObject o = new JSONObject();
            o.put("event", event);
            return o.toString();
        } catch (Exception e) {
            return "{\"event\":\"" + event + "\"}";
        }
    }

    /**
     * 解析 notify_list 并附带组内序号。
     */
    @NonNull
    static JSONArray annotateWithGroupIndex(JSONArray notifyList) throws org.json.JSONException {
        Map<String, Integer> counters = new HashMap<>();
        JSONArray out = new JSONArray();
        for (int i = 0; i < notifyList.length(); i++) {
            JSONObject row = notifyList.optJSONObject(i);
            if (row == null) continue;
            String ev = normalizeEvent(row.optString("event", ""));
            int idx = counters.getOrDefault(ev, 0);
            counters.put(ev, idx + 1);
            JSONObject copy = new JSONObject(row.toString());
            copy.put("_mmc_group_index", idx);
            out.put(copy);
        }
        return out;
    }
}
