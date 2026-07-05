package com.momcozymai.app;

import android.Manifest;
import android.annotation.SuppressLint;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanResult;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.provider.Settings;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.Permission;
import com.getcapacitor.annotation.PermissionCallback;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@CapacitorPlugin(
        name = "MmcBle",
        permissions = {
                @Permission(alias = "scan", strings = { Manifest.permission.BLUETOOTH_SCAN }),
                @Permission(alias = "connect", strings = { Manifest.permission.BLUETOOTH_CONNECT }),
                @Permission(alias = "location", strings = { Manifest.permission.ACCESS_FINE_LOCATION })
        }
)
public class MmcBlePlugin extends Plugin {
    private static final UUID CLIENT_CHARACTERISTIC_CONFIG =
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");
    private static final long SCAN_STOP_GRACE_MS = 800;

    private final Map<String, BluetoothGatt> gatts = new HashMap<>();
    private final Map<String, Set<String>> notifyKeys = new HashMap<>();
    private final Map<String, PluginCall> connectCalls = new HashMap<>();
    private final Map<String, PluginCall> readCalls = new HashMap<>();
    private final Map<String, PluginCall> writeCalls = new HashMap<>();
    private final Map<String, PluginCall> notifyCalls = new HashMap<>();
    private final Map<String, PendingProtocolReq> protocolReqs = new HashMap<>();
    private ScanCallback scanCallback;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private long lastScanStartElapsedMs = 0;
    private final Runnable pendingStopScan = this::stopScanNow;

    @PluginMethod
    public void initialize(PluginCall call) {
        if (hasRequiredBlePermissions()) {
            call.resolve();
            return;
        }
        if (Build.VERSION.SDK_INT >= 31) {
            requestPermissionForAliases(new String[] { "scan", "connect" }, call, "blePermissionCallback");
        } else {
            requestPermissionForAlias("location", call, "blePermissionCallback");
        }
    }

    @PermissionCallback
    private void blePermissionCallback(PluginCall call) {
        if (hasRequiredBlePermissions()) call.resolve();
        else call.reject("Bluetooth permission denied");
    }

    @PluginMethod
    public void requestLEScan(PluginCall call) {
        if (!hasRequiredBlePermissions()) {
            call.reject("Bluetooth permission not granted");
            return;
        }
        BluetoothAdapter adapter = getAdapter();
        if (adapter == null || !adapter.isEnabled()) {
            call.reject("Bluetooth is disabled");
            return;
        }
        BluetoothLeScanner scanner = adapter.getBluetoothLeScanner();
        if (scanner == null) {
            call.reject("Bluetooth LE scanner is unavailable");
            return;
        }
        if (scanCallback != null) {
            mainHandler.removeCallbacks(pendingStopScan);
            call.resolve();
            return;
        }

        scanCallback = new ScanCallback() {
            @Override
            public void onScanResult(int callbackType, ScanResult result) {
                emitScanResult(result);
            }

            @Override
            public void onBatchScanResults(List<ScanResult> results) {
                for (ScanResult result : results) emitScanResult(result);
            }

            @Override
            public void onScanFailed(int errorCode) {
                scanCallback = null;
                JSObject data = new JSObject();
                data.put("errorCode", errorCode);
                notifyListeners("scanFailed", data);
            }
        };
        long delayMs = Math.max(0, SCAN_STOP_GRACE_MS - (SystemClock.elapsedRealtime() - lastScanStartElapsedMs));
        if (delayMs > 0) {
            mainHandler.postDelayed(() -> startScan(scanner, call), delayMs);
        } else {
            startScan(scanner, call);
        }
    }

    @PluginMethod
    public void stopLEScan(PluginCall call) {
        stopScanInternal();
        call.resolve();
    }

    @PluginMethod
    public void getConnectedDevices(PluginCall call) {
        if (!hasRequiredBlePermissions()) {
            call.reject("Bluetooth permission not granted");
            return;
        }
        BluetoothManager manager = getManager();
        JSArray out = new JSArray();
        if (manager != null) {
            try {
                for (BluetoothDevice device : manager.getConnectedDevices(BluetoothProfile.GATT)) {
                    out.put(deviceToJson(device));
                }
            } catch (SecurityException e) {
                call.reject("Bluetooth connect permission denied", e);
                return;
            }
        }
        JSObject ret = new JSObject();
        ret.put("devices", out);
        call.resolve(ret);
    }

