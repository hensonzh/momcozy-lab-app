package com.momcozymai.app;

import org.json.JSONException;
import org.json.JSONObject;

final class DeviceNativeStateStore {
    private static final Object LOCK = new Object();
    private static String snapshotJson = "{\"L\":null,\"R\":null}";
    private static double leftBandpowerMax;
    private static double rightBandpowerMax;

    private DeviceNativeStateStore() {
    }

    static void updateSnapshot(String nextSnapshotJson) {
        if (nextSnapshotJson == null || nextSnapshotJson.trim().isEmpty()) return;
        synchronized (LOCK) {
            snapshotJson = nextSnapshotJson;
        }
    }

    static String getSnapshotJson() {
        synchronized (LOCK) {
            return snapshotJson;
        }
    }

    static void clear() {
        synchronized (LOCK) {
            snapshotJson = "{\"L\":null,\"R\":null}";
            leftBandpowerMax = 0;
            rightBandpowerMax = 0;
        }
    }

    static boolean applyProtocolFrame(String deviceId, byte[] value) {
        MmcBleProtocol.ParsedFrame frame = MmcBleProtocol.parseFrame(value);
        if (frame == null) return false;
        try {
            switch (frame.cid) {
                case 0xf0:
                    if (frame.ct == MmcBleProtocol.CT_ACK) return applyF0(deviceId, frame.cab);
                    break;
                case 0xe1:
                    if (frame.ct == MmcBleProtocol.CT_ACK) return applyE1(deviceId, frame.cab);
                    break;
                case 0xd6:
                    return applyD6(deviceId, frame.cab);
                case 0xd0:
                    return applyD0(deviceId, frame.cab);
                case 0x80:
                    return apply80(deviceId, frame.cab);
                case 0xbf:
                    if (frame.ct == MmcBleProtocol.CT_ACK) return applyBF(deviceId, frame.cab);
                    break;
                case 0xfe:
                    if (frame.ct == MmcBleProtocol.CT_ACK) return applyFE(deviceId);
                    break;
                default:
                    break;
            }
        } catch (JSONException ignored) {
        }
        return false;
    }

    private static boolean applyF0(String deviceId, byte[] cab) throws JSONException {
        JSONObject parsed = MmcBleProtocol.parseF0DeviceInfo(cab);
        if (parsed == null) return false;
        return mutateDevice(deviceId, device -> {
            device.put("firmware", parsed.optString("softwareVersion", device.optString("firmware", "-")));
        });
    }

    private static boolean applyE1(String deviceId, byte[] cab) throws JSONException {
        JSONObject parsed = MmcBleProtocol.parseE1DeviceStatus(cab);
        if (parsed == null) return false;
        return mutateDevice(deviceId, device -> {
            int scene = parsed.optInt("scene", 0) != 0 ? 1 : 0;
            device.put("battery", clamp(parsed.optInt("batteryPct", device.optInt("battery", 0)), 0, 100));
            device.put("pumpMode", clamp(parsed.optInt("pumpMode", 0), 0, 2));
            device.put("gear", clamp(parsed.optInt("gear", 0), 0, 14));
            device.put("pumpWorkState", parsed.optInt("workState", 0));
            device.put("pumpScene", scene);
            device.put("duration", parsed.optInt("duration", 0));
            JSONObject calib = new JSONObject();
            calib.put("stimulate", parsed.optInt("pumpGearCalibStimulate", 0));
            calib.put("deep", parsed.optInt("pumpGearCalibDeep", 0));
            device.put("pumpGearCalib", calib);
            putPacketTimestamp(device, "lastDeviceWorkstateTs", parsed.optLong("bootTime", 0));
        });
    }

    private static boolean applyD6(String deviceId, byte[] cab) throws JSONException {
        JSONObject parsed = MmcBleProtocol.parseD6Battery(cab);
        if (parsed == null) return false;
        return mutateDevice(deviceId, device -> {
            device.put("battery", clamp(parsed.optInt("batteryPct", device.optInt("battery", 0)), 0, 100));
            putPacketTimestamp(device, "lastDeviceWorkstateTs", parsed.optLong("timestamp", 0));
        });
    }

