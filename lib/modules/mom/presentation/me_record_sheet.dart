import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../baby/presentation/baby_design.dart';
import '../application/me_controller.dart';
import '../domain/me_experience.dart';
import 'me_design.dart';

Future<void> showMeRecordSheet(
  BuildContext context,
  MeController controller,
  MeMetric kind,
) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: const Color(0xfffffcf9),
  barrierColor: MeDesign.ink.withValues(alpha: .30),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (context) => MeRecordSheet(controller: controller, kind: kind),
);
const meQuickOptions = {
  MeMetric.energy: ['Energized', 'Managing', 'Exhausted'],
  MeMetric.sleep: ['Less than 3 hours', '3–4 hours', '4–5 hours', '5–6 hours', 'Over 6 hours', 'Not sure'],
  MeMetric.mood: ['Having a hard day', 'Okay', 'Good'],
};

class MeRecordSheet extends StatefulWidget {
  const MeRecordSheet({
    super.key,
    required this.controller,
    required this.kind,
  });
  final MeController controller;
  final MeMetric kind;
  @override
  State<MeRecordSheet> createState() => _MeRecordSheetState();
}

class _MeRecordSheetState extends State<MeRecordSheet> {
  final id = const Uuid().v4();
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(),
      note = TextEditingController(),
      duration = TextEditingController();
  String? value, side, phase, impact, swallow, carer;
  String action = 'Add a bag';
  double pain = 0;
  bool busy = false, failed = false;
  late DateTime at = widget.controller.now();
  late final MeObservation? linkedFeed = _linkedFeed();
  MeObservation? _linkedFeed() {
    if (![
      MeMetric.pain,
      MeMetric.latch,
      MeMetric.bottle,
    ].contains(widget.kind)) {
      return null;
    }
    final today = widget.controller.now();
    final records =
        (widget.controller.state?.records ?? const <MeObservation>[])
            .where(
              (e) =>
                  e.kind == MeMetric.feed &&
                  e.occurredAt.year == today.year &&
                  e.occurredAt.month == today.month &&
                  e.occurredAt.day == today.day &&
                  (widget.kind == MeMetric.pain ||
                      (widget.kind == MeMetric.latch
                          ? e.fields['feeding_method'] == 'breastfeeding'
                          : e.fields['feeding_method'] != 'breastfeeding')),
            )
            .toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return records.firstOrNull;
  }

  String get linkedHelp {
    final record = linkedFeed!;
    final time =
        '${record.occurredAt.hour.toString().padLeft(2, '0')}:${record.occurredAt.minute.toString().padLeft(2, '0')}';
    final method = record.fields['feeding_method'] == 'breastfeeding'
        ? 'Nursing'
        : 'Bottle feeding';
    return 'Linked to your $method record from today at $time.';
  }

