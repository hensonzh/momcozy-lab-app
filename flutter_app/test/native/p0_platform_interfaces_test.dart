import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

void main() {
  group('P0 native fake platforms', () {
    test('fake BLE platform enforces permission before scan', () async {
      final ble = FakeBlePlatform();

      expect(ble.startScan(), throwsA(isA<StateError>()));

      expect(await ble.requestPermission(), BlePermissionState.granted);
      await ble.startScan();
      expect(ble.scanning, isTrue);

      await ble.dispose();
    });

    test(
      'fake BLE platform scans, fails, connects, reads, writes, and notifies',
      () async {
        final ble = FakeBlePlatform(
          initialPermission: BlePermissionState.granted,
          seedDevices: const [
            BleDeviceSnapshot(
              side: 'L',
              deviceId: 'ble-left-001',
              deviceName: 'M9-L',
            ),
          ],
        );
        final scanned = <BleDeviceSnapshot>[];
        final failures = <BleScanFailure>[];
        final notifications = <BleNotification>[];
        final scanSub = ble.scanResults.listen(scanned.add);
        final failureSub = ble.scanFailures.listen(failures.add);
        final notificationSub = ble.notifications.listen(notifications.add);

        await ble.startScan();
        ble.addScanResult(
          const BleDeviceSnapshot(
            side: 'R',
            deviceId: 'ble-right-001',
            deviceName: 'M9-R',
          ),
        );
        ble.failScan(
          const BleScanFailure(
            code: 'adapter-off',
            message: 'Bluetooth is off',
          ),
        );
        await ble.connect('ble-left-001');
        ble.setReadValue('ble-left-001', 'status-char', const [0xaa, 0x55]);
        expect(await ble.read('ble-left-001', 'status-char'), [0xaa, 0x55]);

        await ble.write('ble-left-001', 'command-char', const [0x01]);
        await ble.writeWithoutResponse('ble-left-001', 'command-char', const [
          0x02,
        ]);
        await ble.startNotifications('ble-left-001', 'notify-char');
        ble.emitNotification(
          const BleNotification(
            deviceId: 'ble-left-001',
            characteristicUuid: 'notify-char',
            value: [0xe1],
          ),
        );
        await flushStreams();
        await ble.stopNotifications('ble-left-001', 'notify-char');
        ble.emitNotification(
          const BleNotification(
            deviceId: 'ble-left-001',
            characteristicUuid: 'notify-char',
            value: [0xff],
          ),
        );
        await flushStreams();
        await ble.stopScan();

        expect(
          scanned.map((device) => device.deviceId),
          contains('ble-right-001'),
        );
        expect(failures.single.code, 'adapter-off');
        expect(
          (await ble.getConnectedDevices()).map((device) => device.deviceId),
          ['ble-left-001'],
        );
        expect(ble.writes, [
          {
            'method': 'write',
            'deviceId': 'ble-left-001',
            'characteristicUuid': 'command-char',
            'bytes': [0x01],
          },
          {
            'method': 'writeWithoutResponse',
            'deviceId': 'ble-left-001',
            'characteristicUuid': 'command-char',
            'bytes': [0x02],
          },
        ]);
        expect(notifications.map((event) => event.value), [
          [0xe1],
        ]);

        await scanSub.cancel();
        await failureSub.cancel();
        await notificationSub.cancel();
        await ble.dispose();
      },
    );

    test('fake BLE platform records settings handoffs', () async {
      final ble = FakeBlePlatform();

      await ble.openBluetoothSettings();
      await ble.openAppSettings();

      expect(ble.openedBluetoothSettings, isTrue);
      expect(ble.openedAppSettings, isTrue);
      await ble.dispose();
    });

    test('fake pump protocol emits typed method command schemas', () async {
      final protocol = FakePumpProtocolPlatform();
      final commands = <PumpProtocolCommand>[];
      final sub = protocol.commands.listen(commands.add);

      await protocol.setPumpParams(
        PumpSide.left,
        const PumpParamsRequest(startStop: 1, mode: 1, gear: 6, scene: 1),
      );
      await protocol.powerOff(PumpSide.left, reboot: true);
      await protocol.endRun(PumpSide.left);
      await protocol.getDeviceInfo(PumpSide.right);
      await protocol.setRtc(PumpSide.right, 1782687600);
      await protocol.queryDeviceStatus(PumpSide.right);
      await protocol.adjustGearForSide(PumpSide.left, 5);
      await protocol.setModeForSide(PumpSide.left, 2);
      await protocol.setSceneForSide(PumpSide.left, 1);
      await protocol.setStartStopForSide(PumpSide.left, 0);
      await flushStreams();

      expect(commands.map((command) => command.name), [
        'setPumpParams',
        'powerOff',
        'endRun',
        'getDeviceInfo',
        'setRtc',
        'queryDeviceStatus',
        'adjustGearForSide',
        'setModeForSide',
        'setSceneForSide',
        'setStartStopForSide',
      ]);
      expect(commands.first.side, PumpSide.left);
      expect(commands.first.payload, {
        'startStop': 1,
        'mode': 1,
        'gear': 6,
        'scene': 1,
      });
      expect(commands[4].payload, {'utcSeconds': 1782687600});
      expect(protocol.recordedCommands.length, 10);

      await sub.cancel();
      await protocol.dispose();
    });

    test(
      'fake pump foreground service emits lifecycle and notice events',
      () async {
        final service = FakePumpSessionForegroundServicePlatform();
        final events = <PumpSessionNativeEvent>[];
        final sub = service.events.listen(events.add);

        expect(await service.requestPermission(), isTrue);
        expect(await service.restoreSnapshot(), isNull);
        await service.start(
          const PumpSessionSnapshot(
            active: true,
            elapsedSeconds: 120,
            leftMilkMl: 12,
          ),
        );
        await service.update(
          const PumpSessionSnapshot(
            active: true,
            elapsedSeconds: 180,
            leftMilkMl: 13,
            rightMilkMl: 9,
            paused: true,
          ),
        );
        await service.showCompletionNotice(
          const PumpSessionSnapshot(
            active: false,
            elapsedSeconds: 240,
            leftMilkMl: 13,
          ),
        );
        await service.showAutoEndNotice(
          const PumpSessionSnapshot(
            active: false,
            elapsedSeconds: 240,
            rightMilkMl: 9,
          ),
        );
        await service.stop();
        await flushStreams();

        expect(events.map((event) => event.type), [
          PumpSessionNativeEventType.started,
          PumpSessionNativeEventType.updated,
          PumpSessionNativeEventType.completionNotice,
          PumpSessionNativeEventType.autoEndNotice,
          PumpSessionNativeEventType.stopped,
        ]);
        expect(events[1].snapshot?.paused, isTrue);
        expect(await service.restoreSnapshot(), isNull);

        await sub.cancel();
        await service.dispose();
      },
    );

    test(
      'fake pump foreground service consumes pending native navigation once',
      () async {
        final service = FakePumpSessionForegroundServicePlatform();
        const route = PendingNativeRoute(
          path: '/',
          notifyJson: {'event': 'milk_analysis'},
          autoEndTeardown: true,
        );

        await service.enqueuePendingNavigate(route);

        expect((await service.consumePendingNavigate())?.toMap(), {
          'path': '/',
          'notifyJson': {'event': 'milk_analysis'},
          'autoEndTeardown': true,
        });
        expect(await service.consumePendingNavigate(), isNull);
        await service.dispose();
      },
    );

    test(
      'fake wake lock reference count is idempotent on extra release',
      () async {
        final wakeLock = FakePumpWakeLockPlatform();

        await wakeLock.acquire();
        await wakeLock.acquire();
        expect(wakeLock.held, isTrue);
        await wakeLock.release();
        expect(wakeLock.held, isTrue);
        await wakeLock.release();
        await wakeLock.release();
        expect(wakeLock.held, isFalse);
      },
    );

    test(
      'fake route intent platform handles pending and active route events',
      () async {
        final routes = FakeRouteIntentPlatform();
        final active = <PendingNativeRoute>[];
        final sub = routes.activeRoutes.listen(active.add);
        const route = PendingNativeRoute(
          path: '/pump',
          notifyJson: {'source': 'foreground-notification'},
        );

        await routes.enqueuePendingRoute(route);
        routes.dispatchActiveRoute(route);
        await flushStreams();

        expect((await routes.consumePendingRoute())?.toMap(), {
          'path': '/pump',
          'notifyJson': {'source': 'foreground-notification'},
        });
        expect(await routes.consumePendingRoute(), isNull);
        expect(active.single.path, '/pump');

        await sub.cancel();
        await routes.dispose();
      },
    );
  });
}

Future<void> flushStreams() async {
  await Future<void>.delayed(Duration.zero);
}
