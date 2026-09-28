import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../app/primary_tab_activity.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/design_system/momcozy_motion.dart';
import '../application/schedule_controller.dart';
import '../data/schedule_api_repository.dart';
import '../domain/schedule.dart';
import 'personal_schedule_editor.dart';
import 'schedule_agenda.dart';
import 'schedule_calendar.dart';
import 'schedule_design.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({
    super.key,
    required this.repository,
    required this.timezoneProvider,
    this.now = DateTime.now,
  });
  final ScheduleRepository repository;
  final Future<String> Function() timezoneProvider;
  final DateTime Function() now;
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  bool _expanded = true;
  final _tabRefresh = PrimaryTabRefresh(3);
  late final controller = ScheduleController(
    repository: widget.repository,
    timezoneProvider: widget.timezoneProvider,
    now: widget.now,
  );
  @override
  void initState() {
    super.initState();
    unawaited(controller.load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tabRefresh.shouldRefresh(context, widget.now())) {
      unawaited(controller.load());
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: Material(
      key: const ValueKey('route-page-/schedule'),
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: ScheduleDesign.background),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final state = controller.state;
            // The shared navigation reserves 18px for its raised avatar. Content
            // extends through that transparent region, stopping at its 82px chrome.
            final navigationInset = math.max(
              0.0,
              MediaQuery.paddingOf(context).bottom - 18,
            );
            return Stack(
              children: [
                Positioned.fill(
                  bottom: navigationInset,
                  child: RefreshIndicator(
                    onRefresh: controller.load,
                    child: ListView(
                      key: const PageStorageKey('schedule-scroll'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 11, 16, 112),
                      children: [
                        _header(state.page != null),
                        const SizedBox(height: 9),
                        if (state.page == null) ...[
                          if (state.phase == SchedulePhase.failure)
                            _offline(state.error!)
                          else
                            _loading(),
                        ] else ...[
                          if (state.error != null) ...[
                            _refreshNotice(),
                            const SizedBox(height: 14),
                          ],
                          ScheduleCalendar(
                            state: state,
                            expanded: _expanded,
                            onSelect: controller.select,
                            onToday: () => controller.select(
                              LocalDate.fromDateTime(widget.now()),
                            ),
                            onShift: (amount) => _expanded
                                ? controller.shiftMonth(amount)
                                : controller.select(
                                    state.selected.addDays(amount * 7),
                                  ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '${state.selected.month}/${state.selected.day}',
                            key: const ValueKey('schedule-selected-date'),
                            style: ScheduleDesign.text(
                              18,
                              bold: true,
                              lineHeight: 25,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (!controller.hasCurrentMonth &&
                              state.page!.agendaOn(state.selected).isEmpty)
                            state.phase == SchedulePhase.loading
                                ? _loading()
                                : Text(
                                    'Could not load this month\'s schedule. Please try again.',
                                    style: ScheduleDesign.text(
                                      13,
                                      color: MomHomeTokens.secondary,
                                    ),
                                  )
                          else
                            ScheduleAgenda(
                              state: state,
                              onEdit: (entry) => _editPersonal(existing: entry),
                              onDelete: _deletePersonal,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (state.page != null)
                  Positioned(
                    right: 16,
                    bottom: navigationInset + 48,
                    child: Container(
                      key: const ValueKey('schedule-add'),
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: ScheduleDesign.fabShadow,
                      ),
                      child: Material(
                        color: MomHomeTokens.rose,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _editPersonal(),
                          child: Tooltip(
                            message: 'Add to schedule',
                            child: Semantics(
                              button: true,
                              label: 'Add to schedule',
                              excludeSemantics: true,
                              child: Center(
                                child: Text(
                                  '+',
                                  style: ScheduleDesign.text(
                                    24,
                                    bold: true,
                                    color: MomHomeTokens.surface,
                                    lineHeight: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _header(bool ready) => LayoutBuilder(
    builder: (context, constraints) {
      final titleStyle = ScheduleDesign.text(24, bold: true, lineHeight: 34);
      final labelStyle = ScheduleDesign.text(
        12,
        bold: true,
        color: MomHomeTokens.rose,
        lineHeight: 18,
      );
      final label = _expanded ? 'Collapse calendar' : 'Expand calendar';
      final scaler = MediaQuery.textScalerOf(context);
      double textWidth(String value, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: value, style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      }

      final title = Text('Schedule', style: titleStyle);
      if (!ready) {
        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(height: 44),
          ],
        );
      }
      final buttonWidth = math.min(
        constraints.maxWidth,
        math.max(100.0, textWidth(label, labelStyle) + 52),
      );
      final button = SizedBox(
        width: buttonWidth,
        child: OutlinedButton(
          key: const ValueKey('schedule-calendar-toggle'),
          onPressed: () => setState(() => _expanded = !_expanded),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .8),
            side: const BorderSide(color: Color(0xffe5d9e5)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: const StadiumBorder(),
            minimumSize: const Size(100, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: Text(label, style: labelStyle)),
              const SizedBox(width: 6),
              RotatedBox(
                quarterTurns: _expanded ? 0 : 2,
                child: SvgPicture.asset(
                  'assets/images/schedule_chevron.svg',
                  width: 14,
                  height: 14,
                ),
              ),
            ],
          ),
        ),
      );
      if (textWidth('Schedule', titleStyle) + 12 + buttonWidth >
          constraints.maxWidth) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            title,
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: button),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: title),
          button,
        ],
      );
    },
  );

  Widget _loading() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: MomHomeTokens.surface,
      borderRadius: BorderRadius.circular(22),
    ),
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: MomHomeTokens.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Loading schedule', style: ScheduleDesign.text(18, bold: true)),
        const SizedBox(height: 14),
        Text(
          'Your personal schedule items will appear here.',
          style: ScheduleDesign.text(13, color: MomHomeTokens.secondary),
        ),
        const SizedBox(height: 14),
        const LinearProgressIndicator(minHeight: 4, color: MomHomeTokens.rose),
      ],
    ),
  );

  Widget _offline(ProductFailure failure) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 56, 16, 40),
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Color(0xfff7eff7),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SvgPicture.asset(
              'assets/images/schedule_offline.svg',
              width: 22.7,
              height: 21.7,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          failure.kind == ProductFailureKind.offline
              ? 'Could not connect'
              : 'Could not load schedule',
          textAlign: TextAlign.center,
          style: ScheduleDesign.text(18, bold: true, lineHeight: 26),
        ),
        const SizedBox(height: 12),
        Text(
          failure.kind == ProductFailureKind.offline
              ? 'Connect to the internet to view your schedule'
              : 'Please try again later',
          textAlign: TextAlign.center,
          style: ScheduleDesign.text(
            13,
            color: MomHomeTokens.secondary,
            lineHeight: 20,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 116,
          height: 44,
          child: FilledButton(
            onPressed: controller.load,
            style: FilledButton.styleFrom(
              backgroundColor: MomHomeTokens.rose,
              shape: const StadiumBorder(),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              'Try again',
              style: ScheduleDesign.text(
                13,
                bold: true,
                color: Colors.white,
                lineHeight: 20,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _refreshNotice() => Container(
    constraints: const BoxConstraints(minHeight: 76),
    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
    decoration: BoxDecoration(
      color: MomHomeTokens.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffe8e0e6)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Could not refresh',
                style: ScheduleDesign.text(14, bold: true, lineHeight: 20),
              ),
              const SizedBox(height: 4),
              Text(
                'Your last loaded schedule is still available',
                style: ScheduleDesign.text(
                  12,
                  color: MomHomeTokens.secondary,
                  lineHeight: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 64,
          height: 44,
          child: TextButton(
            onPressed: () async {
              await controller.load();
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xfff7eff7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Try again'),
          ),
        ),
      ],
    ),
  );

  Future<void> _editPersonal({PersonalScheduleEntry? existing}) async {
    await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      animationStyle: MomCozyMotion.animationStyle(context),
      barrierDismissible: false,
      builder: (_) => PersonalScheduleEditor(
        controller: controller,
        existing: existing,
        now: widget.now,
      ),
    );
  }

  Future<void> _deletePersonal(PersonalScheduleEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      animationStyle: MomCozyMotion.animationStyle(context),
      builder: (_) => PersonalScheduleDeleteDialog(entry: entry),
    );
    if (confirmed != true || !mounted) return;
    try {
      await controller.deletePersonal(entry);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not delete. Please try again.'),
            action: SnackBarAction(
              label: 'Try again',
              onPressed: () => _deletePersonal(entry),
            ),
          ),
        );
      }
    }
  }
}
