package com.momcozymai.app;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.TimeZone;

final class PumpAgentNativeStore {
    private static final int FRAME_SIZE = 20;
    private static final long SOURCE_TTL_MS = 6000L;
    private static final Object LOCK = new Object();

    private static final SideState L = new SideState();
    private static final SideState R = new SideState();
    private static int processAll;

    private PumpAgentNativeStore() {
    }

    static void resetProgress() {
        synchronized (LOCK) {
            L.resetProgress();
            R.resetProgress();
            processAll = 0;
        }
    }

    static void markStepStop(String side) {
        synchronized (LOCK) {
            if ("both".equals(side)) {
                L.stopMarked = true;
                R.stopMarked = true;
            } else {
                state(side).stopMarked = true;
            }
        }
    }

    static void markStepPause(String side) {
        synchronized (LOCK) {
            if ("both".equals(side)) {
                L.pauseMarked = true;
                R.pauseMarked = true;
            } else {
                state(side).pauseMarked = true;
            }
        }
    }

    static void setOperationSource(String side, String source) {
        synchronized (LOCK) {
            long expires = System.currentTimeMillis() + SOURCE_TTL_MS;
            if ("both".equals(side)) {
                L.source = source;
                R.source = source;
                L.sourceExpiresAt = expires;
                R.sourceExpiresAt = expires;
            } else {
                SideState st = state(side);
                st.source = source;
                st.sourceExpiresAt = expires;
            }
        }
    }

    static void markDeviceSourceByPacket(int cid, String deviceId) {
        if (!(cid == 0xe0 || cid == 0xe1 || cid == 0xd0 || cid == 0xd1 || cid == 0xd4 || cid == 0xd5 || cid == 0xd6)) {
            return;
        }
        synchronized (LOCK) {
            try {
                JSONObject root = new JSONObject(DeviceNativeStateStore.getSnapshotJson());
                boolean matched = false;
                JSONObject left = root.optJSONObject("L");
                JSONObject right = root.optJSONObject("R");
                if (deviceId != null && left != null && deviceId.equals(left.optString("deviceId", ""))) {
                    setOperationSourceLocked(L, "device");
                    matched = true;
                }
                if (deviceId != null && right != null && deviceId.equals(right.optString("deviceId", ""))) {
                    setOperationSourceLocked(R, "device");
                    matched = true;
                }
                if (!matched) {
                    setOperationSourceLocked(L, "device");
                    setOperationSourceLocked(R, "device");
                }
            } catch (JSONException ignored) {
            }
        }
    }

    static void sampleFromSnapshot() {
        synchronized (LOCK) {
            try {
                JSONObject root = new JSONObject(DeviceNativeStateStore.getSnapshotJson());
                sampleSide(L, root.optJSONObject("L"));
                sampleSide(R, root.optJSONObject("R"));
            } catch (JSONException ignored) {
            }
        }
    }

    static JSONObject buildWorkstateBody(String userId) throws JSONException {
        synchronized (LOCK) {
            JSONObject root = new JSONObject(DeviceNativeStateStore.getSnapshotJson());
            JSONObject body = new JSONObject();
            body.put("user_id", userId);
            body.put("device_left", workstateSide(root.optJSONObject("L"), L));
            body.put("device_right", workstateSide(root.optJSONObject("R"), R));
            return body;
        }
    }

    static JSONObject buildProcessDataBody(String userId) throws JSONException {
        synchronized (LOCK) {
            JSONObject root = new JSONObject(DeviceNativeStateStore.getSnapshotJson());
            JSONObject body = new JSONObject();
            body.put("user_id", userId);
            body.put("device_left", processDataSide(root.optJSONObject("L"), L));
            body.put("device_right", processDataSide(root.optJSONObject("R"), R));
            return body;
        }
    }

    static JSONObject buildProcessBody(String userId) throws JSONException {
        synchronized (LOCK) {
            JSONObject root = new JSONObject(DeviceNativeStateStore.getSnapshotJson());
            JSONObject body = new JSONObject();
            body.put("user_id", userId);
            body.put("process_left", processSide(root.optJSONObject("L"), L));
            body.put("process_right", processSide(root.optJSONObject("R"), R));
            return body;
        }
    }

