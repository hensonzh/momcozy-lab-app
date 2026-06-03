package com.momcozymai.app;

import org.json.JSONException;
import org.json.JSONObject;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Arrays;

final class MmcBleProtocol {
    static final int CT_ACK = 0x01;
    static final int CT_NOTIFY = 0x03;
    static final int CT_DEVICE = 0x04;

    private static final int SOP = 0xaa;
    private static final int FCF = 0x55;
    private static final int CAL_MAX = 100;
    private static final int E1_CAB_MIN_LEN = 15;

    private MmcBleProtocol() {
    }

    static ParsedFrame parseFrame(byte[] buf) {
        if (buf == null || buf.length < 5) return null;
        if ((buf[0] & 0xff) != SOP || (buf[1] & 0xff) != FCF) return null;
        int cal = buf[4] & 0xff;
        if (cal > CAL_MAX || buf.length != 5 + cal + 1) return null;
        int expected = checksum8(buf, 0, buf.length - 1);
        if ((buf[buf.length - 1] & 0xff) != expected) return null;
        return new ParsedFrame(buf[2] & 0xff, buf[3] & 0xff, cal, Arrays.copyOfRange(buf, 5, 5 + cal));
    }

    static byte[] buildAck(int cid) {
        byte[] out = new byte[] { (byte) SOP, (byte) FCF, (byte) CT_ACK, (byte) (cid & 0xff), 0, 0 };
        out[5] = (byte) checksum8(out, 0, 5);
        return out;
    }

    static byte[] buildF0GetDeviceInfo() {
        return buildReq(0xf0, new byte[] { 0x00, 0x11, 0x55, (byte) 0xaa });
    }

    static byte[] buildF2SetRtc(long utcSeconds) {
        return buildReq(0xf2, u32le(utcSeconds));
    }

    static byte[] buildE1QueryDeviceStatus() {
        return buildReq(0xe1, new byte[0]);
    }

    static byte[] buildB1SetPumpParams(int startStop, int mode, int gear, int scene) {
        return buildReq(0xb1, new byte[] {
                (byte) (startStop & 0xff),
                (byte) (mode & 0xff),
                (byte) (gear & 0xff),
                (byte) (scene & 0xff)
        });
    }

    static byte[] buildBFEndRun() {
        return buildReq(0xbf, new byte[] { 0 });
    }

    static byte[] buildFEPowerOff(int reboot) {
        return buildReq(0xfe, new byte[] { (byte) (reboot & 0xff) });
    }

    static JSONObject parseF0DeviceInfo(byte[] cab) throws JSONException {
        if (cab == null || cab.length < 4) return null;
        JSONObject obj = new JSONObject();
        obj.put("productModel", cab[0] & 0xff);
        obj.put("hwPlatform", cab[1] & 0xff);
        obj.put("hwVersion", versionByteToString(cab[2] & 0xff));
        obj.put("softwareVersion", versionByteToString(cab[3] & 0xff));
        return obj;
    }

    static JSONObject parseE1DeviceStatus(byte[] cab) throws JSONException {
        if (cab == null || cab.length < 10) return null;
        ByteBuffer view = ByteBuffer.wrap(cab).order(ByteOrder.LITTLE_ENDIAN);
        JSONObject obj = new JSONObject();
        obj.put("bootTime", uint32(view, 0));
        obj.put("workMode", cab[4] & 0xff);
        obj.put("pumpMode", cab[5] & 0xff);
        obj.put("gear", cab[6] & 0xff);
        if (cab.length >= E1_CAB_MIN_LEN) {
            obj.put("scene", cab[7] & 0xff);
            obj.put("workState", cab[8] & 0xff);
            obj.put("batteryPct", cab[9] & 0xff);
            obj.put("charging", cab[10] & 0xff);
            obj.put("duration", view.getShort(11) & 0xffff);
            obj.put("pumpGearCalibStimulate", cab[13] & 0xff);
            obj.put("pumpGearCalibDeep", cab[14] & 0xff);
            return obj;
        }
        if (cab.length >= 11) {
            obj.put("scene", cab[7] & 0xff);
            obj.put("workState", cab[8] & 0xff);
            obj.put("batteryPct", cab[9] & 0xff);
            obj.put("charging", cab[10] & 0xff);
        } else {
            obj.put("scene", 0);
            obj.put("workState", cab[7] & 0xff);
            obj.put("batteryPct", cab[8] & 0xff);
            obj.put("charging", cab[9] & 0xff);
        }
        obj.put("duration", 0);
        obj.put("pumpGearCalibStimulate", 0);
        obj.put("pumpGearCalibDeep", 0);
        return obj;
    }

