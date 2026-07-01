import 'package:flutter/widgets.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/media/data/media_api_repository.dart';
import 'package:momcozy_flutter_app/features/pump_session/data/pump_workstate_api_repository.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';
import 'package:momcozy_flutter_app/native/android_p0_platform_channels.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/native/pump_native_runtime_coordinator.dart';

const _defaultApiBaseUrl = String.fromEnvironment(
  'MOMCOZY_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8769',
);
const _defaultApiToken = String.fromEnvironment('MOMCOZY_API_TOKEN');
const _defaultUserId = String.fromEnvironment(
  'MOMCOZY_DEFAULT_USER_ID',
  defaultValue: 'demo-user',
);
const _defaultBabyId = String.fromEnvironment(
  'MOMCOZY_DEFAULT_BABY_ID',
  defaultValue: 'demo-baby',
);
const _defaultLocale = String.fromEnvironment(
  'MOMCOZY_LOCALE',
  defaultValue: 'zh-CN',
);

class MomCozyApiRuntime {
  MomCozyApiRuntime({
    required this.jsonTransport,
    required this.userId,
    required this.babyId,
    required this.locale,
    ApiMultipartTransport? multipartTransport,
    ApiMultipartTransport Function()? multipartTransportFactory,
    BlePlatform? blePlatform,
    BlePlatform Function()? blePlatformFactory,
    PumpProtocolPlatform? pumpProtocolPlatform,
    PumpNativeRuntimeCoordinator Function(BlePlatform ble)?
    pumpNativeRuntimeCoordinatorFactory,
    DateTime Function()? now,
  }) : _multipartTransportFactory =
           multipartTransportFactory ??
           (() => throw StateError('Multipart transport is not configured.')),
       _blePlatformFactory = blePlatformFactory ?? AndroidBlePlatform.new,
       _pumpNativeRuntimeCoordinatorFactory =
           pumpNativeRuntimeCoordinatorFactory ??
           ((ble) => PumpNativeRuntimeCoordinator(
             ble: ble,
             upload: AndroidPumpAgentUploadPlatform(),
           )),
       now = now ?? DateTime.now {
    _multipartTransport = multipartTransport;
    _blePlatform = blePlatform;
    _pumpProtocolPlatform = pumpProtocolPlatform;
    _hasInjectedPumpProtocolPlatform = pumpProtocolPlatform != null;
  }

  factory MomCozyApiRuntime.fromEnvironment({
    ApiJsonTransport? jsonTransport,
    ApiMultipartTransport? multipartTransport,
    BlePlatform? blePlatform,
    PumpProtocolPlatform? pumpProtocolPlatform,
    String? userId,
    String? babyId,
    String? locale,
  }) {
    final token = _defaultApiToken.trim();
    final authToken = token.isEmpty ? null : token;
    final baseUri = Uri.parse(_defaultApiBaseUrl);
    const defaultHeaders = {'X-Momcozy-Client': 'flutter'};
    return MomCozyApiRuntime(
      jsonTransport:
          jsonTransport ??
          IoApiJsonTransport(
            baseUri: baseUri,
            token: authToken,
            headers: defaultHeaders,
          ),
      multipartTransport:
          multipartTransport ??
          IoApiMultipartTransport(
            baseUri: baseUri,
            token: authToken,
            headers: defaultHeaders,
          ),
      blePlatform: blePlatform,
      pumpProtocolPlatform: pumpProtocolPlatform,
      userId: userId ?? _defaultUserId,
      babyId: babyId ?? _defaultBabyId,
      locale: locale ?? _defaultLocale,
    );
  }

  final ApiJsonTransport jsonTransport;
  final String userId;
  final String babyId;
  final String locale;
  final DateTime Function() now;
  final ApiMultipartTransport Function() _multipartTransportFactory;
  final BlePlatform Function() _blePlatformFactory;
  final PumpNativeRuntimeCoordinator Function(BlePlatform ble)
  _pumpNativeRuntimeCoordinatorFactory;
  ApiMultipartTransport? _multipartTransport;
  BlePlatform? _blePlatform;
  PumpProtocolPlatform? _pumpProtocolPlatform;
  PumpNativeRuntimeCoordinator? _pumpNativeRuntimeCoordinator;
  late final bool _hasInjectedPumpProtocolPlatform;

  BlePlatform get blePlatform {
    return _blePlatform ??= _blePlatformFactory();
  }

  ApiMultipartTransport get multipartTransport {
    return _multipartTransport ??= _multipartTransportFactory();
  }

  PumpNativeRuntimeCoordinator get pumpNativeRuntimeCoordinator {
    return _pumpNativeRuntimeCoordinator ??=
        _pumpNativeRuntimeCoordinatorFactory(blePlatform);
  }

  PumpProtocolPlatform get pumpProtocolPlatform {
    return _pumpProtocolPlatform ??= pumpNativeRuntimeCoordinator.protocol;
  }

  Future<void> startPumpNativeRuntime({
    bool subscribeConnectedDevices = true,
  }) async {
    await pumpNativeRuntimeCoordinator.start(
      subscribeConnectedDevices: subscribeConnectedDevices,
    );
  }

  Future<void> ensurePumpProtocolReady({
    bool subscribeConnectedDevices = true,
  }) async {
    if (_hasInjectedPumpProtocolPlatform) return;
    await startPumpNativeRuntime(
      subscribeConnectedDevices: subscribeConnectedDevices,
    );
  }

  StatusApiRepository get statusRepository {
    return StatusApiRepository(transport: jsonTransport);
  }

  ScheduleApiRepository get scheduleRepository {
    return ScheduleApiRepository(transport: jsonTransport);
  }

  RecordsApiRepository get recordsRepository {
    return RecordsApiRepository(transport: jsonTransport);
  }

  MediaApiRepository get mediaRepository {
    return MediaApiRepository(transport: multipartTransport);
  }

  PumpWorkstateApiRepository get pumpWorkstateRepository {
    return PumpWorkstateApiRepository(transport: jsonTransport);
  }
}

class MomCozyRuntimeScope extends InheritedWidget {
  const MomCozyRuntimeScope({
    super.key,
    required this.apiRuntime,
    required super.child,
  });

  final MomCozyApiRuntime apiRuntime;

  static MomCozyApiRuntime of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<MomCozyRuntimeScope>();
    assert(
      scope != null,
      'MomCozyRuntimeScope is missing from the widget tree.',
    );
    return scope!.apiRuntime;
  }

  static MomCozyApiRuntime? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MomCozyRuntimeScope>()
        ?.apiRuntime;
  }

  @override
  bool updateShouldNotify(MomCozyRuntimeScope oldWidget) {
    return apiRuntime != oldWidget.apiRuntime;
  }
}