    static JSONObject buildMilkUploadBody(String userId, long endedAtMs) throws JSONException {
        JSONObject root = new JSONObject(DeviceNativeStateStore.getSnapshotJson());
        JSONObject body = new JSONObject();
        double left = displayedMilk(root.optJSONObject("L"));
        double right = displayedMilk(root.optJSONObject("R"));
        body.put("user_id", userId);
        body.put("pump_type", 0);
        body.put("pump_source", 0);
        body.put("pump_time", new SimpleDateFormat("HH:mm", Locale.US).format(new Date(endedAtMs)));
        body.put("pump_milk_volum", Math.max(0, Math.round((left + right) * 10.0) / 10.0));
        return body;
    }

    static void applyProcessDataResponse(JSONObject data, JSONObject requestBody) {
        synchronized (LOCK) {
            int err = data.optInt("error", 0);
            if (err != 0) return;
            String leftStep = requestBody.optJSONObject("device_left") != null
                    ? requestBody.optJSONObject("device_left").optString("step", "")
                    : "";
            String rightStep = requestBody.optJSONObject("device_right") != null
                    ? requestBody.optJSONObject("device_right").optString("step", "")
                    : "";
            if (!"stop".equals(leftStep)) L.process = Math.max(0, Math.round((float) data.optDouble("process_l", 0)));
            if (!"stop".equals(rightStep)) R.process = Math.max(0, Math.round((float) data.optDouble("process_r", 0)));
            processAll = Math.max(0, Math.round((float) data.optDouble("process_all", 0)));
            L.frames.clear();
            R.frames.clear();
        }
    }

    static JSONObject progressJson() {
        synchronized (LOCK) {
            JSONObject out = new JSONObject();
            try {
                out.put("processL", L.process);
                out.put("processR", R.process);
                out.put("processAll", processAll);
            } catch (JSONException ignored) {
            }
            return out;
        }
    }

    static boolean hasAnyDeviceConnected() {
        synchronized (LOCK) {
            try {
                JSONObject root = new JSONObject(DeviceNativeStateStore.getSnapshotJson());
                return isConnected(root.optJSONObject("L")) || isConnected(root.optJSONObject("R"));
            } catch (JSONException ignored) {
                return false;
            }
        }
    }

    static boolean shouldFetchProcessData() {
        synchronized (LOCK) {
            try {
                JSONObject root = new JSONObject(DeviceNativeStateStore.getSnapshotJson());
                return isRunning(root.optJSONObject("L")) || isRunning(root.optJSONObject("R")) || L.stopMarked || R.stopMarked || L.pauseMarked || R.pauseMarked;
            } catch (JSONException ignored) {
                return L.stopMarked || R.stopMarked || L.pauseMarked || R.pauseMarked;
            }
        }
    }

    static String workstateSignature() {
        synchronized (LOCK) {
            try {
                JSONObject root = new JSONObject(DeviceNativeStateStore.getSnapshotJson());
                JSONObject sig = new JSONObject();
                sig.put("L", signatureSide(root.optJSONObject("L")));
                sig.put("R", signatureSide(root.optJSONObject("R")));
                return sig.toString();
            } catch (JSONException ignored) {
                return "";
            }
        }
    }

    private static JSONObject workstateSide(JSONObject device, SideState st) throws JSONException {
        String now = isoNow();
        String source = resolveSource(st);
        if (device == null) return new JSONObject().put("state", 4).put("timestamp", now).put("change_type", source);
        String ts = "device".equals(source) ? device.optString("lastDeviceWorkstateTs", now) : now;
        if (!device.optBoolean("connected", false)) {
            return new JSONObject().put("state", 3).put("timestamp", ts).put("change_type", source);
        }
        JSONObject out = new JSONObject();
        int mode = device.optInt("pumpMode", -1);
        out.put("state", device.optInt("pumpWorkState", 0) == 1 ? 1 : 0);
        out.put("scene", device.optInt("pumpScene", 0) == 1 ? "auto" : "manual");
        if (mode == 0) out.put("mode", "stimulate");
        else if (mode == 1) out.put("mode", "deep");
        else if (mode == 2) out.put("mode", "mix");
        if (device.has("gear")) out.put("level", device.optInt("gear", 0));
        out.put("timestamp", ts);
        out.put("change_type", source);
        return out;
    }

