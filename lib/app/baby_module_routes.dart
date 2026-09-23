import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../modules/baby/application/baby_home_controller.dart';
import '../modules/baby/presentation/baby_home_page.dart';
import '../services/mother/mother_profile_api_repository.dart';
import '../services/baby/baby_profiles_api_repository.dart';
import '../services/baby/baby_records_api_repository.dart';
import 'momcozy_api_runtime.dart';

// Runtime identity isolates accounts and API environments; cache only view data.
final _homeSnapshots = Expando<BabyHomeSnapshot>('baby-home-snapshots');

Widget buildBabyHome(
  BuildContext context, {
  Future<void> Function(String babyId)? onBabySelected,
}) {
  final runtime = MomCozyRuntimeScope.of(context);
  return _BabyHomeRoute(
    key: ValueKey(runtime),
    runtime: runtime,
    onBabySelected: onBabySelected,
  );
}

class _BabyHomeRoute extends StatefulWidget {
  const _BabyHomeRoute({super.key, required this.runtime, this.onBabySelected});
  final MomCozyApiRuntime runtime;
  final Future<void> Function(String babyId)? onBabySelected;
  @override
  State<_BabyHomeRoute> createState() => _BabyHomeRouteState();
}

class _BabyHomeRouteState extends State<_BabyHomeRoute> {
  late final BabyHomeController controller;
  @override
  void initState() {
    super.initState();
    final runtime = widget.runtime;
    controller = BabyHomeController(
      profileRepository: BabyProfilesApiRepository(
        transport: runtime.jsonTransport,
      ),
      recordRepository: BabyRecordsApiRepository(
        transport: runtime.jsonTransport,
      ),
      timezoneProvider: runtime.timezoneProvider,
      now: runtime.now,
      selectedBabyId: runtime.currentSession.babyId,
      snapshot: _homeSnapshots[runtime],
      deliveryDateProvider: () async => (await MotherProfileApiRepository(
        transport: runtime.jsonTransport,
        ownerUserId: runtime.currentSession.userId,
        timezoneProvider: runtime.timezoneProvider,
      ).get()).deliveryDate,
    );
    controller.addListener(() => _homeSnapshots[runtime] = controller.snapshot);
  }

  @override
  Widget build(BuildContext context) => BabyHomePage(
    controller: controller,
    onAsk: (text) => context.go('/', extra: {'agentPrefill': text}),
    onBabySelected: widget.onBabySelected,
    rememberedBabyId: widget.runtime.currentSession.babyId,
  );
  // BabyHomePage owns and disposes this controller. Only the snapshot survives
  // navigation; no timer/listener continues to run on an unmounted page.
}

final babyModuleRoutes = <GoRoute>[];
