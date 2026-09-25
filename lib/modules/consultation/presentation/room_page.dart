import 'dart:async';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../domain/care/appointment.dart';
import '../../../domain/care/consultation_room.dart';
import '../../../services/consultations/consultation_media.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../shared/zoned_time.dart';
import '../../services/presentation/appointment_summary.dart';
import '../../services/presentation/mom_appointment_widgets.dart';
import '../application/room_controller.dart';
import 'video_stage.dart';
import 'device_check_dialog.dart';
import 'device_preview_dialog.dart';
import 'consultation_start_dialog.dart';
import 'consultation_preparation.dart';
import 'consultation_outcome.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../services/consultations/device_check.dart';

class ConsultationRoomPage extends StatefulWidget {
  const ConsultationRoomPage({
    super.key,
    required this.createController,
    required this.onBack,
    required this.onIntake,
    required this.onProgress,
    required this.onRebook,
    this.onHome,
    this.createDeviceCheck,
    this.onCancel,
    this.overHome = false,
  });
  final bool overHome;
  final ConsultationRoomController Function() createController;
  final ConsultationDeviceCheck Function()? createDeviceCheck;
  final Future<void> Function(CareAppointment)? onCancel;
  final VoidCallback onBack;
  final VoidCallback? onHome;
  final Future<void> Function() onIntake;
  final void Function(CareAppointment) onProgress, onRebook;
  @override
  State<ConsultationRoomPage> createState() => _ConsultationRoomPageState();
}

