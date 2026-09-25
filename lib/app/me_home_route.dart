import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../domain/baby/baby_record.dart';
import '../modules/mom/presentation/me_shared_record_sheet.dart';
import '../modules/baby/presentation/baby_profile_editor.dart';
import '../modules/mom/application/me_controller.dart';
import '../modules/mom/data/me_api_repository.dart';
import '../modules/mom/data/me_shared_records.dart';
import '../modules/mom/domain/me_experience.dart';
import '../modules/mom/presentation/me_home_page.dart';
import '../services/baby/baby_profiles_api_repository.dart';
import '../services/baby/baby_records_api_repository.dart';
import 'momcozy_api_runtime.dart';

final _snapshots = Expando<MeState>('me-home');

class MeHomeRoute extends StatefulWidget {
  const MeHomeRoute({super.key, required this.runtime});
  final MomCozyApiRuntime runtime;
  @override
  State<MeHomeRoute> createState() => _MeHomeRouteState();
}

class _MeHomeRouteState extends State<MeHomeRoute> {
  late final repository = MeApiRepository(
    widget.runtime.jsonTransport,
    timezoneProvider: widget.runtime.timezoneProvider,
    selectedBabyId: widget.runtime.currentSession.babyId,
  );
  late final controller = MeController(
    repository: repository,
    now: widget.runtime.now,
    state: _snapshots[widget.runtime],
  );
  @override
  void initState() {
    super.initState();
    controller.addListener(() => _snapshots[widget.runtime] = controller.state);
  }

  Future<void> record(BuildContext context, MeMetric metric) async {
    try {
      final runtime = widget.runtime;
      final timezone = await runtime.timezoneProvider();
      if (!context.mounted) return;
      var baby = repository.baby;
      if (baby == null) {
        final profiles = await BabyProfilesApiRepository(
          transport: runtime.jsonTransport,
        ).list();
        baby =
            profiles
                .where((e) => e.id == runtime.currentSession.babyId)
                .firstOrNull ??
            profiles.firstOrNull;
        if (!context.mounted) return;
      }
      if (baby == null) {
        baby = await showBabyProfileEditor(
          context,
          repository: BabyProfilesApiRepository(
            transport: runtime.jsonTransport,
          ),
          timezone: timezone,
          now: runtime.now,
        );
        if (baby == null || !context.mounted) return;
        repository.baby = baby;
      }
      final result = await showMeSharedRecordSheet(
        context,
        repository: BabyRecordsApiRepository(transport: runtime.jsonTransport),
        baby: baby,
        timezone: timezone,
        now: runtime.now,
        kind: switch (metric) {
          MeMetric.weight => BabyRecordKind.growth,
          MeMetric.diaper => BabyRecordKind.diaper,
          _ => BabyRecordKind.feeding,
        },
      );
      if (result != null && !controller.disposed) {
        controller.applySharedRecords(meObservationsFromBaby(result));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not load. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => MeHomePage(
    controller: controller,
    onSharedRecord: record,
    onAsk: (text) => context.go('/', extra: {'agentPrefill': text}),
  );
}