  bool get quick => meQuickOptions.containsKey(widget.kind);
  bool get valid => quick
      ? value != null
      : widget.kind == MeMetric.pain
      ? side != null && phase != null && impact != null
      : (widget.kind == MeMetric.latch || widget.kind == MeMetric.bottle)
      ? value != null
      : double.tryParse(amount.text) != null &&
            (widget.kind != MeMetric.pump || side != null);
  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    duration.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !valid || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await widget.controller.saveRecord(
        MeObservation(
          id: id,
          kind: widget.kind,
          occurredAt: at,
          value:
              quick ||
                  (widget.kind == MeMetric.latch ||
                      widget.kind == MeMetric.bottle)
              ? value!
              : widget.kind == MeMetric.pain
              ? '${pain.round()} / 10'
              : '${amount.text} ml',
          fields: {
            if (linkedFeed != null) 'feeding_record_id': linkedFeed!.id,
            if (side != null) 'side': side,
            if (phase != null) 'phase': phase,
            if (impact != null) 'impact': impact,
            if (swallow != null) 'swallow': swallow,
            if (carer != null) 'carer': carer,
            if (widget.kind == MeMetric.pain) 'pain': pain.round(),
            if (!quick) 'note': note.text,
            if (widget.kind == MeMetric.storage) 'action': action,
            if (amount.text.isNotEmpty) 'volume_ml': double.parse(amount.text),
            if (duration.text.isNotEmpty)
              'duration_minutes': int.parse(duration.text),
          },
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          failed = true;
        });
      }
    }
  }

  Widget field(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 17),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: MeDesign.text(12, color: MeDesign.muted, line: 18)),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
  Widget dropdown(
    String title,
    List<String> options,
    String? current,
    ValueChanged<String?> changed,
  ) => field(
    title,
    DropdownButtonFormField<String>(
      initialValue: current,
      items: options
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: busy ? null : changed,
      decoration: const InputDecoration(hintText: 'Please select'),
      style: MeDesign.text(14),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final title = switch (kind) {
      MeMetric.energy => 'How is your energy today?',
      MeMetric.sleep => 'About how long did you sleep last night?',
      MeMetric.mood => 'How are you feeling right now?',
      MeMetric.pain => 'Did feeding hurt this time?',
      MeMetric.latch => 'How was your baby\'s latch?',
      MeMetric.bottle => 'How did your baby take the bottle?',
      MeMetric.storage => 'Update stored milk',
      _ => 'Log a pumping session',
    };
    return PopScope(
      canPop: !busy,
      child: Theme(
        data: BabyDesign.theme(Theme.of(context)),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.sizeOf(context).height -
                    MediaQuery.paddingOf(context).top -
                    24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: 39,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xffd9ceca),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 42,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: MeDesign.text(
                                    18,
                                    weight: FontWeight.w700,
                                    line: 27,
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: const Offset(14, 0),
                                child: IconButton(
                                  tooltip: 'Close',
                                  onPressed: busy
                                      ? null
                                      : () => Navigator.pop(context),
                                  icon: Text(
                                    '×',
                                    style: MeDesign.text(
                                      22,
                                      color: MeDesign.muted,
                                      line: 33,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (quick) ...[
                          Text(
                            'Record how you feel right now. You can update it later.',
                            style: MeDesign.text(
                              12,
                              color: MeDesign.muted,
                              line: 18,
                            ),
                          ),
                          const SizedBox(height: 27),
                          LayoutBuilder(
                            builder: (context, box) {
                              final columns =
                                  MediaQuery.textScalerOf(context).scale(12) >
                                      18
                                  ? 2
                                  : 3;
                              return Wrap(
                                spacing: 7,
                                runSpacing: 14,
                                children: [
                                  for (final option in meQuickOptions[kind]!)
                                    SizedBox(
                                      width:
                                          (box.maxWidth - 7 * (columns - 1)) /
                                          columns,
                                      child: Semantics(
                                        selected: value == option,
                                        child: OutlinedButton(
                                          onPressed: busy
                                              ? null
                                              : () => setState(
                                                  () => value = option,
                                                ),
                                          style: OutlinedButton.styleFrom(
                                            minimumSize: const Size.fromHeight(
                                              44,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 10,
                                            ),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            backgroundColor: value == option
                                                ? BabyDesign.selected
                                                : const Color(0xfffffcf9),
                                            foregroundColor: value == option
                                                ? BabyDesign.selectedInk
                                                : MeDesign.rose,
                                            side: BorderSide(
                                              color: value == option
                                                  ? Colors.transparent
                                                  : const Color(0xffe9dfdc),
                                            ),
                                            shape: const StadiumBorder(),
                                            textStyle: MeDesign.text(
                                              12,
                                              weight: FontWeight.w700,
                                              line: 21,
                                            ),
                                          ),
                                          child: Text(
                                            option,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 74),
                          Text(
                            'You do not need to fill out the other items.',
                            style: MeDesign.text(12, color: MeDesign.muted),
                          ),
                          const SizedBox(height: 24),
                        ] else ...[
                          Text(
                            linkedFeed != null
                                ? linkedHelp
                                : switch (kind) {
                                    MeMetric.pump => 'Record the amount you pumped, without setting a target you have to meet.',
                                    MeMetric.storage => 'Track bags you add or use to keep your stored milk up to date.',
                                    MeMetric.bottle => 'Link an existing bottle feeding instead of logging the amount again.',
                                    _ => 'Record how this feeding felt for you.',
                                  },
                            style: MeDesign.text(
                              12,
                              color: MeDesign.muted,
                              line: 18,
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (kind == MeMetric.pain) ...[
                            field(
                              'Which side feels uncomfortable?',
                              BabyChoices<String>(
                                options: const {
                                  'Left side': 'Left side',
                                  'Right side': 'Right side',
                                  'Both sides': 'Both sides',
                                },
                                selected: side,
                                onChanged: (v) => setState(() => side = v),
                                columns: 3,
                                enabled: !busy,
                                height: 44,
                                radius: 22,
                              ),
                            ),
                            dropdown(
                              'When did it hurt?',
                              ['When latching', 'During feeding', 'After feeding', 'While pumping'],
                              phase,
                              (v) => setState(() => phase = v),
                            ),
                            field(
                              'Pain level',
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    '${pain.round()} / 10',
                                    style: MeDesign.text(
                                      22,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  Slider(
                                    value: pain,
                                    max: 10,
                                    divisions: 10,
                                    activeColor: MeDesign.rose,
                                    onChanged: busy
                                        ? null
                                        : (v) => setState(() => pain = v),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '0 No pain',
                                        style: MeDesign.text(
                                          11,
                                          color: MeDesign.muted,
                                        ),
                                      ),
                                      Text(
                                        '10 Most severe',
                                        style: MeDesign.text(
                                          11,
                                          color: MeDesign.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            dropdown(
                              'How did it affect feeding?',
                              ['Could continue', 'Needed a break', 'Could not continue'],
                              impact,
                              (v) => setState(() => impact = v),
                            ),
                          ],
                          if (kind == MeMetric.latch) ...[
                            dropdown(
                              'How was the latch?',
                              ['Stayed latched', 'Came off easily', 'Could not latch'],
                              value,
                              (v) => setState(() => value = v),
                            ),
                            dropdown(
                              'Did you notice swallowing? (optional)',
                              ['Yes', 'No', 'Not sure'],
                              swallow,
                              (v) => setState(() => swallow = v),
                            ),
                          ],
                          if (kind == MeMetric.bottle) ...[
                            dropdown(
                              'How did your baby respond?',
                              ['Fed willingly', 'Took some', 'Reluctant', 'Refused'],
                              value,
                              (v) => setState(() => value = v),
                            ),
                            dropdown(
                              'Who fed your baby? (optional)',
                              ['Me', 'Partner', 'Family', 'Care professional'],
                              carer,
                              (v) => setState(() => carer = v),
                            ),
                          ],
                          if (kind == MeMetric.storage) ...[
                            dropdown(
                              'What would you like to do?',
                              ['Add a bag', 'Use a bag'],
                              action,
                              (v) => setState(() => action = v!),
                            ),
                          ],
                          if (kind == MeMetric.pump ||
                              kind == MeMetric.storage ||
                              kind == MeMetric.bottle) ...[
                            field(
                              kind == MeMetric.storage
                                  ? 'Date stored'
                                  : kind == MeMetric.bottle
                                  ? 'Record time'
                                  : 'Pumping time',
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: at,
                                          firstDate: DateTime(2000),
                                          lastDate: widget.controller.now(),
                                        );
                                        if (date == null || !context.mounted) {
                                          return;
                                        }
                                        final time = await showTimePicker(
                                          context: context,
                                          initialTime: TimeOfDay.fromDateTime(
                                            at,
                                          ),
                                        );
                                        if (time != null && mounted) {
                                          final v = DateTime(
                                            date.year,
                                            date.month,
                                            date.day,
                                            time.hour,
                                            time.minute,
                                          );
                                          if (!v.isAfter(
                                            widget.controller.now(),
                                          )) {
                                            setState(() => at = v);
                                          }
                                        }
                                      },
                                child: Text(
                                  '${at.year}-${at.month}-${at.day} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
                                ),
                              ),
                            ),
                            if (kind != MeMetric.bottle)
                              field(
                                kind == MeMetric.storage ? 'How much is in this bag?' : 'How much did you pump?',
                                TextFormField(
                                  controller: amount,
                                  enabled: !busy,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    suffixText: 'ml',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) {
                                    final n = double.tryParse(v ?? '');
                                    return n == null ||
                                            !n.isFinite ||
                                            n <= 0 ||
                                            n > 3000
                                        ? 'Enter a valid milk amount'
                                        : null;
                                  },
                                ),
                              ),
                          ],
                          if (kind == MeMetric.pump) ...[
                            dropdown(
                              'Which side did you pump?',
                              ['Left side', 'Right side', 'Both sides'],
                              side,
                              (v) => setState(() => side = v),
                            ),
                            field(
                              'Duration (optional)',
                              TextFormField(
                                controller: duration,
                                enabled: !busy,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  suffixText: 'Minutes',
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return null;
                                  final n = int.tryParse(v);
                                  return n == null || n <= 0 || n > 240
                                      ? 'Enter 1–240 minutes'
                                      : null;
                                },
                              ),
                            ),
                          ],
                          if (kind == MeMetric.pain || kind == MeMetric.latch)
                            field(
                              'Changes or notes (optional)',
                              TextFormField(
                                controller: note,
                                enabled: !busy,
                                maxLength: 500,
                                maxLines: 2,
                              ),
                            ),
                          const SizedBox(height: 32),
                        ],
                        if (failed) ...[
                          const MeError(),
                          const SizedBox(height: 12),
                        ],
                        MeButton(
                          'Save record',
                          onPressed: valid ? save : null,
                          busy: busy,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
