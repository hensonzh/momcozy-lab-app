import 'dart:convert';
import 'package:flutter/material.dart';
import '../application/me_controller.dart';
import 'me_design.dart';

const meProfileGroups = [
  'About you',
  'Delivery details',
  'Feeding method',
  'Support & more',
];
const meProfileChoices = <String, Map<String, String>>{
  'delivery_count': {'1': 'First', '2': 'Second', '3': 'Third or later'},
  'baby_count': {'1': 'One baby', '2': 'Twins', '3': 'Triplets or more'},
  'current_delivery_method': {
    'vaginal': 'Vaginal birth',
    'cesarean': 'Cesarean birth',
  },
  'feeding_methods': {
    'direct': 'Nursing',
    'expressed': 'Bottle-fed breast milk',
    'formula': 'Bottle-fed formula',
  },
  'feeding_preference': {
    'breast': 'Breastfeeding',
    'formula': 'Formula feeding',
    'mixed': 'Combination feeding',
    'undecided': 'Not sure yet',
  },
  'caregivers': {
    'partner': 'Partner',
    'family': 'Family',
    'professional': 'Care professional',
    'self': 'Mostly me',
  },
};

class MeProfilePage extends StatelessWidget {
  const MeProfilePage({super.key, required this.controller});
  final MeController controller;
  String value(String key) =>
      controller.state?.profile[key]?.toString() ?? 'Not provided';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MePage(
      title: 'My profile',
      background: MeDesign.profileBackground,
      bodyPadding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Help Momcozy AI get to know you',
            style: MeDesign.text(22, weight: FontWeight.w700, line: 32),
          ),
          const SizedBox(height: 6),
          Text(
            'Share what you feel comfortable sharing. You can update it anytime.',
            style: MeDesign.text(13, color: MeDesign.muted, line: 19),
          ),
          const SizedBox(height: 25),
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        MeProfileEditor(controller: controller, group: i),
                  ),
                ),
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: [86.0, 138.0, 112.0, 86.0][i],
                  ),
                  padding: const EdgeInsets.fromLTRB(17, 13, 17, 23),
                  decoration: MeDesign.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              meProfileGroups[i],
                              style: MeDesign.text(
                                15,
                                weight: FontWeight.w700,
                                line: 22,
                              ),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 54),
                            child: Text(
                              'Edit ›',
                              style: MeDesign.text(
                                13,
                                color: MeDesign.rose,
                                line: 19,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      for (final line in _summary(i)) ...[
                        Text(
                          line,
                          style: MeDesign.text(
                            13,
                            color: const Color(0xff807975),
                            line: 19,
                          ),
                        ),
                        if (line != _summary(i).last) const SizedBox(height: 6),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  List<String> _summary(int group) {
    final profile = controller.state?.profile ?? {};
    final birth = DateTime.tryParse(value('actual_delivery_date'));
    final weeks = profile['gestation_weeks'];
    final days = profile['gestation_days'];
    final delivery = [
      'delivery_count',
      'baby_count',
      'current_delivery_method',
    ];
    return switch (group) {
      0 => ['${value('preferred_name')} · Age ${value('age')}'],
      1 => [
        'Delivery date  ${birth == null ? 'Not provided' : '${birth.month}/${birth.day}/${birth.year}'}',
        'Gestational age  ${weeks == null ? 'Not provided' : '$weeks wk${days == null ? '' : ' $days days'}'}',
        delivery.every((e) => profile[e] == null)
            ? 'Delivery history, number of babies, and delivery method not provided'
            : delivery.map(_labels).join(' · '),
      ],
      2 => [
        'Current feeding method  ${_labels('feeding_methods')}',
        'Preferred feeding method  ${_labels('feeding_preference')}',
      ],
      _ => ['Care support, return-to-work plans, and other notes'],
    };
  }

  String _labels(String key) {
    final value = controller.state?.profile[key];
    if (value == null) return 'Not provided';
    final values = value is List ? value : [value];
    if (values.isEmpty) return 'Not provided';
    return values
        .map((e) {
          final raw = e.toString();
          final code = key == 'delivery_count' && (int.tryParse(raw) ?? 0) >= 3
              ? '3'
              : raw;
          return meProfileChoices[key]?[code] ?? 'Review saved choice';
        })
        .join(', ');
  }
}

class MeProfileEditor extends StatefulWidget {
  const MeProfileEditor({
    super.key,
    required this.controller,
    required this.group,
  });
  final MeController controller;
  final int group;
  @override
  State<MeProfileEditor> createState() => _MeProfileEditorState();
}

class _MeProfileEditorState extends State<MeProfileEditor> {
  late final initial = Map<String, Object?>.from(
    widget.controller.state?.profile ?? {},
  );
  late final draft = Map<String, Object?>.from(initial);
  final form = GlobalKey<FormState>();
  bool busy = false, failed = false, allowExit = false;
  bool get dirty => jsonEncode(draft) != jsonEncode(initial);
  Future<void> back() async {
    if (busy) return;
    if (!dirty || await meDiscard(context)) {
      if (mounted) {
        setState(() => allowExit = true);
        Navigator.pop(context);
      }
    }
  }

  Future<void> save() async {
    if (busy || !dirty || !form.currentState!.validate()) return;
    final changes = {
      for (final e in draft.entries)
        if (jsonEncode(e.value) != jsonEncode(initial[e.key])) e.key: e.value,
    };
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await widget.controller.saveProfile(changes);
      if (mounted) {
        setState(() => allowExit = true);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          failed = true;
        });
      }
    }
  }

  Widget label(String name) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(name, style: MeDesign.text(15, weight: FontWeight.w500)),
  );
  Widget input(
    String key,
    String name, {
    bool numeric = false,
    int? limit,
    String? hint,
    int lines = 1,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      label(name),
      TextFormField(
        initialValue: draft[key]?.toString(),
        enabled: !busy,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        maxLines: lines,
        maxLength: limit,
        style: MeDesign.text(16),
        decoration: InputDecoration(
          hintText: hint ?? 'Enter $name',
          filled: true,
          fillColor: MeDesign.surface,
        ),
        onChanged: (v) => setState(
          () => draft[key] = v.isEmpty
              ? null
              : numeric
              ? int.tryParse(v)
              : v,
        ),
        validator: (v) {
          if (v == null || v.isEmpty) {
            return key == 'preferred_name' ? 'Please enter a name' : null;
          }
          if (numeric) {
            final n = int.tryParse(v);
            if (n == null) return 'Enter a whole number';
            if (key == 'age' && (n < 12 || n > 70)) {
              return 'Enter an age from 12 to 70';
            }
            if (key == 'gestation_weeks' && (n < 20 || n > 45)) {
              return 'Enter 20–45 weeks';
            }
            if (key == 'gestation_days' && (n < 0 || n > 6)) {
              return 'Enter 0–6 days';
            }
          }
          return null;
        },
      ),
      const SizedBox(height: 26),
    ],
  );
  Widget choices(String key, String name, {bool multi = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      label(name),
      LayoutBuilder(
        builder: (context, box) {
          final entries = meProfileChoices[key]!.entries.toList();
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final entry in entries)
                SizedBox(
                  width: (box.maxWidth - 12) / 2,
                  child: MeChoice(
                    entry.value,
                    selected: multi
                        ? (draft[key] as List? ?? []).contains(entry.key)
                        : key == 'delivery_count' && entry.key == '3'
                        ? (draft[key] as int? ?? 0) >= 3
                        : draft[key]?.toString() == entry.key,
                    onTap: busy
                        ? null
                        : () => setState(() {
                            if (multi) {
                              final selected = List<String>.from(
                                draft[key] as List? ?? [],
                              );
                              selected.contains(entry.key)
                                  ? selected.remove(entry.key)
                                  : selected.add(entry.key);
                              draft[key] = meProfileChoices[key]!.keys
                                  .where(selected.contains)
                                  .toList();
                            } else {
                              if (key == 'delivery_count' &&
                                  entry.key == '3' &&
                                  (draft[key] as int? ?? 0) >= 3) {
                                return;
                              }
                              draft[key] =
                                  ['delivery_count', 'baby_count'].contains(key)
                                  ? int.parse(entry.key)
                                  : entry.key;
                            }
                          }),
                    height: 48,
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 26),
    ],
  );
  Widget dateField(String key, String name, {bool future = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      label(name),
      OutlinedButton(
        onPressed: busy
            ? null
            : () async {
                final today = widget.controller.now();
                final date = await showDatePicker(
                  context: context,
                  initialDate:
                      DateTime.tryParse(draft[key]?.toString() ?? '') ?? today,
                  firstDate: DateTime(1950),
                  lastDate: future ? DateTime(today.year + 10) : today,
                );
                if (date != null && mounted) {
                  setState(
                    () => draft[key] =
                        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                  );
                }
              },
        style: OutlinedButton.styleFrom(
          backgroundColor: MeDesign.surface,
          minimumSize: const Size.fromHeight(56),
          alignment: Alignment.centerLeft,
          side: const BorderSide(color: MeDesign.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          draft[key]?.toString() ??
              'Select a date${future ? ' (optional)' : ''}',
          style: MeDesign.text(
            16,
            color: draft[key] == null ? MeDesign.muted : MeDesign.ink,
          ),
        ),
      ),
      const SizedBox(height: 26),
    ],
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowExit || (!dirty && !busy),
    onPopInvokedWithResult: (p, _) {
      if (!p) back();
    },
    child: MePage(
      title: meProfileGroups[widget.group],
      onBack: back,
      footer: MeButton('Save', onPressed: dirty ? save : null, busy: busy),
      body: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.group == 0) ...[
              Text(
                'What should we call you?',
                style: MeDesign.text(24, weight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                'Share your name and age so Momcozy AI can tailor its support to you.',
                style: MeDesign.text(14, color: MeDesign.muted),
              ),
              const SizedBox(height: 40),
              input('preferred_name', 'Name'),
              input('age', 'Age', numeric: true),
            ],
            if (widget.group == 1) ...[
              Text(
                'About your delivery',
                style: MeDesign.text(24, weight: FontWeight.w700),
              ),
              const SizedBox(height: 30),
              dateField('actual_delivery_date', 'Delivery date'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: input(
                      'gestation_weeks',
                      'Gestational age at delivery',
                      numeric: true,
                      hint: 'Weeks',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: input(
                      'gestation_days',
                      'Days',
                      numeric: true,
                      hint: '0–6',
                    ),
                  ),
                ],
              ),
              choices('delivery_count', 'How many times have you given birth?'),
              choices('baby_count', 'How many babies did you deliver?'),
              choices('current_delivery_method', 'Delivery method'),
            ],
            if (widget.group == 2) ...[
              choices(
                'feeding_methods',
                'Current feeding methods · Select all that apply',
                multi: true,
              ),
              const SizedBox(height: 24),
              choices(
                'feeding_preference',
                'Preferred feeding method · Select one',
              ),
            ],
            if (widget.group == 3) ...[
              choices(
                'caregivers',
                'Who helps care for your baby? · Select all that apply',
                multi: true,
              ),
              const SizedBox(height: 24),
              dateField(
                'return_to_work_date',
                'Planned return-to-work date',
                future: true,
              ),
              input(
                'additional_context',
                'Anything else we should know?',
                lines: 5,
                limit: 500,
                hint:
                    'For example, your recovery, health history, medications, or anything else you would like to share.',
              ),
            ],
            if (failed) const MeError(),
          ],
        ),
      ),
    ),
  );
}