class _ConsultationRoomPageState extends State<ConsultationRoomPage>
    with WidgetsBindingObserver {
  late final ConsultationRoomController controller = widget.createController();
  Timer? _timer;
  bool _allowPop = false, _leaving = false, _flowOpen = false;
  bool _leaveFailed = false;
  final _leaveFailureKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(controller.load()),
    );
    unawaited(controller.load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(controller.load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> _back() async {
    if (_leaving ||
        (!controller.isExpert &&
            (_flowOpen || (controller.busy && !controller.inRoom)))) {
      return;
    }
    _leaving = true;
    try {
      if (controller.inRoom || controller.wantsToJoin) {
        final leave = await showDialog<bool>(
          context: context,
          animationStyle: MomCozyMotion.animationStyle(context),
          builder: (context) => !controller.isExpert
              ? _leaveConfirmation(context)
              : AlertDialog(
                  scrollable: true,
                  title: const Text('Leave the consultation room for now?'),
                  content: const Text(
                    'Leaving will not end the consultation. You can rejoin from your appointment details.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Stay in room'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Leave for now'),
                    ),
                  ],
                ),
        );
        if (leave != true) {
          return;
        }
      }
      if (!mounted) return;
      if (_leaveFailed) setState(() => _leaveFailed = false);
      try {
        await controller.leave();
      } catch (_) {
        if (mounted) {
          setState(() => _leaveFailed = true);
          await WidgetsBinding.instance.endOfFrame;
          final noticeContext = _leaveFailureKey.currentContext;
          if (mounted && noticeContext != null && noticeContext.mounted) {
            await Scrollable.ensureVisible(noticeContext);
          }
        }
        return;
      }
      if (!mounted) return;
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) widget.onBack();
    } finally {
      _leaving = false;
    }
  }

  Widget _leaveConfirmation(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: MomSettingsFlowDialog(
      title: 'Leave the consultation room for now?',
      closeLabel: 'Close leave confirmation',
      onClose: () => Navigator.pop(context, false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Leaving will not end the consultation. You can rejoin from your appointment details.',
            style: MomHomeTokens.text(
              13,
              height: 1.55,
              color: MomHomeTokens.secondary,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay in room'),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave for now'),
          ),
        ],
      ),
    ),
  );

  bool get _isUserRoomContent =>
      !controller.isExpert &&
      controller.data != null &&
      (controller.data!.ended || controller.inRoom);

  bool get _useMomRoomScaffold =>
      _isUserRoomContent || (!controller.isExpert && controller.data == null);

  AppBar _userRoomAppBar() => AppBar(
    backgroundColor: MomHomeTokens.background,
    surfaceTintColor: Colors.transparent,
    toolbarHeight: MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 112 : 64,
    leading: IconButton(
      tooltip: 'Back',
      onPressed: _back,
      color: MomHomeTokens.rose,
      icon: const Icon(Icons.chevron_left),
    ),
    centerTitle: false,
    title: Text(
      'Video consultation',
      maxLines: 2,
      softWrap: true,
      overflow: TextOverflow.visible,
      style: MomHomeTokens.text(20, weight: FontWeight.w700),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => PopScope(
      canPop:
          _allowPop ||
          ((controller.isExpert || (!_flowOpen && !controller.busy)) &&
              !controller.inRoom &&
              !controller.wantsToJoin),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child:
          widget.overHome &&
              !controller.isExpert &&
              !controller.inRoom &&
              !(controller.data?.ended ?? false)
          ? Material(
              type: MaterialType.transparency,
              child: SafeArea(
                child: _flowOpen
                    ? const SizedBox.shrink()
                    : controller.data == null
                    ? _preparationDialog(
                        onClose: _back,
                        child: _roomLoadState(),
                      )
                    : _userPreparation(controller.data!),
              ),
            )
          : Scaffold(
              backgroundColor: _useMomRoomScaffold
                  ? MomHomeTokens.background
                  : null,
              appBar: _useMomRoomScaffold
                  ? _userRoomAppBar()
                  : !controller.isExpert &&
                        controller.data != null &&
                        !controller.data!.ended &&
                        !controller.inRoom
                  ? null
                  : AppBar(
                      toolbarHeight:
                          MediaQuery.textScalerOf(context).scale(1) > 1.4
                          ? 96
                          : controller.isExpert
                          ? kToolbarHeight
                          : 52,
                      leadingWidth: controller.isExpert
                          ? null
                          : MediaQuery.textScalerOf(context).scale(1) > 1.4
                          ? 88
                          : 64,
                      leading: controller.isExpert
                          ? BackButton(onPressed: _back)
                          : TextButton(
                              onPressed: _back,
                              style: TextButton.styleFrom(
                                foregroundColor: MomCozyColors.mutedForeground,
                              ),
                              child: const Text('Back'),
                            ),
                      centerTitle: !controller.isExpert,
                      title: Text(
                        'Video consultation',
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.visible,
                        style: controller.isExpert
                            ? null
                            : const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                      ),
                      bottom: controller.isExpert
                          ? null
                          : const PreferredSize(
                              preferredSize: Size.fromHeight(1),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Divider(height: 1),
                              ),
                            ),
                      actions: [
                        if (controller.isExpert)
                          IconButton(
                            tooltip: 'Refresh consultation status',
                            onPressed: controller.busy ? null : controller.load,
                            icon: const Icon(Icons.refresh),
                          ),
                      ],
                    ),
              body:
                  !controller.isExpert &&
                      controller.data != null &&
                      !controller.data!.ended &&
                      !controller.inRoom
                  ? _userPreparation(controller.data!)
                  : MomCozyPageBody(
                      maxWidth: controller.isExpert
                          ? 760
                          : MomCozyLayout.maxAppWidth,
                      child: _body(),
                    ),
            ),
    ),
  );
  Widget _preparationDialog({
    required VoidCallback? onClose,
    required Widget child,
  }) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: MomSettingsFlowDialog(
      title: 'Appointment details',
      closeLabel: 'Close appointment details',
      onClose: onClose,
      child: child,
    ),
  );

  Widget _userPreparation(ConsultationRoomContext data) => _preparationDialog(
    onClose: _flowOpen || controller.busy ? null : _back,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.message case final message?) _notice(message),
        if (controller.failure != null)
          TextButton(
            onPressed: controller.busy || _flowOpen ? null : controller.load,
            child: const Text('Refresh consultation status'),
          ),
        if (controller.pendingEnd)
          TextButton(
            onPressed: controller.busy ? null : controller.retryEnd,
            child: const Text('Check consultation outcome'),
          ),
        ConsultationPreparation(
          data: data,
          now: () => controller.now,
          busy: controller.busy || _flowOpen || controller.pendingEnd,
          onStart: _startConsultation,
          onIntake: () async {
            await widget.onIntake();
            if (mounted) await controller.load();
          },
          onRebook: () => widget.onRebook(data.appointment),
          onCancel:
              widget.onCancel != null &&
                  !data.active &&
                  data.appointment.status == AppointmentStatus.confirmed
              ? () => _cancelAppointment(data.appointment)
              : null,
        ),
      ],
    ),
  );

  Future<void> _cancelAppointment(CareAppointment appointment) async {
    if (_flowOpen || controller.busy) return;
    setState(() => _flowOpen = true);
    try {
      await widget.onCancel!(appointment);
      if (mounted) await controller.load();
    } finally {
      if (mounted) setState(() => _flowOpen = false);
    }
  }

  Widget _roomLoadState() => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: controller.loading || controller.failure == null
        ? Semantics(
            liveRegion: true,
            child: MomSettingsCard(
              children: [
                Text(
                  'Loading consultation details',
                  style: MomHomeTokens.text(18, weight: FontWeight.w700),
                ),
                Text(
                  'When the appointment details load, you can review how to prepare.',
                  style: MomHomeTokens.text(
                    13,
                    color: MomHomeTokens.secondary,
                    height: 1.55,
                  ),
                ),
                const LinearProgressIndicator(minHeight: 4),
              ],
            ),
          )
        : ProductErrorView(
            failure: controller.failure!,
            onRetry: controller.load,
            useMomStyle: true,
          ),
  );

  Widget _body() {
    if (!controller.isExpert && controller.data == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(MomHomeTokens.inset),
        child: _roomLoadState(),
      );
    }
    if (controller.loading && controller.data == null) {
      return const ProductLoadingView();
    }
    final data = controller.data;
    if (data == null) {
      return controller.failure == null
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              padding: MomCozyInsets.page,
              child: ProductErrorView(
                failure: controller.failure!,
                onRetry: controller.load,
              ),
            );
    }
    if (!controller.isExpert && data.ended) {
      return Theme(
        data: momSettingsTheme(Theme.of(context)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_leaveFailed) ...[
                  _leaveFailureNotice(),
                  const SizedBox(height: 14),
                ],
                if (controller.message case final message?) ...[
                  _sessionNotice(message),
                  const SizedBox(height: 14),
                ],
                if (controller.pendingEnd) ...[
                  FilledButton(
                    onPressed: controller.busy ? null : controller.retryEnd,
                    child: const Text('Check consultation outcome'),
                  ),
                  const SizedBox(height: 14),
                ],
                UserConsultationOutcome(
                  data: data,
                  onSummary: () => widget.onProgress(data.appointment),
                  onRebook: () => widget.onRebook(data.appointment),
                  onHome: widget.onHome ?? widget.onBack,
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (!controller.isExpert && controller.inRoom && !data.ended) {
      return _userSession(data);
    }
    return ListView(
      padding: MomCozyInsets.page,
      children: [
        if (_leaveFailed) _leaveFailureNotice(),
        if (controller.message case final message?) _notice(message),
        if (controller.pendingEnd)
          FilledButton(
            onPressed: controller.busy ? null : controller.retryEnd,
            child: const Text('Check consultation outcome'),
          ),
        if (data.ended)
          _outcome(data)
        else if (!controller.inRoom)
          _expertPreparation(data)
        else ...[
          _sessionHeader(data),
          const SizedBox(height: MomCozySpacing.headingGap),
          ConsultationVideoStage(data: data, media: controller.media),
          if (controller.media.error case final error?) _notice(error),
          if (controller.media.weakNetwork)
            _notice('Your connection is weak. Audio and video may be choppy.'),
          if (controller.media.audioPlaybackBlocked)
            TextButton(
              onPressed: controller.media.enableAudio,
              child: const Text('Tap to enable call audio'),
            ),
          const SizedBox(height: MomCozySpacing.content),
          ConsultationMediaControls(media: controller.media, onLeave: _back),
          if (controller.media.state ==
              ConsultationMediaState.disconnected) ...[
            const SizedBox(height: MomCozySpacing.content),
            FilledButton(
              onPressed: controller.canEnter ? controller.enter : null,
              child: const Text('Reconnect'),
            ),
            TextButton(
              onPressed: controller.busy ? null : controller.leave,
              child: const Text('Back to preparation'),
            ),
          ],
          if (controller.isExpert) _expertActions(data),
        ],
      ],
    );
  }

  Widget _userSession(ConsultationRoomContext data) {
    final media = controller.media;
    final reconnecting = media.state == ConsultationMediaState.reconnecting;
    return Theme(
      data: momSettingsTheme(Theme.of(context)),
      child: RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_leaveFailed) ...[
                  _leaveFailureNotice(),
                  const SizedBox(height: 14),
                ],
                if (controller.message case final message?) ...[
                  _sessionNotice(message),
                  const SizedBox(height: 14),
                ],
                MomServiceExpertIdentity(
                  name: data.appointment.publicProviderName,
                  label: 'Your consultant',
                ),
                const SizedBox(height: 8),
                Text(
                  '${appointmentDay(data.appointment.startsAt, data.appointment.timezone)} · ${zonedRange(data.appointment.startsAt, data.appointment.endsAt, data.appointment.timezone)}',
                  style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: MomHomeTokens.mint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      reconnecting
                          ? 'Reconnect'
                          : data.active
                          ? 'In consultation'
                          : 'Waiting room',
                      style: MomHomeTokens.text(
                        11,
                        weight: FontWeight.w700,
                        color: MomHomeTokens.teal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ConsultationVideoStage(data: data, media: media),
                const SizedBox(height: 14),
                if (media.error case final error?) ...[
                  _sessionNotice(error),
                  const SizedBox(height: 14),
                ],
                if (media.weakNetwork) ...[
                  _sessionNotice(
                    'Your connection is weak. Audio and video may be choppy.',
                  ),
                  const SizedBox(height: 14),
                ],
                if (media.audioPlaybackBlocked) ...[
                  OutlinedButton(
                    onPressed: media.busy ? null : media.enableAudio,
                    child: const Text('Tap to enable call audio'),
                  ),
                  const SizedBox(height: 14),
                ],
                ConsultationMediaControls(
                  media: media,
                  onLeave: _back,
                  compact: true,
                ),
                if (media.state == ConsultationMediaState.disconnected) ...[
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: controller.canEnter ? controller.enter : null,
                    child: const Text('Reconnect'),
                  ),
                  TextButton(
                    onPressed: controller.busy ? null : controller.leave,
                    child: const Text('Back to preparation'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionNotice(String text) => Semantics(
    liveRegion: true,
    child: MomSettingsCard(
      color: MomCozyColors.amberSoft,
      children: [Text(text, style: MomHomeTokens.text(13, height: 1.55))],
    ),
  );

  Widget _leaveFailureNotice() => KeyedSubtree(
    key: _leaveFailureKey,
    child: _isUserRoomContent
        ? _sessionNotice(
            'Could not leave the consultation room. Tap Leave Room again to try.',
          )
        : _notice(
            'Could not leave the consultation room. Tap Leave Room again to try.',
          ),
  );

  Widget _notice(String text) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: MomCozySpacing.headingGap),
      child: MomCozySurface(
        color: MomCozyColors.amberSoft,
        padding: MomCozyInsets.compactCard,
        child: Text(
          text,
          style: const TextStyle(fontSize: MomCozyTypography.secondarySize),
        ),
      ),
    ),
  );
  Widget _expertPreparation(ConsultationRoomContext data) {
    final open = data.windowOpen(controller.now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppointmentSummary(
          appointment: data.appointment,
          title: 'This consultation',
        ),
        const SizedBox(height: MomCozySpacing.section),
        const Text(
          'Prepare for your consultation',
          style: TextStyle(
            fontSize: MomCozyTypography.headingSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: MomCozySpacing.compact),
        const Text(
          'Find a quiet, well-lit place and get your camera and microphone ready.',
          style: TextStyle(
            color: MomCozyColors.mutedForeground,
            height: MomCozyTypography.lineHeight,
          ),
        ),
        const SizedBox(height: MomCozySpacing.page),
        OutlinedButton.icon(
          onPressed: controller.busy
              ? null
              : () => showDialog<void>(
                  context: context,
                  animationStyle: MomCozyMotion.animationStyle(context),
                  builder: (context) => const ConsultationDevicePreviewDialog(),
                ),
          icon: const Icon(Icons.videocam_outlined),
          label: const Text('Check camera & microphone'),
        ),
        const SizedBox(height: MomCozySpacing.content),
        if (data.videoProvider == VideoProvider.sandbox)
          _notice(
            'This is a simulated consultation to test both sides. Remote audio and video are not transmitted.',
          ),
        if (data.videoProvider == VideoProvider.disabled)
          _notice(
            'Video consultations are not available yet. Try again later.',
          ),
        if (!open)
          _notice(
            controller.now.isBefore(data.opensAt)
                ? 'The consultation room opens ${appointmentDay(data.opensAt, data.appointment.timezone)} at ${zonedClock(data.opensAt, data.appointment.timezone)} (10 minutes before your appointment).'
                : 'The join window has closed. Return to booking to reschedule.',
          ),
        if (controller.isExpert && !data.videoConsent) ...[
          _notice('Waiting for the client to consent to video.'),
          const SizedBox(height: MomCozySpacing.content),
        ],
        const SizedBox(height: MomCozySpacing.card),
        if (controller.wantsToJoin &&
            data.consultation?.roomStatus == VideoRoomStatus.creating) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: MomCozySpacing.content),
          const Text(
            'The consultation room is getting ready. Please wait.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MomCozySpacing.content),
        ],
        FilledButton(
          onPressed: controller.canEnter ? controller.enter : null,
          child: Text(
            controller.busy
                ? 'Joining…'
                : data.active
                ? 'Rejoin consultation room'
                : 'Join consultation',
          ),
        ),
        if (controller.isExpert && controller.canMarkNoShow)
          TextButton(
            onPressed: () => _end(ConsultationEndReason.userNoShow),
            child: const Text('Mark client as no-show'),
          ),
      ],
    );
  }

  Future<void> _startConsultation() async {
    final data = controller.data;
    if (_flowOpen ||
        controller.busy ||
        controller.inRoom ||
        controller.pendingEnd ||
        data == null ||
        !data.windowOpen(controller.now) ||
        !data.intakeReady ||
        !data.caseConsent ||
        data.videoProvider == VideoProvider.disabled) {
      return;
    }
    setState(() => _flowOpen = true);
    try {
      final ready = await showDialog<bool>(
        context: context,
        animationStyle: MomCozyMotion.animationStyle(context),
        builder: (dialogContext) => ConsultationDeviceCheckDialog(
          createCheck: widget.createDeviceCheck,
          onSuccess: () => Navigator.pop(dialogContext, true),
        ),
      );
      if (!mounted || ready != true) return;
      await showDialog<void>(
        context: context,
        animationStyle: MomCozyMotion.animationStyle(context),
        barrierDismissible: false,
        builder: (_) => ConsultationStartDialog(
          controller: controller,
          onIntake: widget.onIntake,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _flowOpen = false);
        if (widget.overHome && !controller.inRoom && !controller.wantsToJoin) {
          widget.onBack();
        }
      }
    }
  }

  Widget _sessionHeader(ConsultationRoomContext data) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const CircleAvatar(
        radius: 18,
        backgroundColor: MomCozyColors.careSoft,
        foregroundColor: MomCozyColors.care,
        child: Icon(Icons.person_outline, size: MomCozyIconSizes.standard),
      ),
      const SizedBox(width: MomCozySpacing.statusGap),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${data.appointment.publicProviderName} · IBCLC',
              style: const TextStyle(
                fontSize: MomCozyTypography.captionSize,
                color: MomCozyColors.mutedForeground,
              ),
            ),
            const SizedBox(height: MomCozySpacing.xs),
            Text(
              '${appointmentDay(data.appointment.startsAt, data.appointment.timezone)} · ${zonedRange(data.appointment.startsAt, data.appointment.endsAt, data.appointment.timezone)}',
              style: const TextStyle(
                fontSize: MomCozyTypography.captionSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: MomCozySpacing.compact),
      MomCozyBadge(
        data.active ? 'In consultation' : 'Waiting room',
        color: MomCozyColors.care,
        background: MomCozyColors.careSoft,
      ),
    ],
  );
  Widget _expertActions(ConsultationRoomContext data) => Padding(
    padding: const EdgeInsets.only(top: MomCozySpacing.card),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!data.active)
          FilledButton(
            onPressed: controller.canStart ? controller.start : null,
            child: const Text('Start consultation'),
          ),
        if (data.active)
          FilledButton(
            onPressed: controller.busy
                ? null
                : () => _end(ConsultationEndReason.completed),
            child: const Text('Finish consultation'),
          ),
        TextButton(
          onPressed: controller.busy ? null : _interrupted,
          child: const Text('Cannot continue consultation'),
        ),
        if (controller.canMarkNoShow)
          TextButton(
            onPressed: () => _end(ConsultationEndReason.userNoShow),
            child: const Text('Mark client as no-show'),
          ),
      ],
    ),
  );
  Future<void> _interrupted() async {
    final reason = await showModalBottomSheet<ConsultationEndReason>(
      context: context,
      sheetAnimationStyle: MomCozyMotion.animationStyle(context),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: MomCozyInsets.card,
                child: Text(
                  'Choose a reason for ending',
                  style: TextStyle(
                    fontSize: MomCozyTypography.sectionSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ListTile(
                title: const Text('Technical or network issue'),
                subtitle: const Text(
                  'End this consultation without using a session',
                ),
                onTap: () => Navigator.pop(
                  context,
                  ConsultationEndReason.technicalFailure,
                ),
              ),
              ListTile(
                title: const Text('Referral or further medical support needed'),
                subtitle: const Text(
                  'End this consultation and complete the clinical note later',
                ),
                onTap: () => Navigator.pop(
                  context,
                  ConsultationEndReason.safetyEscalation,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (reason != null && mounted) await _end(reason);
  }

  Future<void> _end(ConsultationEndReason reason) async {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: MomCozyMotion.animationStyle(context),
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('End this consultation?'),
        content: Text(
          reason == ConsultationEndReason.completed
              ? 'Finishing uses one consultation. Please complete the consultation notes afterward.'
              : 'This will not use a consultation. The reason will be saved in the service history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue consultation'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End consultation'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.end(reason);
  }

  Widget _outcome(ConsultationRoomContext data) {
    final (title, description) = switch (data.consultation?.endReason) {
      ConsultationEndReason.technicalFailure => (
        'Video connection could not continue',
        'No consultation was used. You can book another time.',
      ),
      ConsultationEndReason.userNoShow => (
        'This consultation could not start',
        'No consultation was used. Book again if you need more support.',
      ),
      ConsultationEndReason.safetyEscalation => (
        'This consultation has ended',
        'Follow your consultant\'s guidance for further support. Your follow-up records will appear in Service Progress.',
      ),
      _ =>
        data.appointment.status == AppointmentStatus.cancelled
            ? (
                'Appointment canceled',
                'You can book another consultation if you need more support.',
              )
            : (
                'This consultation has ended',
                controller.isExpert
                    ? 'Please complete the consultation notes and follow-up recommendations.'
                    : 'Your IBCLC is preparing recommendations. You can view them in Service Progress.',
              ),
    };
    return MomCozySurface(
      padding: EdgeInsets.zero,
      child: ProductEmptyView(
        title: title,
        description: description,
        action: Column(
          children: [
            FilledButton(
              onPressed: () => widget.onProgress(data.appointment),
              child: Text(
                controller.isExpert
                    ? 'Complete consultation notes'
                    : 'View consultation summary',
              ),
            ),
            if (!controller.isExpert &&
                data.consultation?.endReason != ConsultationEndReason.completed)
              TextButton(
                onPressed: () => widget.onRebook(data.appointment),
                child: const Text('Book another appointment'),
              ),
          ],
        ),
      ),
    );
  }
}
