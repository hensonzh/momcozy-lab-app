import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/ble/pump_device_snapshot.dart';
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
                    'battery': 87,
                    'rssi': -54,
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
      expect(connected.single.battery, 87);
      expect(connected.single.rssi, -54);
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

    test('BLE adapter maps permanently denied permission aliases', () async {
      const channel = MethodChannel('test.momcozy/mmc_ble_permission_aliases');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return switch (call.method) {
              'permissionState' => {'state': 'blocked'},
              'initialize' => {'state': 'permanently_denied'},
              _ => null,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final ble = AndroidBlePlatform(channel: channel);

      expect(await ble.permissionState(), BlePermissionState.permanentlyDenied);
      expect(
        await ble.requestPermission(),
        BlePermissionState.permanentlyDenied,
      );

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
        'device': {
          'deviceId': 'ble-right-001',
          'name': 'M9-R',
          'batteryPct': 74,
          'rssi': -52,
        },
      });
      await ble.handleNativeEvent('scanFailed', {'errorCode': 7});
      await ble.handleNativeEvent('notification', {
        'deviceId': 'ble-right-001',
        'characteristicUUID': 'notify-char',
        'value': [0xe1],
      });
      await flushStreams();

      expect(scans.single.deviceName, 'M9-R');
      expect(scans.single.battery, 74);
      expect(scans.single.rssi, -52);
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

    test(
      'route intent adapter invokes pending route schemas and events',
      () async {
        const channel = MethodChannel('test.momcozy/route_intent');
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              return switch (call.method) {
                'consumePendingNavigate' => {
                  'path': '/pump',
                  'notifyJson': {'event': 'pump'},
                  'autoEndTeardown': false,
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
        final routes = <PendingNativeRoute>[];
        final platform = AndroidRouteIntentPlatform(channel: channel);
        final sub = platform.activeRoutes.listen(routes.add);

        await platform.enqueuePendingRoute(
          const PendingNativeRoute(
            path: '/me',
            notifyJson: {'event': 'grown'},
            autoEndTeardown: true,
          ),
        );
        final pending = await platform.consumePendingRoute();
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              channel.name,
              channel.codec.encodeMethodCall(
                const MethodCall('activeRoute', {
                  'path': '/plan',
                  'notifyJson': {'event': 'plan_updated'},
                  'autoEndTeardown': false,
                }),
              ),
              (_) {},
            );
        await flushStreams();

        expect(calls.map((call) => call.method), [
          'enqueuePendingNavigate',
          'consumePendingNavigate',
        ]);
        expect(calls.first.arguments, {
          'path': '/me',
          'notifyJson': {'event': 'grown'},
          'autoEndTeardown': true,
        });
        expect(pending?.toMap(), {
          'path': '/pump',
          'notifyJson': {'event': 'pump'},
        });
        expect(routes.single.toMap(), {
          'path': '/plan',
          'notifyJson': {'event': 'plan_updated'},
        });

        await sub.cancel();
        await platform.dispose();
      },
    );

    test('pump agent upload adapter invokes method schemas', () async {
      const channel = MethodChannel('test.momcozy/pump_agent_upload');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'sampleFromSnapshot' => {
                'processL': 10,
                'processR': 20,
                'processAll': 30,
                'elapsedSeconds': 180,
              },
              'resetProgress' => {
                'processL': 0,
                'processR': 0,
                'processAll': 0,
                'elapsedSeconds': 0,
              },
              'updateDeviceSnapshot' => null,
              'uploadWorkstate' ||
              'getProcessData' ||
              'uploadProcess' ||
              'uploadMilkRecord' => {
                'body': call.arguments,
                'response': {'error': 0},
                'processAll': 42,
                'deduped': call.method == 'uploadMilkRecord',
              },
              _ => null,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final upload = AndroidPumpAgentUploadPlatform(channel: channel);

      await upload.setConfig(
        apiBaseUrl: 'https://api.example.test',
        bearerToken: 'secret-token',
      );
      await upload.updateDeviceSnapshot(
        const PumpDeviceSnapshot(
          left: PumpDeviceSideState(
            deviceId: 'left-device-id',
            deviceName: 'Left pump',
            connected: true,
            battery: 87,
            serialNumber: 'left-sn',
          ),
        ),
      );
      expect((await upload.sampleFromSnapshot()).processAll, 30);
      expect((await upload.resetProgress()).processAll, 0);
      await upload.markStepStop(PumpAgentUploadSide.both);
      await upload.markStepPause(PumpAgentUploadSide.left);
      await upload.setOperationSource(
        PumpAgentUploadSide.right,
        PumpAgentUploadSource.agent,
      );
      expect((await upload.uploadWorkstate()).response, {'error': 0});
      expect((await upload.getProcessData()).progress.processAll, 42);
      expect((await upload.uploadProcess()).deduped, isFalse);
      expect(
        (await upload.uploadMilkRecord(endedAtMs: 1782687600000)).deduped,
        isTrue,
      );

      expect(calls.map((call) => call.method), [
        'setConfig',
        'updateDeviceSnapshot',
        'sampleFromSnapshot',
        'resetProgress',
        'markStepStop',
        'markStepPause',
        'setOperationSource',
        'uploadWorkstate',
        'getProcessData',
        'uploadProcess',
        'uploadMilkRecord',
      ]);
      expect(calls.first.arguments, {
        'apiBaseUrl': 'https://api.example.test',
        'bearerToken': 'secret-token',
      });
      expect(calls[1].arguments, {
        'snapshot': {
          'L': {
            'deviceId': 'left-device-id',
            'deviceName': 'Left pump',
            'connected': true,
            'battery': 87,
            'flangeSize': 24,
            'sealSize': 'M',
            'model': '',
            'firmware': '-',
            'serialNumber': 'left-sn',
          },
          'R': null,
        },
      });
      expect(calls[4].arguments, {'side': 'both'});
      expect(calls[5].arguments, {'side': 'L'});
      expect(calls[6].arguments, {'side': 'R', 'source': 'agent'});
      expect(calls.last.arguments, {'endedAtMs': 1782687600000});

      await upload.dispose();
    });

    test('pump agent upload adapter maps native failure events', () async {
      const channel = MethodChannel('test.momcozy/pump_agent_upload_events');
      final upload = AndroidPumpAgentUploadPlatform(channel: channel);
      final failures = <PumpAgentUploadFailure>[];
      final progressEvents = <PumpAgentUploadProgress>[];
      final processReplies = <PumpAgentProcessReply>[];
      final sub = upload.failures.listen(failures.add);
      final progressSub = upload.progressEvents.listen(progressEvents.add);
      final replySub = upload.processReplies.listen(processReplies.add);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(
              const MethodCall('uploadFailure', {
                'method': 'uploadProcess',
                'code': 'network',
                'message': 'Network timeout',
                'retryable': true,
                'payload': {'token': '***'},
              }),
            ),
            (_) {},
          );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(
              const MethodCall('processProgress', {
                'processL': 12,
                'processR': 24,
                'processAll': 36,
                'elapsedSeconds': 180,
              }),
            ),
            (_) {},
          );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(
              const MethodCall('processReply', {
                'error': 0,
                'need_reply': false,
              }),
            ),
            (_) {},
          );
      await flushStreams();

      expect(failures.single.method, 'uploadProcess');
      expect(failures.single.retryable, isTrue);
      expect(failures.single.payload, {'token': '***'});
      expect(progressEvents.single.processAll, 36);
      expect(progressEvents.single.elapsedSeconds, 180);
      expect(processReplies.single.response, {'error': 0, 'need_reply': false});

      await sub.cancel();
      await progressSub.cancel();
      await replySub.cancel();
      await upload.dispose();
    });
  });
}

Future<void> flushStreams() async {
  await Future<void>.delayed(Duration.zero);
}
