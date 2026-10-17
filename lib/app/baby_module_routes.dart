import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../modules/baby/application/baby_home_controller.dart';
import '../modules/baby/presentation/baby_home_page.dart';
import '../features/app_pages/chat_first_baby_page.dart';
import '../features/app_pages/chat_first_baby_details_page.dart';
import '../features/agent_hub/presentation/chat_first_actions.dart';
import '../features/records/presentation/chat_first_record_sheet.dart';
import '../domain/baby/baby_record.dart';
import '../services/mother/mother_profile_api_repository.dart';
import '../services/baby/baby_profiles_api_repository.dart';
import '../services/baby/baby_records_api_repository.dart';
import 'momcozy_api_runtime.dart';

// Runtime identity isolates accounts and API environments; cache only view data.
final _homeSnapshots = Expando<BabyHomeSnapshot>('baby-home-snapshots');

Widget buildBabyHome(
  BuildContext context, {
  bool chatFirstExperience = false,
  bool fullDetails = false,
  Future<void> Function(String babyId)? onBabySelected,
}) {
  final runtime = MomCozyRuntimeScope.of(context);
  return _BabyHomeRoute(
    key: ValueKey(runtime),
    runtime: runtime,
    chatFirstExperience: chatFirstExperience,
    fullDetails: fullDetails,
    onBabySelected: onBabySelected,
  );
}

class _BabyHomeRoute extends StatefulWidget {
  const _BabyHomeRoute({
    super.key,
    required this.runtime,
    required this.chatFirstExperience,
    required this.fullDetails,
    this.onBabySelected,
  });
  final MomCozyApiRuntime runtime;
  final bool chatFirstExperience;
  final bool fullDetails;
  final Future<void> Function(String babyId)? onBabySelected;
  @override
  State<_BabyHomeRoute> createState() => _BabyHomeRouteState();
}

class _BabyHomeRouteState extends State<_BabyHomeRoute> {
  late final BabyHomeController controller;

  Future<void> _recordSelectedSleep(String babyId) async {
    final runtime = widget.runtime;
    try {
      if (runtime.currentSession.babyId != babyId) {
        await widget.onBabySelected?.call(babyId);
      }
      if (!mounted ||
          controller.baby?.id != babyId ||
          runtime.currentSession.babyId != babyId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂时无法确认当前宝宝，请返回宝宝概览核对后重试。')),
          );
        }
        return;
      }
      final saved = await showChatFirstRecordSheet(
        context,
        runtime: runtime,
        kind: ChatFirstRecordKind.sleep,
      );
      if (saved != null && mounted) {
        await controller.refreshRecords(kind: BabyRecordKind.sleep);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时无法确认宝宝档案，请检查网络后重试。')));
      }
    }
  }

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
  Widget build(BuildContext context) =>
      widget.chatFirstExperience && widget.fullDetails
      ? ChatFirstBabyDetailsPage(
          controller: controller,
          onBabySelected: widget.onBabySelected,
          onRecordSleep: _recordSelectedSleep,
          onAsk: (question) =>
              context.go('/', extra: {'agentPrefill': question}),
          rememberedBabyId: widget.runtime.currentSession.babyId,
        )
      : widget.chatFirstExperience
      ? ChatFirstBabyPage(
          controller: controller,
          onOpenDetails: () async => context.push('/baby/details'),
          onBabySelected: widget.onBabySelected,
          rememberedBabyId: widget.runtime.currentSession.babyId,
        )
      : BabyHomePage(
          controller: controller,
          onAsk: (text) => context.go('/', extra: {'agentPrefill': text}),
          onBabySelected: widget.onBabySelected,
          rememberedBabyId: widget.runtime.currentSession.babyId,
        );
  // The active page owns and disposes its controller. Only its view snapshot
  // survives navigation; no timer/listener continues on an unmounted page.
}

final babyModuleRoutes = <GoRoute>[];
