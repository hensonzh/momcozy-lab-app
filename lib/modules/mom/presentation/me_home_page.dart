import '../../../domain/mother/postpartum_stage.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../application/me_controller.dart';
import '../domain/me_experience.dart';
import 'me_design.dart';
import 'me_concerns.dart';
import 'me_profile_page.dart';
import 'me_manage_records.dart';
import 'me_record_sheet.dart';

class MeHomePage extends StatefulWidget {
  const MeHomePage({
    super.key,
    required this.controller,
    required this.onAsk,
    required this.onSharedRecord,
  });
  final MeController controller;
  final ValueChanged<String> onAsk;
  final Future<void> Function(BuildContext, MeMetric) onSharedRecord;
  @override
  State<MeHomePage> createState() => _MeHomePageState();
}

class _MeHomePageState extends State<MeHomePage> with WidgetsBindingObserver {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.controller.load());
    schedule();
  }

  void schedule() {
    timer?.cancel();
    final now = widget.controller.now();
    timer = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      () {
        widget.controller.load();
        schedule();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = widget.controller.now();
      if (widget.controller.day != DateTime(now.year, now.month, now.day)) {
        widget.controller.load();
      }
      schedule();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  Future<void> record(MeMetric kind) =>
      [MeMetric.feed, MeMetric.diaper, MeMetric.weight].contains(kind)
      ? widget.onSharedRecord(context, kind)
      : showMeRecordSheet(context, widget.controller, kind);
  Future<void> page(Widget page) => Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => page));
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(gradient: MeDesign.background),
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final state = c.state;
        if (state == null) {
          return Center(
            child: c.error == null
                ? const CircularProgressIndicator()
                : TextButton(onPressed: c.load, child: Text(c.error!)),
          );
        }
        final now = c.now();
        final name = state.profile['preferred_name'] as String? ?? '';
        final birth = DateTime.tryParse(
          state.profile['actual_delivery_date']?.toString() ?? '',
        );
        final days = birth == null
            ? null
            : DateTime(now.year, now.month, now.day).difference(birth).inDays;
        final greeting = now.hour < 12
            ? 'Good morning'
            : now.hour < 18
            ? 'Good afternoon'
            : 'Good evening';
        final active = state.active;
        final concern = active.firstOrNull;
        return RefreshIndicator(
          onRefresh: c.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 58),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 4,
                  children: [
                    Text(
                      '$greeting${name.isEmpty ? '' : ', $name'}',
                      style: MeDesign.text(
                        20,
                        weight: FontWeight.w700,
                        line: 34,
                      ),
                    ),
                    TextButton(
                      onPressed: () => page(MeProfilePage(controller: c)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'My profile ›',
                            style: MeDesign.text(
                              12,
                              color: MeDesign.rose,
                              line: 20,
                            ),
                          ),
                          if (days != null && days >= 0)
                            Text(
                              formatPostpartumDay(days),
                              style: MeDesign.text(
                                11,
                                color: const Color(0xff756966),
                                line: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(19, 15, 19, 19),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xfffae3e5), Color(0xffe8def7)],
                  ),
                  border: Border.all(color: const Color(0xffe4cbd8)),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            concern == null
                                ? 'Your focus right now'
                                : 'In progress',
                            style: MeDesign.text(
                              12,
                              weight: FontWeight.w700,
                              color: const Color(0xff93506e),
                              line: 20,
                            ),
                          ),
                        ),
                        if (concern != null)
                          InkWell(
                            onTap: () => page(
                              MeConcernsPage(controller: c, onRecord: record),
                            ),
                            child: Text(
                              'My focus ›',
                              style: MeDesign.text(12, color: MeDesign.rose),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      concern == null
                          ? 'What would you like to work on?'
                          : concern.labels.first,
                      style: MeDesign.text(
                        22,
                        weight: FontWeight.w700,
                        line: 32,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      concern == null
                          ? 'Start with what\'s on your mind now.\nMaybe feeding hurts, you\'re concerned about milk supply, or you\'re preparing to return to work.'
                          : concern.labels.length > 1
                          ? concern.labels.skip(1).join(', ')
                          : 'Keep the records that matter to you in one place.',
                      style: MeDesign.text(
                        12,
                        color: const Color(0xff70636b),
                        line: 18,
                      ),
                    ),
                    const SizedBox(height: 14),
                    MeButton(
                      concern == null
                          ? 'Choose what you\'d like to work on'
                          : 'View records and trends',
                      fontSize: 13,
                      weight: FontWeight.w500,
                      onPressed: () => concern == null
                          ? showMeConcernFlow(context, c)
                          : page(
                              MeConcernDetail(
                                controller: c,
                                concernId: concern.id,
                                onRecord: record,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => widget.onAsk(
                  'I\'d like to talk about feeding and recovery today.',
                ),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 74),
                  decoration: MeDesign.card(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      MeDesign.asset(
                        'AssetCozymateAvatar.png',
                        width: 42,
                        height: 42,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chat with Momcozy AI',
                              style: MeDesign.text(
                                14,
                                weight: FontWeight.w700,
                                line: 22,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Talk about how you feel or any feeding questions.',
                              style: MeDesign.text(
                                11,
                                color: const Color(0xff665d6e),
                                line: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      MeDesign.asset(
                        'IconArrowForward.svg',
                        width: 20,
                        height: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Today\'s records',
                      style: MeDesign.text(
                        18,
                        weight: FontWeight.w700,
                        line: 27,
                      ),
                    ),
                  ),
                  Flexible(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => page(MeManageRecords(controller: c)),
                      child: Text(
                        'Manage records ›',
                        style: MeDesign.text(
                          12,
                          color: MeDesign.rose,
                          line: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                'The more you record, the better Momcozy AI can support you',
                style: MeDesign.text(
                  11,
                  color: const Color(0xff70636b),
                  line: 18,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, box) {
                  final count = MediaQuery.textScalerOf(context).scale(14) > 21
                      ? 1
                      : 2;
                  final width = (box.maxWidth - (count - 1) * 12) / count;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final kind in state.visibleMetrics)
                        SizedBox(
                          width: width,
                          child: MeHomeMetric(
                            kind: kind,
                            observation: c.latest(kind),
                            failed: state.failedMetrics.contains(kind),
                            onTap: () => record(kind),
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (state.failedMetrics.isNotEmpty) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: c.load,
                  child: const Text(
                    'Some records could not load. Tap to try again.',
                  ),
                ),
              ],
              if (c.error != null) ...[
                const SizedBox(height: 12),
                MeError(message: c.error!),
                TextButton(onPressed: c.load, child: const Text('Try again')),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class MeHomeMetric extends StatelessWidget {
  const MeHomeMetric({
    super.key,
    required this.kind,
    required this.onTap,
    this.observation,
    this.failed = false,
  });
  final MeMetric kind;
  final VoidCallback onTap;
  final MeObservation? observation;
  final bool failed;
  @override
  Widget build(BuildContext context) {
    final date = observation?.occurredAt;
    final verticalScale = (MediaQuery.textScalerOf(context).scale(22) / 22)
        .clamp(1.0, double.infinity);
    return Semantics(
      button: true,
      label:
          '${kind.label}, ${observation?.displayValue ?? (failed ? 'Could not load' : 'Not recorded yet')}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            height: 106 * verticalScale,
            decoration: BoxDecoration(
              gradient: MeDesign.metricGradient(kind),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: .65)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  Positioned(
                    right: -38,
                    top: -24,
                    child: MeDesign.asset(
                      'DecorationAmbientRing.svg',
                      width: 114,
                      height: 114,
                    ),
                  ),
                  Positioned(
                    left: -23,
                    bottom: -42,
                    child: MeDesign.asset(
                      'DecorationAmbientPetal.svg',
                      width: 132,
                      height: 62,
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 26,
                    child: Opacity(
                      opacity: .84,
                      child: MeDesign.art(
                        kind,
                        kind == MeMetric.energy
                            ? 44
                            : (kind == MeMetric.sleep || kind == MeMetric.mood)
                            ? 48
                            : 50,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 13,
                    top: 11 * verticalScale,
                    child: Text(
                      kind.label,
                      style: MeDesign.text(14, color: const Color(0xff776e69)),
                    ),
                  ),
                  Positioned(
                    left: 13,
                    right: 60,
                    top: 35 * verticalScale,
                    child: Text(
                      observation?.displayValue ??
                          (failed ? 'Could not load' : 'Not recorded yet'),
                      style: MeDesign.text(
                        observation == null ? 16 : 22,
                        weight: FontWeight.w700,
                        color: observation == null
                            ? const Color(0xff807975)
                            : MeDesign.ink,
                      ),
                    ),
                  ),
                  if (date != null)
                    Positioned(
                      left: 13,
                      bottom: 13 * verticalScale,
                      child: Text(
                        'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                        style: MeDesign.text(
                          12,
                          color: const Color(0xff776e69),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 11,
                    top: 9,
                    child: Text(
                      '＋',
                      style: MeDesign.text(
                        15,
                        color: MeDesign.rose,
                        weight: FontWeight.w500,
                        line: 23,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
