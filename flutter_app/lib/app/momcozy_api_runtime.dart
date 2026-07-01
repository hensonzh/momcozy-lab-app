import 'package:flutter/widgets.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/pump_session/data/pump_workstate_api_repository.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';

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
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  factory MomCozyApiRuntime.fromEnvironment({
    ApiJsonTransport? jsonTransport,
    String? userId,
    String? babyId,
    String? locale,
  }) {
    final token = _defaultApiToken.trim();
    return MomCozyApiRuntime(
      jsonTransport:
          jsonTransport ??
          IoApiJsonTransport(
            baseUri: Uri.parse(_defaultApiBaseUrl),
            token: token.isEmpty ? null : token,
            headers: const {'X-Momcozy-Client': 'flutter'},
          ),
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

  StatusApiRepository get statusRepository {
    return StatusApiRepository(transport: jsonTransport);
  }

  ScheduleApiRepository get scheduleRepository {
    return ScheduleApiRepository(transport: jsonTransport);
  }

  RecordsApiRepository get recordsRepository {
    return RecordsApiRepository(transport: jsonTransport);
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
