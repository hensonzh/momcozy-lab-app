# BLE protocol fixtures

These fixtures freeze the current BLE packet behavior before the Flutter rewrite.

Sources of truth:

- `src/lib/bleProtocol.ts`
- `android/app/src/main/java/com/momcozymai/app/MmcBleProtocol.java`
- `doc/设备APP蓝牙通信协议.md`

The structured fixtures are:

- `req_golden_packets.json`: request/ACK packet encoding golden cases.
- `parse_frames.json`: full frame parsing, parser output, and invalid frame fallbacks.
- `boundary_cases.json`: level/mode/boundary request packets and calibration sentinel cases.
- `side_mapping.json`: left/right device mapping scenarios for the Flutter device repository layer.
- `cross_platform_parity.json`: required Web TS, Android Java, and future Dart parity cases.

The `.hex` files mirror the minimum fixture names required by the Flutter app test plan. Keep them aligned with `req_golden_packets.json` and `parse_frames.json`.

When the Flutter/Dart BLE protocol is implemented, port these fixtures into Dart tests first, then compare the generated packets and parser outputs byte-for-byte before wiring real devices.
