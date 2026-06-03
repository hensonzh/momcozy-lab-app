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

    private interface DeviceMutator {
        void mutate(JSONObject device) throws JSONException;
    }
}