    @PluginMethod
    public void connect(PluginCall call) {
        String deviceId = call.getString("deviceId");
        if (deviceId == null || deviceId.isEmpty()) {
            call.reject("deviceId is required");
            return;
        }
        if (!hasRequiredBlePermissions()) {
            call.reject("Bluetooth permission not granted");
            return;
        }
        BluetoothAdapter adapter = getAdapter();
        if (adapter == null || !adapter.isEnabled()) {
            call.reject("Bluetooth is disabled");
            return;
        }
        try {
            mainHandler.removeCallbacks(pendingStopScan);
            stopScanNow();
            BluetoothGatt previous = gatts.remove(deviceId);
            if (previous != null) {
                try {
                    previous.disconnect();
                    previous.close();
                } catch (SecurityException ignored) {
                }
            }
            BluetoothDevice device = adapter.getRemoteDevice(deviceId);
            connectCalls.put(deviceId, call);
            BluetoothGatt gatt = device.connectGatt(getContext(), false, new GattCallback(deviceId), BluetoothDevice.TRANSPORT_LE);
            gatts.put(deviceId, gatt);
        } catch (IllegalArgumentException | SecurityException e) {
            connectCalls.remove(deviceId);
            call.reject("Bluetooth connect failed", e);
        }
    }

    @PluginMethod
    public void disconnect(PluginCall call) {
        String deviceId = call.getString("deviceId");
        if (deviceId == null || deviceId.isEmpty()) {
            call.reject("deviceId is required");
            return;
        }
        BluetoothGatt gatt = gatts.remove(deviceId);
        notifyKeys.remove(deviceId);
        if (gatt != null) {
            try {
                gatt.disconnect();
                gatt.close();
            } catch (SecurityException ignored) {
            }
        }
        call.resolve();
    }

    @PluginMethod
    public void read(PluginCall call) {
        CharacteristicRef ref = requireCharacteristic(call);
        if (ref == null) return;
        String key = characteristicKey(ref);
        readCalls.put(key, call);
        try {
            if (!ref.gatt.readCharacteristic(ref.characteristic)) {
                readCalls.remove(key);
                call.reject("readCharacteristic returned false");
            }
        } catch (SecurityException e) {
            readCalls.remove(key);
            call.reject("Bluetooth read permission denied", e);
        }
    }

    @PluginMethod
    public void write(PluginCall call) {
        writeInternal(call, false);
    }

    @PluginMethod
    public void writeWithoutResponse(PluginCall call) {
        writeInternal(call, true);
    }

    @PluginMethod
    public void startNotifications(PluginCall call) {
        CharacteristicRef ref = requireCharacteristic(call);
        if (ref == null) return;
        BluetoothGattDescriptor descriptor = ref.characteristic.getDescriptor(CLIENT_CHARACTERISTIC_CONFIG);
        if (descriptor == null) {
            call.reject("CCCD descriptor not found");
            return;
        }
        String key = characteristicKey(ref);
        try {
            if (!ref.gatt.setCharacteristicNotification(ref.characteristic, true)) {
                call.reject("setCharacteristicNotification returned false");
                return;
            }
            descriptor.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
            notifyCalls.put(key, call);
            if (!ref.gatt.writeDescriptor(descriptor)) {
                notifyCalls.remove(key);
                call.reject("writeDescriptor returned false");
            }
        } catch (SecurityException e) {
            notifyCalls.remove(key);
            call.reject("Bluetooth notify permission denied", e);
        }
    }

    @PluginMethod
    public void stopNotifications(PluginCall call) {
        CharacteristicRef ref = requireCharacteristic(call);
        if (ref == null) return;
        notifyKeys.computeIfAbsent(ref.deviceId, k -> new HashSet<>()).remove(characteristicKey(ref));
        try {
            ref.gatt.setCharacteristicNotification(ref.characteristic, false);
        } catch (SecurityException ignored) {
        }
        call.resolve();
    }