    private static JSONObject signatureSide(JSONObject device) throws JSONException {
        JSONObject out = new JSONObject();
        out.put("connected", isConnected(device));
        out.put("pumpWorkState", device != null ? device.optInt("pumpWorkState", -1) : -1);
        out.put("pumpScene", device != null ? device.optInt("pumpScene", -1) : -1);
        out.put("pumpMode", device != null ? device.optInt("pumpMode", -1) : -1);
        out.put("gear", device != null ? device.optInt("gear", -1) : -1);
        return out;
    }

    private static JSONObject processDataSide(JSONObject device, SideState st) throws JSONException {
        String now = isoNow();
        boolean connected = device != null && device.optBoolean("connected", false);
        boolean running = connected && device.optInt("pumpWorkState", 0) == 1;
        if (!connected) {
            resolveStep(st, false, false);
            return emptyProcessDataSide("offline", now);
        }
        if (!running) {
            return emptyProcessDataSide(resolveStep(st, true, false), device.optString("lastDeviceProcessTs", now));
        }
        Frame last = st.frames.isEmpty() ? null : st.frames.get(st.frames.size() - 1);
        JSONObject out = new JSONObject();
        out.put("step", resolveStep(st, true, true));
        out.put("cap_data", capDataArray(st));
        out.put("time", last != null ? last.time : device.optString("lastDeviceProcessTs", now));
        out.put("milk_reel", last != null ? last.milkReel : 0);
        out.put("bandpower", last != null ? last.bandpower : 0);
        out.put("milk", last != null ? last.milk : 0);
        return out;
    }

    private static JSONObject processSide(JSONObject device, SideState st) throws JSONException {
        if (device == null || !device.optBoolean("connected", false)) return zeroProcessSide(st);
        syncSnapshotFields(st, device);
        JSONObject out = new JSONObject();
        out.put("time", st.time.isEmpty() ? isoNow() : st.time);
        out.put("process", st.process);
        out.put("cap_data", st.capData);
        out.put("milk_reel", st.milkReel);
        out.put("bandpower", st.bandpower);
        out.put("milk", st.milk);
        return out;
    }

    private static JSONObject zeroProcessSide(SideState st) throws JSONException {
        JSONObject out = new JSONObject();
        out.put("time", st.time.isEmpty() ? isoNow() : st.time);
        out.put("process", 0);
        out.put("cap_data", 0);
        out.put("milk_reel", 0);
        out.put("bandpower", 0);
        out.put("milk", 0);
        return out;
    }

    private static JSONObject emptyProcessDataSide(String step, String time) throws JSONException {
        JSONObject out = new JSONObject();
        out.put("step", step);
        out.put("cap_data", zeroArray());
        out.put("time", time);
        out.put("milk_reel", 0);
        out.put("bandpower", 0);
        out.put("milk", 0);
        return out;
    }

    private static void sampleSide(SideState st, JSONObject device) {
        boolean connected = isConnected(device);
        if (connected && !st.prevConnected) {
            st.step = "stop";
            st.stopMarked = false;
            st.pauseMarked = false;
            st.frames.clear();
        }
        if (!connected && st.prevConnected) {
            st.step = "stop";
            st.pauseMarked = false;
            st.frames.clear();
        }
        st.prevConnected = connected;
        if (!connected || device == null) return;
        syncSnapshotFields(st, device);
        String ts = device.optString("lastDeviceProcessTs", isoNow());
        st.frames.add(new Frame(ts, st.capData, st.milkReel, st.bandpower, st.milk));
        while (st.frames.size() > FRAME_SIZE) st.frames.remove(0);
    }

