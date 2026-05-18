package com.momcozymai.app;

/**
 * 承载从原生 Intent 传递到 WebView 侧的一次性路由（例如点击吸乳会话通知）。
 */
public final class PumpNavigationBridge {

    private PumpNavigationBridge() {
    }

    private static volatile String pendingPath;
    private static volatile boolean pendingAutoEndTeardown;
    /** 可选：后台提醒等场景带给 Web 的 JSON（如每日小结正文）。 */
    private static volatile String pendingNotifyJson;

    public static final class PendingNavigate {
        public final String path;
        public final boolean autoEndTeardown;
        public final String notifyJson;

        PendingNavigate(String path, boolean autoEndTeardown, String notifyJson) {
            this.path = path != null ? path : "";
            this.autoEndTeardown = autoEndTeardown;
            this.notifyJson = notifyJson != null ? notifyJson : "";
        }
    }

    public static synchronized void setPending(String path, boolean autoEndTeardown) {
        setPending(path, autoEndTeardown, null);
    }

    public static synchronized void setPending(String path, boolean autoEndTeardown, String notifyJson) {
        if (path == null || path.isEmpty()) return;
        pendingPath = path;
        pendingAutoEndTeardown = autoEndTeardown;
        if (notifyJson != null && !notifyJson.isEmpty()) {
            pendingNotifyJson = notifyJson;
        } else {
            pendingNotifyJson = null;
        }
    }

    /**
     * 取出并重置 pending，避免同一 Intent 重复消费。
     */
    public static synchronized PendingNavigate consumePendingNavigate() {
        final String p = pendingPath;
        pendingPath = null;
        final boolean t = pendingAutoEndTeardown;
        pendingAutoEndTeardown = false;
        final String nj = pendingNotifyJson;
        pendingNotifyJson = null;
        return new PendingNavigate(p != null ? p : "", t, nj != null ? nj : "");
    }
}