    @PluginMethod
    public void openBluetoothSettings(PluginCall call) {
        Intent intent = new Intent(Settings.ACTION_BLUETOOTH_SETTINGS);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        getContext().startActivity(intent);
        call.resolve();
    }

    @PluginMethod
    public void openAppSettings(PluginCall call) {
        Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
        intent.setData(Uri.parse("package:" + getContext().getPackageName()));
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        getContext().startActivity(intent);
        call.resolve();
    }

    @PluginMethod
    public void nativeSetPumpParams(PluginCall call) {
        String deviceId = requireDeviceId(call);
        if (deviceId == null) return;
        int startStop = clamp(call.getInt("startStop", 0), 0, 1);
        int mode = clamp(call.getInt("mode", 0), 0, 2);
        int gear = clamp(call.getInt("gear", 0), 0, 14);
        int scene = clamp(call.getInt("scene", 0), 0, 1);
        sendProtocolReq(call, deviceId, MmcBleProtocol.buildB1SetPumpParams(startStop, mode, gear, scene));
    }

    @PluginMethod
    public void nativePowerOff(PluginCall call) {
        String deviceId = requireDeviceId(call);
        if (deviceId == null) return;
        int reboot = clamp(call.getInt("reboot", 0), 0, 1);
        sendProtocolReq(call, deviceId, MmcBleProtocol.buildFEPowerOff(reboot));
    }

    @PluginMethod
    public void nativeEndRun(PluginCall call) {
        String deviceId = requireDeviceId(call);
        if (deviceId == null) return;
        sendProtocolReq(call, deviceId, MmcBleProtocol.buildBFEndRun());
    }

    @PluginMethod
    public void nativeGetDeviceInfo(PluginCall call) {
        String deviceId = requireDeviceId(call);
        if (deviceId == null) return;
        sendProtocolReq(call, deviceId, MmcBleProtocol.buildF0GetDeviceInfo());
    }

    @PluginMethod
    public void nativeSetRtc(PluginCall call) {
        String deviceId = requireDeviceId(call);
        if (deviceId == null) return;
        long utcSeconds = Math.max(0L, call.getLong("utcSeconds", System.currentTimeMillis() / 1000L));
        sendProtocolReq(call, deviceId, MmcBleProtocol.buildF2SetRtc(utcSeconds));
    }

    @PluginMethod
    public void nativeQueryDeviceStatus(PluginCall call) {
        String deviceId = requireDeviceId(call);
        if (deviceId == null) return;
        sendProtocolReq(call, deviceId, MmcBleProtocol.buildE1QueryDeviceStatus());
    }

    @PluginMethod
    public void nativeAdjustGearForSide(PluginCall call) {
        String side = normalizeSide(call.getString("side"));
        if (side == null) {
            call.reject("side must be L or R");
            return;
        }
        int delta = call.getInt("delta", 0);
        JSONObject device = DeviceNativeStateStore.getDeviceForSideCopy(side);
        String deviceId = DeviceNativeStateStore.getDeviceIdForSide(side);
        if (device == null || deviceId.isEmpty() || !device.optBoolean("connected", false)) {
            call.reject("side device is not connected");
            return;
        }
        int mode = clamp(device.optInt("pumpMode", 0), 0, 2);
        int gear = clamp(device.optInt("gear", 0) + delta, 0, 14);
        int scene = clamp(device.optInt("pumpScene", 0), 0, 1);
        int ss = device.optInt("pumpWorkState", 0) == 1 ? 1 : 0;
        sendProtocolReq(call, deviceId, MmcBleProtocol.buildB1SetPumpParams(ss, mode, gear, scene),
                () -> DeviceNativeStateStore.updateAfterPumpParams(deviceId, mode, gear, ss, scene));
    }