    private static boolean isConnected(JSONObject device) {
        return device != null && device.optBoolean("connected", false);
    }

    private static boolean isRunning(JSONObject device) {
        return isConnected(device) && device.optInt("pumpWorkState", 0) == 1;
    }

    private static void syncSnapshotFields(SideState st, JSONObject device) {
        st.time = "device".equals(resolveSource(st)) ? device.optString("lastDeviceProcessTs", isoNow()) : isoNow();
        st.capData = Math.max(0, Math.round((float) device.optDouble("flowFloat", st.capData) * 100f) / 100.0);
        st.milkReel = composeMilkReel(device);
        st.bandpower = Math.max(0, Math.round((float) device.optDouble("bandpower", st.bandpower)));
        st.milk = Math.max(0, Math.round((float) device.optDouble("milkMl", st.milk)));
    }

    private static JSONArray capDataArray(SideState st) {
        JSONArray arr = new JSONArray();
        int pad = Math.max(0, FRAME_SIZE - st.frames.size());
        for (int i = 0; i < pad; i++) arr.put(0);
        int start = Math.max(0, st.frames.size() - FRAME_SIZE);
        for (int i = start; i < st.frames.size(); i++) arr.put(Double.valueOf(st.frames.get(i).capData));
        return arr;
    }

    private static JSONArray zeroArray() {
        JSONArray arr = new JSONArray();
        for (int i = 0; i < FRAME_SIZE; i++) arr.put(0);
        return arr;
    }

    private static String resolveStep(SideState st, boolean connected, boolean running) {
        if (st.stopMarked) {
            st.stopMarked = false;
            st.step = "stop";
            return "stop";
        }
        if (st.pauseMarked) {
            st.pauseMarked = false;
            st.step = "pause";
            return "pause";
        }
        if (!connected) {
            st.step = "stop";
            return "stop";
        }
        if (!running) {
            if ("running".equals(st.step) || "start".equals(st.step) || "pause".equals(st.step)) {
                st.step = "pause";
                return "pause";
            }
            st.step = "stop";
            return "stop";
        }
        st.step = "stop".equals(st.step) ? "start" : "running";
        return st.step;
    }

    private static String resolveSource(SideState st) {
        return st.sourceExpiresAt > System.currentTimeMillis() ? st.source : "device";
    }

    private static void setOperationSourceLocked(SideState st, String source) {
        st.source = source;
        st.sourceExpiresAt = System.currentTimeMillis() + SOURCE_TTL_MS;
    }

    private static SideState state(String side) {
        return "R".equals(side) ? R : L;
    }

    private static int composeMilkReel(JSONObject device) {
        int milk = device.optInt("milkFlag", 0) & 0x01;
        int mo = device.optInt("moFlag", 0) & 0x01;
        return (mo << 1) | milk;
    }

    private static double displayedMilk(JSONObject device) {
        if (device == null || !device.optBoolean("connected", false)) return 0;
        return Math.max(0, Math.round((float) device.optDouble("milkMl", 0)));
    }

    private static String isoNow() {
        SimpleDateFormat fmt = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US);
        fmt.setTimeZone(TimeZone.getTimeZone("UTC"));
        return fmt.format(new Date());
    }

    private static final class SideState {
        String source = "device";
        long sourceExpiresAt;
        String step = "stop";
        boolean stopMarked;
        boolean pauseMarked;
        boolean prevConnected;
        int process;
        String time = isoNow();
        double capData;
        int milkReel;
        int bandpower;
        int milk;
        final List<Frame> frames = new ArrayList<>();

        void resetProgress() {
            process = 0;
            frames.clear();
            step = "stop";
            stopMarked = false;
            pauseMarked = false;
        }
    }

    private static final class Frame {
        final String time;
        final double capData;
        final int milkReel;
        final int bandpower;
        final int milk;

        Frame(String time, double capData, int milkReel, int bandpower, int milk) {
            this.time = time;
            this.capData = capData;
            this.milkReel = milkReel;
            this.bandpower = bandpower;
            this.milk = milk;
        }
    }
}