    static JSONObject parseD6Battery(byte[] cab) throws JSONException {
        if (cab == null || cab.length < 6) return null;
        JSONObject obj = new JSONObject();
        obj.put("timestamp", uint32(ByteBuffer.wrap(cab).order(ByteOrder.LITTLE_ENDIAN), 0));
        obj.put("charging", cab[4] & 0xff);
        obj.put("batteryPct", cab[5] & 0xff);
        return obj;
    }

    static JSONObject parse80RealtimeMilk(byte[] cab) throws JSONException {
        if (cab == null || cab.length < 0x17) return null;
        ByteBuffer view = ByteBuffer.wrap(cab).order(ByteOrder.LITTLE_ENDIAN);
        JSONObject obj = new JSONObject();
        obj.put("timestamp", uint32(view, 0));
        obj.put("flowFloat", view.getFloat(4));
        obj.put("milkMlX10", view.getShort(8) & 0xffff);
        obj.put("milkFlag", cab[10] & 0x01);
        obj.put("moFlag", (cab[10] & 0x02) >> 1);
        obj.put("bandpower", view.getFloat(11));
        obj.put("pitchX10", view.getShort(15));
        obj.put("rollX10", view.getShort(17));
        obj.put("pressureCh1X10", view.getShort(19) & 0xffff);
        obj.put("pressureCh2X10", view.getShort(21) & 0xffff);
        return obj;
    }

    static JSONObject parseBFEndRunResponse(byte[] cab) throws JSONException {
        if (cab == null || cab.length < 6) return null;
        ByteBuffer view = ByteBuffer.wrap(cab).order(ByteOrder.LITTLE_ENDIAN);
        JSONObject obj = new JSONObject();
        obj.put("timestamp", uint32(view, 0));
        obj.put("milkMlX10", view.getShort(4) & 0xffff);
        return obj;
    }

    static int getCidFromReqPacket(byte[] packet) {
        return packet != null && packet.length > 3 ? packet[3] & 0xff : -1;
    }

    private static byte[] buildReq(int cid, byte[] cab) {
        int cal = cab != null ? cab.length : 0;
        if (cal > CAL_MAX) throw new IllegalArgumentException("CAL > " + CAL_MAX);
        byte[] out = new byte[5 + cal + 1];
        out[0] = (byte) SOP;
        out[1] = (byte) FCF;
        out[2] = 0x00;
        out[3] = (byte) (cid & 0xff);
        out[4] = (byte) (cal & 0xff);
        if (cal > 0) System.arraycopy(cab, 0, out, 5, cal);
        out[out.length - 1] = (byte) checksum8(out, 0, out.length - 1);
        return out;
    }

    private static byte[] u32le(long value) {
        long v = value & 0xffffffffL;
        return new byte[] {
                (byte) (v & 0xff),
                (byte) ((v >> 8) & 0xff),
                (byte) ((v >> 16) & 0xff),
                (byte) ((v >> 24) & 0xff)
        };
    }

    private static long uint32(ByteBuffer view, int offset) {
        return view.getInt(offset) & 0xffffffffL;
    }

    private static int checksum8(byte[] data, int offset, int len) {
        int sum = 0;
        for (int i = offset; i < offset + len; i++) sum += data[i] & 0xff;
        return (~(sum & 0xff)) & 0xff;
    }

    private static String versionByteToString(int b) {
        return (b / 10) + "." + (b % 10);
    }

    static final class ParsedFrame {
        final int ct;
        final int cid;
        final int cal;
        final byte[] cab;

        ParsedFrame(int ct, int cid, int cal, byte[] cab) {
            this.ct = ct;
            this.cid = cid;
            this.cal = cal;
            this.cab = cab;
        }
    }
}
