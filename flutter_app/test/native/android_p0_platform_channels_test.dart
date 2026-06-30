import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/native/android_p0_platform_channels.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Android P0 platform channels', () {
    test('BLE adapter invokes MmcBle method schemas', () async {
      const channel = MethodChannel('test.momcozy/mmc_ble');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'permissionState' => {'state': 'denied'},
              'getConnectedDevices' => {
                'devices': [
                  {
                    'side': 'L',
                    'deviceId': 'ble-left-001',
                    'name': 'M9-L',
                    'connected': true,
                  },
                ],
              },
              'read' => {
                'value': [0x01, 0x02, 0xff],
              },
              _ => null,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final ble = AndroidBlePlatform(
        channel: channel,
        defaultServiceUuid: 'pump-service',
      );

      expect(await ble.permissionState(), BlePermissionState.denied);
      expect(await ble.requestPermission(), BlePermissionState.granted);
      await ble.startScan();
      await ble.stopScan();
      final connected = await ble.getConnectedDevices();
      await ble.connect('ble-left-001');
      await ble.disconnect('ble-left-001');
      expect(await ble.read('ble-left-001', 'status-char'), [0x01, 0x02, 0xff]);
      await ble.write('ble-left-001', 'command-char', const [0xaa]);
      await ble.writeWithoutResponse('ble-left-001', 'command-char', const [
        0xbb,
      ]);
      await ble.startNotifications('ble-left-001', 'notify-char');
      await ble.stopNotifications('ble-left-001', 'notify-char');

      expect(connected.single.deviceId, 'ble-left-001');
      expect(connected.single.deviceName, 'M9-L');
      expect(calls.map((call) => call.method), [
        'permissionState',
        'initialize',
        'requestLEScan',
        'stopLEScan',
        'getConnectedDevices',
        'connect',
        'disconnect',
        'read',
        'write',
        'writeWithoutResponse',
        'startNotifications',
        'stopNotifications',
      ]);
      expect(calls[7].arguments, {
        'deviceId': 'ble-left-001',
        'serviceUUID': 'pump-service',
        'characteristicUUID': 'status-char',
      });
      expect(calls[8].arguments, {
        'deviceId': 'ble-left-001',
        'serviceUUID': 'pump-service',
        'characteristicUUID': 'command-char',
        'value': [0xaa],
      });

      await ble.dispose();
    });

    test('BLE adapter maps native events into streams', () async {
      const channel = MethodChannel('test.momcozy/mmc_ble_events');
      final ble = AndroidBlePlatform(channel: channel);
      final scans = <BleDeviceSnapshot>[];
      final failures = <BleScanFailure>[];
      final notifications = <BleNotification>[];
      final scanSub = ble.scanResults.listen(scans.add);
      final failureSub = ble.scanFailures.listen(failures.add);
      final notificationSub = ble.notifications.listen(notifications.add);

      await ble.handleNativeEvent('scanResult', {
        'device': {'deviceId': 'ble-right-001', 'name': 'M9-R'},
      });
      await ble.handleNativeEvent('scanFailed', {'errorCode': 7});
      await ble.handleNativeEvent('notification', {
        'deviceId': 'ble-right-001',
        'characteristicUUID': 'notify-char',
        'value': [0xe1],
      });
      await flushStreams();

      expect(scans.single.deviceName, 'M9-R');
      expect(failures.single.code, '7');
      expect(notifications.single.value, [0xe1]);

      await scanSub.cancel();
      await failureSub.cancel();
      await notificationSub.cancel();
      await ble.dispose();
    });

    test(
      'pump foreground adapter invokes notification method schemas',
      () async {
        const channel = MethodChannel('test.momcozy/pump_notification');
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              return switch (call.method) {
                'requestPermission' => {'granted': true},
                'consumePendingNavigate' => {
                  'path': '/',
                  'notifyJson': {'event': 'milk_analysis'},
                  'autoEndTeardown': true,
                },
                'restoreSnapshot' => {
                  'active': true,
                  'elapsedSeconds': 240,
                  'leftMilkMl': 12,
                  'rightMilkMl': 9,
                  'paused': true,
                },
                _ => null,
              };
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        final service = AndroidPumpSessionForegroundServicePlatform(
          channel: channel,
        );

        expect(await service.requestPermission(), isTrue);
        await service.start(
          const PumpSessionSnapshot(active: true, elapsedSeconds: 120),
        );
        await service.update(
          const PumpSessionSnapshot(
            active: true,
            elapsedSeconds: 180,
            paused: true,
          ),
        );
        await service.showCompletionNotice(
          const PumpSessionSnapshot(active: false, elapsedSeconds: 240),
        );
        await service.showAutoEndNotice(
          const PumpSessionSnapshot(active: false, elapsedSeconds: 240),
        );
        await service.enqueuePendingNavigate(
          const PendingNativeRoute(
            path: '/',
            notifyJson: {'event': 'milk_analysis'},
            autoEndTeardown: true,
          ),
        );
        final route = await service.consumePendingNavigate();
        final restored = await service.restoreSnapshot();
        await service.stop();

        expect(calls.map((call) => call.method), [
          'requestPermission',
          'start',
          'update',
          'showCompletionNotice',
          'showAutoEndNotice',
          'enqueuePendingNavigate',
          'consumePendingNavigate',
          'restoreSnapshot',
          'stop',
        ]);
        expect(calls[1].arguments, {
          'active': true,
          'state': 'running',
          'elapsedSeconds': 120,
          'leftMilkMl': 0,
          'rightMilkMl': 0,
          'paused': false,
          'processAll': 0,
        });
        expect(
          (calls[2].arguments as Map<Object?, Object?>)['state'],
          'paused',
        );
        expect(route?.toMap(), {
          'path': '/',
          'notifyJson': {'event': 'milk_analysis'},
          'autoEndTeardown': true,
        });
        expect(restored?.paused, isTrue);

        await service.dispose();
      },
    );
  });
}

Future<void> flushStreams() async {
  await Future<void>.delayed(Duration.zero);
}