    private static boolean applyD0(String deviceId, byte[] cab) throws JSONException {
        JSONObject parsed = MmcBleProtocol.parseD0OperationRecord(cab);
        if (parsed == null) return false;
        return mutateDevice(deviceId, device -> {
            int mode = clamp(parsed.optInt("afterMode", device.optInt("pumpMode", 0)), 0, 2);
            int gear = clamp(parsed.optInt("afterGear", device.optInt("gear", 0)), 0, 14);
            int scene = parsed.optInt("afterAutoFlag", 0) != 0 ? 1 : 0;
            int ws = parsed.optInt("afterStartStop", 0) == 1 ? 0x01 : 0x00;
            device.put("pumpScene", scene);
            device.put("pumpWorkState", ws);
            device.put("pumpMode", mode);
            device.put("gear", gear);
            if (parsed.optInt("duration", 0) > 0) {
                device.put("duration", parsed.optInt("duration", 0));
            }
            patchGearMemory(device, scene, mode, gear);
            putPacketTimestamp(device, "lastDeviceWorkstateTs", parsed.optLong("timestamp", 0));
        });
    }

    private static boolean apply80(String deviceId, byte[] cab) throws JSONException {
        JSONObject parsed = MmcBleProtocol.parse80RealtimeMilk(cab);
        if (parsed == null) return false;
        return mutateDevice(deviceId, device -> {
            String side = sideForDevice(deviceId, new JSONObject(snapshotJson));
            double rawBandpower = Math.max(0, parsed.optDouble("bandpower", 0));
            double max = "L".equals(side)
                    ? (leftBandpowerMax = Math.max(leftBandpowerMax, rawBandpower))
                    : (rightBandpowerMax = Math.max(rightBandpowerMax, rawBandpower));
            double normalized = max > 0 ? rawBandpower / max : 0;
            double storedBandpower = rawBandpower < 500 ? 0 : normalized;
            device.put("flowFloat", parsed.optDouble("flowFloat", 0));
            device.put("milkMl", parsed.optDouble("milkMlX10", 0) / 10.0);
            device.put("milkFlag", parsed.optInt("milkFlag", 0));
            device.put("moFlag", parsed.optInt("moFlag", 0));
            device.put("bandpower", storedBandpower);
            device.put("pitch", parsed.optDouble("pitchX10", 0) / 10.0);
            device.put("roll", parsed.optDouble("rollX10", 0) / 10.0);
            device.put("pressureCh1", parsed.optDouble("pressureCh1X10", 0) / 10.0);
            device.put("pressureCh2", parsed.optDouble("pressureCh2X10", 0) / 10.0);
            putPacketTimestamp(device, "lastDeviceProcessTs", parsed.optLong("timestamp", 0));
        });
    }

    private static boolean applyBF(String deviceId, byte[] cab) throws JSONException {
        JSONObject parsed = MmcBleProtocol.parseBFEndRunResponse(cab);
        if (parsed == null) return false;
        return mutateDevice(deviceId, device -> {
            device.put("finalMilkMl", parsed.optDouble("milkMlX10", 0) / 10.0);
        });
    }

    private static boolean applyFE(String deviceId) throws JSONException {
        return mutateDevice(deviceId, device -> {
            device.put("pumpWorkState", 0);
        });
    }

    private static boolean mutateDevice(String deviceId, DeviceMutator mutator) throws JSONException {
        if (deviceId == null || deviceId.isEmpty()) return false;
        synchronized (LOCK) {
            JSONObject root = new JSONObject(snapshotJson);
            String side = sideForDevice(deviceId, root);
            if (side == null) return false;
            JSONObject device = root.optJSONObject(side);
            if (device == null) return false;
            mutator.mutate(device);
            snapshotJson = root.toString();
            return true;
        }
    }

    private static String sideForDevice(String deviceId, JSONObject root) {
        JSONObject left = root.optJSONObject("L");
        if (left != null && deviceId.equals(left.optString("deviceId", ""))) return "L";
        JSONObject right = root.optJSONObject("R");
        if (right != null && deviceId.equals(right.optString("deviceId", ""))) return "R";
        return null;
    }

