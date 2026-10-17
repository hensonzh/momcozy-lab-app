import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';

const devicesEndpoint = '/v1/devices/pumps';

class RegisteredDevice {
  const RegisteredDevice({
    required this.id,
    required this.model,
    required this.status,
  });

  final String id;
  final String model;
  final String status;

  static RegisteredDevice fromMap(Map<String, Object?> data) {
    final id = data['device_id'];
    final model = data['model'];
    final status = data['status'];
    if (id is! String || id.isEmpty || model is! String || status is! String) {
      throw const FormatException('Invalid device response.');
    }
    return RegisteredDevice(id: id, model: model, status: status);
  }
}

class RegisteredDevicesRepository {
  const RegisteredDevicesRepository(this.transport);

  final ApiJsonTransport transport;

  Future<List<RegisteredDevice>> list() async {
    final body = await transport.getJson(devicesEndpoint);
    final items = body['items'];
    if (items is! List) {
      throw const FormatException('Invalid devices response.');
    }
    return [
      for (final item in items)
        if (item is Map<String, Object?>)
          RegisteredDevice.fromMap(item)
        else
          throw const FormatException('Invalid device item.'),
    ];
  }
}

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key, required this.runtime});

  final MomCozyApiRuntime runtime;

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  late Future<List<RegisteredDevice>> _devices = _load();

  Future<List<RegisteredDevice>> _load() =>
      RegisteredDevicesRepository(widget.runtime.jsonTransport).list();

  @override
  void didUpdateWidget(covariant DevicesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runtime != widget.runtime ||
        oldWidget.runtime.currentSession.userId !=
            widget.runtime.currentSession.userId) {
      _devices = _load();
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFFFFDFA),
    child: FutureBuilder<List<RegisteredDevice>>(
      future: _devices,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('无法加载设备，请检查网络后重试。'),
                TextButton(
                  onPressed: () => setState(() => _devices = _load()),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }
        final devices = snapshot.data!;
        if (devices.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '当前账号没有已登记的设备。设备连接与控制暂未开放。',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final device in devices)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.devices_other_rounded),
                  title: Text(device.model.isEmpty ? '已登记设备' : device.model),
                  subtitle: Text('设备 ID：${device.id}'),
                  trailing: Text(device.status),
                ),
              ),
          ],
        );
      },
    ),
  );
}