    @PluginMethod
    public void nativeSetModeForSide(PluginCall call) {
        String side = normalizeSide(call.getString("side"));
        if (side == null) {
            call.reject("side must be L or R");
            return;
        }
        int mode = clamp(call.getInt("mode", 0), 0, 2);
        JSONObject device = DeviceNativeStateStore.getDeviceForSideCopy(side);
        String deviceId = DeviceNativeStateStore.getDeviceIdForSide(side);
        if (device == null || deviceId.isEmpty() || !device.optBoolean("connected", false)) {
            call.reject("side device is not connected");
            return;
        }
        int scene = clamp(device.optInt("pumpScene", 0), 0, 1);
        int fallback = clamp(device.optInt("gear", 0), 0, 14);
        int gear = DeviceNativeStateStore.readGearFromMemory(device, scene, mode, fallback);
        int ss = device.optInt("pumpWorkState", 0) == 1 ? 1 : 0;
        sendProtocolReq(call, deviceId, MmcBleProtocol.buildB1SetPumpParams(ss, mode, gear, scene),
                () -> DeviceNativeStateStore.updateAfterPumpParams(deviceId, mode, gear, ss, scene));
    }

    @PluginMethod
    public void nativeSetSceneForSide(PluginCall call) {
        String side = normalizeSide(call.getString("side"));
        if (side == null) {
            call.reject("side must be L or R");
            return;
        }
        int scene = clamp(call.getInt("scene", 0), 0, 1);
        JSONObject device = DeviceNativeStateStore.getDeviceForSideCopy(side);
        String deviceId = DeviceNativeStateStore.getDeviceIdForSide(side);
        if (device == null || deviceId.isEmpty() || !device.optBoolean("connected", false)) {
            call.reject("side device is not connected");
            return;
        }
        if (scene == 1) DeviceNativeStateStore.copyAiMemoryFromCalib(side);
        else DeviceNativeStateStore.copyManualMemoryFromAi(side);
        JSONObject refreshed = DeviceNativeStateStore.getDeviceForSideCopy(side);
        if (refreshed != null) device = refreshed;
        int mode = scene == 1 ? 0 : clamp(device.optInt("pumpMode", 0), 0, 2);
        int fallback = clamp(device.optInt("gear", 0), 0, 14);
        int gear = scene == 1 && device.optJSONObject("pumpGearCalib") != null
                ? clamp(device.optJSONObject("pumpGearCalib").optInt("stimulate", fallback), 0, 14)
                : DeviceNativeStateStore.readGearFromMemory(device, scene, mode, fallback);
        int ss = 1;
        sendProtocolReq(call, deviceId, MmcBleProtocol.buildB1SetPumpParams(ss, mode, gear, scene),
                () -> DeviceNativeStateStore.updateAfterPumpParams(deviceId, mode, gear, ss, scene));
    }

    @PluginMethod
    public void nativeSetStartStopForSide(PluginCall call) {
        String side = normalizeSide(call.getString("side"));
        if (side == null) {
            call.reject("side must be L or R");
            return;
        }
        int startStop = clamp(call.getInt("startStop", 0), 0, 1);
        JSONObject device = DeviceNativeStateStore.getDeviceForSideCopy(side);
        String deviceId = DeviceNativeStateStore.getDeviceIdForSide(side);
        if (device == null || deviceId.isEmpty() || !device.optBoolean("connected", false)) {
            call.reject("side device is not connected");
            return;
        }
        int mode = clamp(device.optInt("pumpMode", 0), 0, 2);
        int scene = clamp(device.optInt("pumpScene", 0), 0, 1);
        int fallback = clamp(device.optInt("gear", 0), 0, 14);
        int gear = DeviceNativeStateStore.readGearFromMemory(device, scene, mode, fallback);
        sendProtocolReq(call, deviceId, MmcBleProtocol.buildB1SetPumpParams(startStop, mode, gear, scene),
                () -> DeviceNativeStateStore.updateAfterPumpParams(deviceId, mode, gear, startStop, scene));
    }

    @Override
    protected void handleOnDestroy() {
        mainHandler.removeCallbacks(pendingStopScan);
        stopScanNow();
        for (BluetoothGatt gatt : gatts.values()) {
            try {
                gatt.close();
            } catch (Exception ignored) {
            }
        }
        gatts.clear();
        notifyKeys.clear();
        for (PendingProtocolReq pending : protocolReqs.values()) pending.cancelTimeout();
        protocolReqs.clear();
    }