    private static void putPacketTimestamp(JSONObject device, String key, long seconds) throws JSONException {
        if (seconds <= 0) return;
        device.put(key, new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US) {{
            setTimeZone(java.util.TimeZone.getTimeZone("UTC"));
        }}.format(new java.util.Date(seconds * 1000L)));
    }

    private static int clamp(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }

    static String getDeviceIdForSide(String side) {
        synchronized (LOCK) {
            try {
                JSONObject root = new JSONObject(snapshotJson);
                JSONObject device = root.optJSONObject(side);
                return device != null ? device.optString("deviceId", "") : "";
            } catch (JSONException ignored) {
                return "";
            }
        }
    }

    static JSONObject getDeviceForSideCopy(String side) {
        synchronized (LOCK) {
            try {
                JSONObject root = new JSONObject(snapshotJson);
                JSONObject device = root.optJSONObject(side);
                return device != null ? new JSONObject(device.toString()) : null;
            } catch (JSONException ignored) {
                return null;
            }
        }
    }

    static boolean updateAfterPumpParams(String deviceId, int mode, int gear, int workState, int scene) {
        try {
            return mutateDevice(deviceId, device -> {
                device.put("pumpMode", clamp(mode, 0, 2));
                device.put("gear", clamp(gear, 0, 14));
                device.put("pumpWorkState", workState == 1 ? 1 : 0);
                device.put("pumpScene", scene == 1 ? 1 : 0);
                patchGearMemory(device, scene, mode, gear);
            });
        } catch (JSONException ignored) {
            return false;
        }
    }

    static boolean copyAiMemoryFromCalib(String side) {
        synchronized (LOCK) {
            try {
                JSONObject root = new JSONObject(snapshotJson);
                JSONObject device = root.optJSONObject(side);
                if (device == null) return false;
                JSONObject calib = device.optJSONObject("pumpGearCalib");
                if (calib == null) return false;
                JSONObject ai = new JSONObject();
                if (calib.has("stimulate")) ai.put("stimulate", calib.optInt("stimulate"));
                if (calib.has("deep")) ai.put("deep", calib.optInt("deep"));
                device.put("pumpGearMemoryAi", ai);
                snapshotJson = root.toString();
                return true;
            } catch (JSONException ignored) {
                return false;
            }
        }
    }

    static boolean copyManualMemoryFromAi(String side) {
        synchronized (LOCK) {
            try {
                JSONObject root = new JSONObject(snapshotJson);
                JSONObject device = root.optJSONObject(side);
                if (device == null) return false;
                JSONObject ai = device.optJSONObject("pumpGearMemoryAi");
                if (ai == null) return false;
                JSONObject manual = new JSONObject();
                if (ai.has("stimulate")) manual.put("stimulate", ai.optInt("stimulate"));
                if (ai.has("deep")) manual.put("deep", ai.optInt("deep"));
                device.put("pumpGearMemoryManual", manual);
                snapshotJson = root.toString();
                return true;
            } catch (JSONException ignored) {
                return false;
            }
        }
    }

    static int readGearFromMemory(JSONObject device, int scene, int mode, int fallback) {
        int clampedFallback = clamp(fallback, 0, 14);
        if (device == null) return clampedFallback;
        JSONObject memory = device.optJSONObject(scene == 1 ? "pumpGearMemoryAi" : "pumpGearMemoryManual");
        if (memory == null) return clampedFallback;
        int gear;
        if (mode == 0) gear = memory.optInt("stimulate", clampedFallback);
        else if (mode == 1) gear = memory.optInt("deep", clampedFallback);
        else if (memory.has("stimulate")) gear = memory.optInt("stimulate", clampedFallback);
        else gear = memory.optInt("deep", clampedFallback);
        return clamp(gear, 0, 14);
    }

    private static void patchGearMemory(JSONObject device, int scene, int mode, int gear) throws JSONException {
        JSONObject memory = device.optJSONObject(scene == 1 ? "pumpGearMemoryAi" : "pumpGearMemoryManual");
        if (memory == null) memory = new JSONObject();
        int clampedGear = clamp(gear, 0, 14);
        if (mode == 0) memory.put("stimulate", clampedGear);
        else if (mode == 1) memory.put("deep", clampedGear);
        else {
            memory.put("stimulate", clampedGear);
            memory.put("deep", clampedGear);
        }
        device.put(scene == 1 ? "pumpGearMemoryAi" : "pumpGearMemoryManual", memory);
    }

    private interface DeviceMutator {
        void mutate(JSONObject device) throws JSONException;
    }
}
