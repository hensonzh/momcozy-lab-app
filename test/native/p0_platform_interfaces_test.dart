import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/ble/pump_device_snapshot.dart';
import 'package:app/native/p0_platform_interfaces.dart';

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

    test(
      'fake BLE platform clears subscriptions and reads again after reconnect',
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
        final notifications = <BleNotification>[];
        final notificationSub = ble.notifications.listen(notifications.add);

        await ble.connect('ble-left-001');
        await ble.startNotifications('ble-left-001', 'notify-char');
        expect(ble.isSubscribed('ble-left-001', 'notify-char'), isTrue);

        await ble.disconnect('ble-left-001');
        expect(await ble.getConnectedDevices(), isEmpty);
        expect(ble.isSubscribed('ble-left-001', 'notify-char'), isFalse);
        expect(
          ble.read('ble-left-001', 'status-char'),
          throwsA(isA<StateError>()),
        );
        ble.emitNotification(
          const BleNotification(
            deviceId: 'ble-left-001',
            characteristicUuid: 'notify-char',
            value: [0xff],
          ),
        );
        await flushStreams();
        expect(notifications, isEmpty);

        await ble.connect('ble-left-001');
        ble.setReadValue('ble-left-001', 'status-char', const [0xaa, 0x55]);
        expect(await ble.read('ble-left-001', 'status-char'), [0xaa, 0x55]);
        await ble.startNotifications('ble-left-001', 'notify-char');
        ble.emitNotification(
          const BleNotification(
            deviceId: 'ble-left-001',
            characteristicUuid: 'notify-char',
            value: [0xe1],
          ),
        );
        await flushStreams();

        expect(
          (await ble.getConnectedDevices()).map((device) => device.deviceId),
          ['ble-left-001'],
        );
        expect(notifications.map((event) => event.value), [
          [0xe1],
        ]);

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
      'fake pump agent upload emits method schemas and dedupes uploads',
      () async {
        final upload = FakePumpAgentUploadPlatform()
          ..progress = const PumpAgentUploadProgress(
            processL: 10,
            processR: 20,
            processAll: 30,
            elapsedSeconds: 180,
          );
        final calls = <PumpAgentUploadCall>[];
        final progressEvents = <PumpAgentUploadProgress>[];
        final processReplies = <PumpAgentProcessReply>[];
        final sub = upload.calls.listen(calls.add);
        final progressSub = upload.progressEvents.listen(progressEvents.add);
        final replySub = upload.processReplies.listen(processReplies.add);

        await upload.setConfig(
          apiBaseUrl: 'https://api.example.test',
          bearerToken: 'secret-token',
        );
        await upload.updateDeviceSnapshot(
          const PumpDeviceSnapshot(
            left: PumpDeviceSideState(
              deviceId: 'left-secret-id',
              deviceName: 'Left pump',
              connected: true,
              serialNumber: 'left-secret-sn',
            ),
          ),
        );
        expect(await upload.sampleFromSnapshot(), upload.progress);
        final resetProgress = await upload.resetProgress();
        await upload.markStepStop(PumpAgentUploadSide.both);
        await upload.markStepPause(PumpAgentUploadSide.left);
        await upload.setOperationSource(
          PumpAgentUploadSide.right,
          PumpAgentUploadSource.app,
        );
        final firstWorkstate = await upload.uploadWorkstate();
        final duplicateWorkstate = await upload.uploadWorkstate();
        await upload.getProcessData();
        await upload.uploadProcess();
        final firstMilkRecord = await upload.uploadMilkRecord(
          endedAtMs: 1782687600000,
        );
        final duplicateMilkRecord = await upload.uploadMilkRecord(
          endedAtMs: 1782687600000,
        );
        upload.emitProgress(
          const PumpAgentUploadProgress(
            processL: 11,
            processR: 22,
            processAll: 33,
            elapsedSeconds: 190,
          ),
        );
        upload.emitProcessReply(const {'error': 0, 'need_reply': false});
        await flushStreams();

        expect(calls.map((call) => call.method), [
          'setConfig',
          'updateDeviceSnapshot',
          'sampleFromSnapshot',
          'resetProgress',
          'markStepStop',
          'markStepPause',
          'setOperationSource',
          'uploadWorkstate',
          'uploadWorkstate',
          'getProcessData',
          'uploadProcess',
          'uploadMilkRecord',
          'uploadMilkRecord',
        ]);
        expect(calls.first.payload, {
          'apiBaseUrl': 'https://api.example.test',
          'bearerToken': '***',
        });
        expect(calls[1].payload['snapshot'], {
          'L': {
            'deviceId': '***',
            'deviceName': 'Left pump',
            'connected': true,
            'battery': 0,
            'flangeSize': 24,
            'sealSize': 'M',
            'model': '',
            'firmware': '-',
            'serialNumber': '***',
          },
          'R': null,
        });
        expect(resetProgress.toMap(), {
          'processL': 0,
          'processR': 0,
          'processAll': 0,
          'elapsedSeconds': 0,
        });
        expect(calls[4].payload, {'side': 'both'});
        expect(calls[5].payload, {'side': 'L'});
        expect(calls[6].payload, {'side': 'R', 'source': 'app'});
        expect(firstWorkstate.deduped, isFalse);
        expect(duplicateWorkstate.deduped, isTrue);
        expect(calls[8].payload['deduped'], isTrue);
        expect(firstMilkRecord.deduped, isFalse);
        expect(duplicateMilkRecord.deduped, isTrue);
        expect(calls.last.payload['deduped'], isTrue);
        expect(upload.completedUploadKeys.length, 3);
        expect(upload.dedupedUploadKeys.length, 2);
        expect(progressEvents.single.processAll, 33);
        expect(progressEvents.single.elapsedSeconds, 190);
        expect(processReplies.single.response, {
          'error': 0,
          'need_reply': false,
        });
        expect(upload.recordedProgressEvents.single, progressEvents.single);
        expect(upload.recordedProcessReplies.single, processReplies.single);

        await sub.cancel();
        await progressSub.cancel();
        await replySub.cancel();
        await upload.dispose();
      },
    );

    test('fake pump agent upload redacts sensitive failure payloads', () async {
      final upload = FakePumpAgentUploadPlatform();
      final failures = <PumpAgentUploadFailure>[];
      final sub = upload.failures.listen(failures.add);

      upload.emitFailure(
        method: 'uploadProcess',
        code: 'network-timeout',
        message: 'Upload timed out',
        retryable: true,
        payload: const {
          'bearerToken': 'secret-token',
          'user_id': 'demo-user',
          'conversationId': 'conv-1',
          'safe': 'kept',
          'nested': {
            'Authorization': 'Bearer secret-token',
            'session_id': 'session-1',
            'milk': 42,
          },
        },
      );
      await flushStreams();

      expect(failures.single.method, 'uploadProcess');
      expect(failures.single.retryable, isTrue);
      expect(failures.single.payload, {
        'bearerToken': '***',
        'user_id': '***',
        'conversationId': '***',
        'safe': 'kept',
        'nested': {'Authorization': '***', 'session_id': '***', 'milk': 42},
      });
      expect(upload.recordedFailures.single.payload, failures.single.payload);

      await sub.cancel();
      await upload.dispose();
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