    private String requireDeviceId(PluginCall call) {
        String deviceId = call.getString("deviceId");
        if (deviceId == null || deviceId.isEmpty()) {
            call.reject("deviceId is required");
            return null;
        }
        return deviceId;
    }

    private void sendProtocolReq(PluginCall call, String deviceId, byte[] packet) {
        sendProtocolReq(call, deviceId, packet, null);
    }

    private void sendProtocolReq(PluginCall call, String deviceId, byte[] packet, AckSideEffect ackSideEffect) {
        int cid = MmcBleProtocol.getCidFromReqPacket(packet);
        if (cid < 0) {
            call.reject("invalid protocol packet");
            return;
        }
        String key = protocolReqKey(deviceId, cid);
        if (protocolReqs.containsKey(key)) {
            call.reject("duplicate pending protocol req cid=0x" + Integer.toHexString(cid));
            return;
        }
        PendingProtocolReq pending = new PendingProtocolReq(deviceId, cid, packet, call, ackSideEffect);
        protocolReqs.put(key, pending);
        pending.sendNext();
    }

    private boolean writePumpProtocolPacket(String deviceId, byte[] packet) {
        BluetoothGatt gatt = gatts.get(deviceId);
        if (gatt == null) return false;
        BluetoothGattService service = gatt.getService(parseUuid("0000af00-0000-1000-8000-00805f9b34fb"));
        if (service == null) return false;
        BluetoothGattCharacteristic characteristic = service.getCharacteristic(parseUuid("0000af01-0000-1000-8000-00805f9b34fb"));
        if (characteristic == null) return false;
        characteristic.setWriteType(BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE);
        characteristic.setValue(packet);
        try {
            return gatt.writeCharacteristic(characteristic);
        } catch (SecurityException e) {
            return false;
        }
    }

    private void settleProtocolReq(String deviceId, MmcBleProtocol.ParsedFrame frame) {
        if (frame.ct != 0x01 && frame.ct != 0x02) return;
        String key = protocolReqKey(deviceId, frame.cid);
        PendingProtocolReq pending = protocolReqs.remove(key);
        if (pending == null) return;
        pending.cancelTimeout();
        if (frame.ct == 0x01 && pending.ackSideEffect != null && pending.ackSideEffect.run()) {
            JSObject state = new JSObject();
            state.put("snapshotJson", DeviceNativeStateStore.getSnapshotJson());
            notifyListeners("nativeDeviceStateChanged", state);
        }
        JSObject ret = new JSObject();
        ret.put("ct", frame.ct);
        ret.put("cid", frame.cid);
        ret.put("value", bytesToArray(frame.cab));
        ret.put("snapshotJson", DeviceNativeStateStore.getSnapshotJson());
        pending.call.resolve(ret);
    }

    private String protocolReqKey(String deviceId, int cid) {
        return deviceId + "|" + cid;
    }

    private int clamp(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }

    private String normalizeSide(String side) {
        if ("L".equals(side) || "R".equals(side)) return side;
        return null;
    }

    private void writeInternal(PluginCall call, boolean withoutResponse) {
        CharacteristicRef ref = requireCharacteristic(call);
        if (ref == null) return;
        byte[] value = readValue(call);
        if (value == null) return;
        String key = characteristicKey(ref);
        ref.characteristic.setWriteType(withoutResponse
                ? BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
                : BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT);
        ref.characteristic.setValue(value);
        try {
            if (!ref.gatt.writeCharacteristic(ref.characteristic)) {
                call.reject("writeCharacteristic returned false");
                return;
            }
            if (withoutResponse) call.resolve();
            else writeCalls.put(key, call);
        } catch (SecurityException e) {
            call.reject("Bluetooth write permission denied", e);
        }
    }

    private boolean hasRequiredBlePermissions() {
        if (Build.VERSION.SDK_INT >= 31) {
            return ContextCompat.checkSelfPermission(getContext(), Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
                    && ContextCompat.checkSelfPermission(getContext(), Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED;
        }
        return ContextCompat.checkSelfPermission(getContext(), Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
    }

    private BluetoothManager getManager() {
        return (BluetoothManager) getContext().getSystemService(Context.BLUETOOTH_SERVICE);
    }

    private BluetoothAdapter getAdapter() {
        BluetoothManager manager = getManager();
        return manager != null ? manager.getAdapter() : null;
    }

    private void stopScanInternal() {
        if (scanCallback == null) return;
        mainHandler.removeCallbacks(pendingStopScan);
        mainHandler.postDelayed(pendingStopScan, SCAN_STOP_GRACE_MS);
    }

    private void startScan(BluetoothLeScanner scanner, PluginCall call) {
        if (scanCallback == null) {
            call.resolve();
            return;
        }
        try {
            scanner.startScan(scanCallback);
            lastScanStartElapsedMs = SystemClock.elapsedRealtime();
            call.resolve();
        } catch (SecurityException e) {
            scanCallback = null;
            call.reject("Bluetooth scan permission denied", e);
        }
    }

    private void stopScanNow() {
        if (scanCallback == null) return;
        BluetoothAdapter adapter = getAdapter();
        BluetoothLeScanner scanner = adapter != null ? adapter.getBluetoothLeScanner() : null;
        if (scanner != null) {
            try {
                scanner.stopScan(scanCallback);
            } catch (SecurityException ignored) {
            }
        }
        scanCallback = null;
    }

    @SuppressLint("MissingPermission")
    private void emitScanResult(ScanResult result) {
        BluetoothDevice device = result.getDevice();
        JSObject data = new JSObject();
        data.put("device", deviceToJson(device));
        data.put("rssi", result.getRssi());
        if (result.getScanRecord() != null && result.getScanRecord().getDeviceName() != null) {
            data.put("localName", result.getScanRecord().getDeviceName());
        }
        notifyListeners("scanResult", data);
    }

    @SuppressLint("MissingPermission")
    private JSObject deviceToJson(BluetoothDevice device) {
        JSObject obj = new JSObject();
        obj.put("deviceId", device.getAddress());
        if (device.getName() != null) obj.put("name", device.getName());
        return obj;
    }

    private CharacteristicRef requireCharacteristic(PluginCall call) {
        String deviceId = call.getString("deviceId");
        String serviceUUID = call.getString("serviceUUID");
        String characteristicUUID = call.getString("characteristicUUID");
        if (deviceId == null || serviceUUID == null || characteristicUUID == null) {
            call.reject("deviceId, serviceUUID and characteristicUUID are required");
            return null;
        }
        BluetoothGatt gatt = gatts.get(deviceId);
        if (gatt == null) {
            call.reject("Device is not connected");
            return null;
        }
        BluetoothGattService service = gatt.getService(parseUuid(serviceUUID));
        if (service == null) {
            call.reject("GATT service not found: " + serviceUUID);
            return null;
        }
        BluetoothGattCharacteristic characteristic = service.getCharacteristic(parseUuid(characteristicUUID));
        if (characteristic == null) {
            call.reject("GATT characteristic not found: " + characteristicUUID);
            return null;
        }
        return new CharacteristicRef(deviceId, serviceUUID, characteristicUUID, gatt, characteristic);
    }

    private UUID parseUuid(String uuid) {
        if (uuid.length() == 4) {
            return UUID.fromString("0000" + uuid.toLowerCase(Locale.US) + "-0000-1000-8000-00805f9b34fb");
        }
        return UUID.fromString(uuid);
    }

    private byte[] readValue(PluginCall call) {
        JSArray arr = call.getArray("value");
        if (arr == null) {
            call.reject("value is required");
            return null;
        }
        try {
            List<Object> list = arr.toList();
            byte[] out = new byte[list.size()];
            for (int i = 0; i < list.size(); i++) {
                Object item = list.get(i);
                if (!(item instanceof Number)) {
                    call.reject("value must be a number array");
                    return null;
                }
                out[i] = (byte) (((Number) item).intValue() & 0xff);
            }
            return out;
        } catch (JSONException e) {
            call.reject("Invalid value array", e);
            return null;
        }
    }

    private JSArray bytesToArray(byte[] value) {
        JSArray arr = new JSArray();
        if (value == null) return arr;
        for (byte b : value) arr.put(b & 0xff);
        return arr;
    }

    private String characteristicKey(CharacteristicRef ref) {
        return ref.deviceId
                + "|"
                + parseUuid(ref.serviceUUID).toString().toLowerCase(Locale.US)
                + "|"
                + parseUuid(ref.characteristicUUID).toString().toLowerCase(Locale.US);
    }

    private final class GattCallback extends BluetoothGattCallback {
        private final String deviceId;

        private GattCallback(String deviceId) {
            this.deviceId = deviceId;
        }

        @Override
        public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {
            if (gatts.get(deviceId) != gatt) {
                if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    try {
                        gatt.close();
                    } catch (Exception ignored) {
                    }
                }
                return;
            }
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                try {
                    gatt.discoverServices();
                } catch (SecurityException e) {
                    PluginCall call = connectCalls.remove(deviceId);
                    if (call != null) call.reject("discoverServices permission denied", e);
                }
                return;
            }
            if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                if (gatts.get(deviceId) == gatt) gatts.remove(deviceId);
                notifyKeys.remove(deviceId);
                rejectProtocolReqsForDevice(deviceId, "Bluetooth disconnected");
                PluginCall call = connectCalls.remove(deviceId);
                if (call != null) call.reject("Bluetooth disconnected before services were discovered");
                JSObject data = new JSObject();
                data.put("deviceId", deviceId);
                data.put("status", status);
                notifyListeners("disconnected", data);
                try {
                    gatt.close();
                } catch (Exception ignored) {
                }
            }
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status) {
            if (gatts.get(deviceId) != gatt) return;
            PluginCall call = connectCalls.remove(deviceId);
            if (call == null) return;
            if (status == BluetoothGatt.GATT_SUCCESS) call.resolve();
            else call.reject("GATT service discovery failed status=" + status);
        }

        @Override
        public void onCharacteristicRead(@NonNull BluetoothGatt gatt, @NonNull BluetoothGattCharacteristic characteristic, byte[] value, int status) {
            CharacteristicRef ref = fromCharacteristic(gatt, characteristic);
            PluginCall call = readCalls.remove(characteristicKey(ref));
            if (call == null) return;
            if (status == BluetoothGatt.GATT_SUCCESS) {
                JSObject ret = new JSObject();
                ret.put("value", bytesToArray(value));
                call.resolve(ret);
            } else {
                call.reject("GATT read failed status=" + status);
            }
        }

        @Override
        public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) {
            onCharacteristicRead(gatt, characteristic, characteristic.getValue(), status);
        }

        @Override
        public void onCharacteristicWrite(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) {
            CharacteristicRef ref = fromCharacteristic(gatt, characteristic);
            PluginCall call = writeCalls.remove(characteristicKey(ref));
            if (call == null) return;
            if (status == BluetoothGatt.GATT_SUCCESS) call.resolve();
            else call.reject("GATT write failed status=" + status);
        }

        @Override
        public void onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status) {
            CharacteristicRef ref = fromCharacteristic(gatt, descriptor.getCharacteristic());
            PluginCall call = notifyCalls.remove(characteristicKey(ref));
            if (call == null) return;
            if (status == BluetoothGatt.GATT_SUCCESS) {
                notifyKeys.computeIfAbsent(deviceId, k -> new HashSet<>()).add(characteristicKey(ref));
                call.resolve();
            } else {
                call.reject("GATT descriptor write failed status=" + status);
            }
        }

        @Override
        public void onCharacteristicChanged(@NonNull BluetoothGatt gatt, @NonNull BluetoothGattCharacteristic characteristic, byte[] value) {
            CharacteristicRef ref = fromCharacteristic(gatt, characteristic);
            if (!notifyKeys.getOrDefault(deviceId, new HashSet<>()).contains(characteristicKey(ref))) return;
            MmcBleProtocol.ParsedFrame frame = MmcBleProtocol.parseFrame(value);
            if (frame != null) {
                PumpAgentNativeStore.markDeviceSourceByPacket(frame.cid, deviceId);
                if (DeviceNativeStateStore.applyProtocolFrame(deviceId, value)) {
                    JSObject state = new JSObject();
                    state.put("snapshotJson", DeviceNativeStateStore.getSnapshotJson());
                    notifyListeners("nativeDeviceStateChanged", state);
                }
                settleProtocolReq(deviceId, frame);
            }
            JSObject data = new JSObject();
            data.put("deviceId", deviceId);
            data.put("serviceUUID", ref.serviceUUID);
            data.put("characteristicUUID", ref.characteristicUUID);
            data.put("value", bytesToArray(value));
            notifyListeners("notification", data);
        }

        @Override
        public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
            onCharacteristicChanged(gatt, characteristic, characteristic.getValue());
        }
    }

    private void rejectProtocolReqsForDevice(String deviceId, String reason) {
        Set<String> keys = new HashSet<>();
        for (String key : protocolReqs.keySet()) {
            if (key.startsWith(deviceId + "|")) keys.add(key);
        }
        for (String key : keys) {
            PendingProtocolReq pending = protocolReqs.remove(key);
            if (pending == null) continue;
            pending.cancelTimeout();
            pending.call.reject(reason);
        }
    }

    private final class PendingProtocolReq {
        private static final int MAX_ATTEMPTS = 3;
        private static final long TIMEOUT_MS = 3000L;
        final String deviceId;
        final int cid;
        final byte[] packet;
        final PluginCall call;
        final AckSideEffect ackSideEffect;
        int attempts;
        Runnable timeoutRunnable;

        PendingProtocolReq(String deviceId, int cid, byte[] packet, PluginCall call, AckSideEffect ackSideEffect) {
            this.deviceId = deviceId;
            this.cid = cid;
            this.packet = packet;
            this.call = call;
            this.ackSideEffect = ackSideEffect;
        }

        void sendNext() {
            attempts += 1;
            if (!writePumpProtocolPacket(deviceId, packet)) {
                protocolReqs.remove(protocolReqKey(deviceId, cid));
                call.reject("protocol write failed");
                return;
            }
            timeoutRunnable = () -> {
                if (!protocolReqs.containsKey(protocolReqKey(deviceId, cid))) return;
                if (attempts >= MAX_ATTEMPTS) {
                    protocolReqs.remove(protocolReqKey(deviceId, cid));
                    call.reject("no response after " + MAX_ATTEMPTS + " attempts");
                    return;
                }
                sendNext();
            };
            mainHandler.postDelayed(timeoutRunnable, TIMEOUT_MS);
        }

        void cancelTimeout() {
            if (timeoutRunnable != null) {
                mainHandler.removeCallbacks(timeoutRunnable);
                timeoutRunnable = null;
            }
        }
    }

    private interface AckSideEffect {
        boolean run();
    }

    private CharacteristicRef fromCharacteristic(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
        BluetoothGattService service = characteristic.getService();
        return new CharacteristicRef(
                deviceIdFromGatt(gatt),
                service != null ? service.getUuid().toString() : "",
                characteristic.getUuid().toString(),
                gatt,
                characteristic
        );
    }

    @SuppressLint("MissingPermission")
    private String deviceIdFromGatt(BluetoothGatt gatt) {
        BluetoothDevice device = gatt.getDevice();
        return device != null ? device.getAddress() : "";
    }

    private static final class CharacteristicRef {
        final String deviceId;
        final String serviceUUID;
        final String characteristicUUID;
        final BluetoothGatt gatt;
        final BluetoothGattCharacteristic characteristic;

        CharacteristicRef(String deviceId, String serviceUUID, String characteristicUUID, BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
            this.deviceId = deviceId;
            this.serviceUUID = serviceUUID;
            this.characteristicUUID = characteristicUUID;
            this.gatt = gatt;
            this.characteristic = characteristic;
        }
    }
}
