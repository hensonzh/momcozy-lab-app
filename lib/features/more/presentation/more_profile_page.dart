import 'package:flutter/material.dart';

class MoreProfileOverviewPage extends StatelessWidget {
  const MoreProfileOverviewPage({
    super.key,
    required this.path,
    required this.onOpenEditor,
  });

  final String path;
  final VoidCallback onOpenEditor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: ValueKey('route-page-$path'),
      color: _MoreColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        physics: const ClampingScrollPhysics(),
        children: [
          const _ProfileHeader(
            title: 'Body Profile',
            subtitle: 'Postpartum day 42 · Updated today',
            trailingIcon: Icons.more_horiz_rounded,
          ),
          const SizedBox(height: 16),
          const _RecoveryHero(),
          const SizedBox(height: 16),
          const _SafetyBanner(),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(
                child: Text('Confirmed profile', style: _MoreText.sectionTitle),
              ),
              Text('Updated today', style: _MoreText.supporting),
            ],
          ),
          const SizedBox(height: 12),
          _ProfileCard(
            title: 'Pelvic floor & bladder',
            subtitle: 'Based on the past 7 days',
            accent: _MoreColors.green,
            actionLabel: 'Edit',
            actionKey: const ValueKey('more-edit-pelvic-floor'),
            onAction: onOpenEditor,
            children: const [
              _ProfileValueRow(
                label: 'Urine leakage',
                value: '2–3 times a week',
              ),
              _ProfileValueRow(
                label: 'Typical triggers',
                value: 'Coughing / sneezing, Lifting baby',
              ),
              _ProfileValueRow(label: 'Usual amount', value: 'A few drops'),
              _ProfileValueRow(
                label: 'Life impact',
                value: '4/10 · Moderate concern',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProfileCard(
            title: 'Core & abdomen',
            subtitle: 'Last confirmed today',
            accent: _MoreColors.pink,
            actionLabel: 'Edit',
            onAction: onOpenEditor,
            children: const [
              _ProfileValueRow(
                label: 'Midline doming',
                value: 'When getting up or straining',
              ),
              _ProfileValueRow(
                label: 'Separation feeling',
                value: 'Around the navel · about 2 fingers',
              ),
              _ProfileValueRow(
                label: 'Lower abdominal pain',
                value: '4/10 · Aching',
              ),
              _ProfileValueRow(
                label: 'More noticeable',
                value: 'After lifting baby · late afternoon',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PainSummaryCard(onAction: onOpenEditor),
          const SizedBox(height: 16),
          const _ProfileCard(
            title: 'Postpartum recovery',
            subtitle: 'Delivery and current recovery',
            children: [
              _ProfileValueRow(label: 'Delivery', value: 'Vaginal birth'),
              _ProfileValueRow(label: 'Wound', value: 'No current discomfort'),
              _ProfileValueRow(
                label: 'Bleeding',
                value: 'Decreasing and lighter',
              ),
              _ProfileValueRow(
                label: 'Bowel',
                value: 'Occasional constipation',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _TrackingCallout(),
          const SizedBox(height: 18),
          SizedBox(
            height: 56,
            child: FilledButton(
              key: const ValueKey('more-add-health-record'),
              onPressed: onOpenEditor,
              style: FilledButton.styleFrom(
                backgroundColor: _MoreColors.wine,
                shape: const StadiumBorder(),
                elevation: 7,
                shadowColor: _MoreColors.wineShadow,
              ),
              child: const Text(
                '+ Add a health record',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MoreBodyProfileEditorPage extends StatefulWidget {
  const MoreBodyProfileEditorPage({
    super.key,
    required this.path,
    required this.onBack,
    required this.onSave,
  });

  final String path;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  State<MoreBodyProfileEditorPage> createState() =>
      _MoreBodyProfileEditorPageState();
}

class _MoreBodyProfileEditorPageState extends State<MoreBodyProfileEditorPage> {
  String _leakage = 'Sometimes';
  String _pain = 'Rare';
  String _separation = 'Mild';
  double _pelvicStrength = 0.6;
  final Set<String> _painZones = {'Lower Abdomen', 'Shoulders & Neck'};

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: ValueKey('route-page-${widget.path}'),
      color: _MoreColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _ProfileHeader(
              title: 'Body Profile',
              leadingIcon: Icons.arrow_back_rounded,
              onLeading: widget.onBack,
              trailingIcon: Icons.help_outline_rounded,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              physics: const ClampingScrollPhysics(),
              children: [
                const Text(
                  'Postpartum Recovery Tracker',
                  style: TextStyle(
                    color: _MoreColors.wine,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Keep track of your physical healing journey to receive tailored exercise guides.',
                  style: _MoreText.supportingDark,
                ),
                const SizedBox(height: 18),
                _EditorCard(
                  title: 'Pelvic Floor Health',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Urine Leakage'),
                      const SizedBox(height: 8),
                      _ChoiceRow(
                        values: const [
                          'None',
                          'Rare',
                          'Sometimes',
                          'Often',
                          'Always',
                        ],
                        selected: _leakage,
                        onSelected: (value) => setState(() => _leakage = value),
                      ),
                      const SizedBox(height: 22),
                      const _FieldLabel('Lower Abdominal Pain'),
                      const SizedBox(height: 8),
                      _ChoiceRow(
                        values: const [
                          'None',
                          'Rare',
                          'Sometimes',
                          'Often',
                          'Always',
                        ],
                        selected: _pain,
                        onSelected: (value) => setState(() => _pain = value),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Expanded(
                            child: _FieldLabel('Pelvic Floor Strength'),
                          ),
                          Text(
                            _pelvicStrength < 0.34
                                ? 'Weak (Level 1)'
                                : _pelvicStrength < 0.67
                                ? 'Moderate (Level 3)'
                                : 'Strong (Level 5)',
                            style: const TextStyle(
                              color: _MoreColors.wine,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _pelvicStrength,
                        onChanged: (value) =>
                            setState(() => _pelvicStrength = value),
                        activeColor: _MoreColors.wine,
                        inactiveColor: _MoreColors.roseTint,
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Weak', style: _MoreText.caption),
                          Text('Moderate', style: _MoreText.caption),
                          Text('Strong', style: _MoreText.caption),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _EditorCard(
                  title: 'Diastasis Recti',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Separation Severity'),
                      const SizedBox(height: 8),
                      _ChoiceRow(
                        values: const [
                          'Not sure',
                          'Mild',
                          'Moderate',
                          'Severe',
                        ],
                        selected: _separation,
                        onSelected: (value) =>
                            setState(() => _separation = value),
                      ),
                      const SizedBox(height: 20),
                      const _FieldLabel('Daily Impact Description'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 94),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: _MoreColors.roseSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _MoreColors.line),
                        ),
                        child: const Text(
                          'I experience occasional tightness in my core when picking up my baby, especially in the afternoon…',
                          style: TextStyle(
                            color: _MoreColors.ink,
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _EditorCard(
                  title: 'Pain Map',
                  subtitle: 'Tap areas where you feel discomfort or pain',
                  child: _PainMapEditor(
                    selectedZones: _painZones,
                    onToggle: (zone) {
                      setState(() {
                        if (!_painZones.remove(zone)) _painZones.add(zone);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _MoreColors.line)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                key: const ValueKey('more-save-profile'),
                onPressed: widget.onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: _MoreColors.wine,
                  shape: const StadiumBorder(),
                  elevation: 7,
                  shadowColor: _MoreColors.wineShadow,
                ),
                child: const Text(
                  'Save Profile',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.onLeading,
    this.trailingIcon,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final VoidCallback? onLeading;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: leadingIcon == null
                ? const SizedBox.square(dimension: 42)
                : _CircleIconButton(icon: leadingIcon!, onPressed: onLeading),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 52),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _MoreColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _MoreText.caption,
                  ),
                ],
              ],
            ),
          ),
          if (trailingIcon != null)
            Positioned(right: 0, child: _CircleIconButton(icon: trailingIcon!)),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(side: BorderSide(color: _MoreColors.line)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 42,
          child: Icon(icon, color: _MoreColors.ink, size: 22),
        ),
      ),
    );
  }
}

class _RecoveryHero extends StatelessWidget {
  const _RecoveryHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 18, 22),
      decoration: BoxDecoration(
        color: _MoreColors.hero,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: _MoreColors.heroLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your recovery profile',
                  style: TextStyle(
                    color: _MoreColors.wine,
                    fontSize: 22,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Only your confirmed records appear here. Add details anytime.',
                  style: _MoreText.supportingDark,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _ProfilePill('Vaginal birth'),
                    _ProfilePill('6 weeks postpartum'),
                    _ProfilePill('2 pain areas'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Image.asset(
            'assets/images/more/recovery_score.png',
            width: 80,
            height: 80,
            filterQuality: FilterQuality.high,
          ),
        ],
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _MoreColors.roseTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _MoreColors.wine,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: _MoreColors.warning,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _MoreColors.warningLine),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: _MoreColors.warningIcon,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: _MoreColors.warningInk,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safety comes first',
                  style: TextStyle(
                    color: _MoreColors.warningInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Know the symptoms that need urgent care',
                  style: TextStyle(
                    color: _MoreColors.warningInk,
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'View',
            style: TextStyle(
              color: _MoreColors.warningInk,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.title,
    required this.subtitle,
    required this.children,
    this.accent,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Color? accent;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _MoreDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (accent != null) ...[
                Container(
                  width: 8,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _MoreText.cardTitle),
                    const SizedBox(height: 4),
                    Text(subtitle, style: _MoreText.supporting),
                  ],
                ),
              ),
              if (actionLabel != null)
                TextButton(
                  key: actionKey,
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    foregroundColor: _MoreColors.wine,
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileValueRow extends StatelessWidget {
  const _ProfileValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: Text(label, style: _MoreText.supporting)),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: _MoreColors.ink,
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PainSummaryCard extends StatelessWidget {
  const _PainSummaryCard({required this.onAction});

  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      title: 'Pain map',
      subtitle: '2 active areas',
      accent: _MoreColors.lilac,
      actionLabel: 'Add',
      onAction: onAction,
      children: const [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PainPreview(),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  _PainValue(
                    title: 'Lower abdomen · 4/10',
                    subtitle: 'Aching · recurring',
                  ),
                  SizedBox(height: 10),
                  _PainValue(
                    title: 'Left lower back · 4/10',
                    subtitle: 'Sore · worse in afternoon',
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PainPreview extends StatelessWidget {
  const _PainPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 102,
      decoration: BoxDecoration(
        color: _MoreColors.roseSurface,
        borderRadius: BorderRadius.circular(19),
      ),
      child: const CustomPaint(painter: _PainPreviewPainter()),
    );
  }
}

class _PainPreviewPainter extends CustomPainter {
  const _PainPreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = const Color(0xffe6cdd3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..moveTo(size.width * 0.24, size.height * 0.48)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.08,
        size.width * 0.84,
        size.height * 0.08,
        size.width * 0.81,
        size.height * 0.45,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.65,
        size.width * 0.42,
        size.height * 0.62,
        size.width * 0.24,
        size.height * 0.48,
      );
    canvas.drawPath(path, outline);
    _drawHotspot(canvas, Offset(size.width * 0.35, size.height * 0.44), 8);
    _drawHotspot(canvas, Offset(size.width * 0.58, size.height * 0.73), 10);
  }

  void _drawHotspot(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius * 2.1,
      Paint()..color = _MoreColors.wine.withValues(alpha: 0.12),
    );
    canvas.drawCircle(center, radius, Paint()..color = _MoreColors.wine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PainValue extends StatelessWidget {
  const _PainValue({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: _MoreColors.roseSurface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _MoreColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _MoreColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: _MoreText.caption),
        ],
      ),
    );
  }
}

class _TrackingCallout extends StatelessWidget {
  const _TrackingCallout();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _MoreColors.hero,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _MoreColors.heroLine),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Two areas are worth tracking',
            style: TextStyle(
              color: _MoreColors.wine,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 9),
          Text(
            'Leakage and lower-abdominal discomfort have been recorded more than once. Consider a guided re-check or share this profile with a pelvic-health PT.',
            style: _MoreText.supportingDark,
          ),
        ],
      ),
    );
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _MoreDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 24,
                decoration: BoxDecoration(
                  color: _MoreColors.cardAccent,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: _MoreText.cardTitle)),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: Text(subtitle!, style: _MoreText.supporting),
            ),
          ],
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _MoreColors.ink,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 6.0;
        final width =
            (constraints.maxWidth - gap * (values.length - 1)) / values.length;
        return Wrap(
          spacing: gap,
          runSpacing: 7,
          children: [
            for (final value in values)
              SizedBox(
                width: width,
                child: _SelectPill(
                  label: value,
                  selected: selected == value,
                  onTap: () => onSelected(value),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SelectPill extends StatelessWidget {
  const _SelectPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _MoreColors.wine : _MoreColors.roseSurface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          constraints: const BoxConstraints(minHeight: 38),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? _MoreColors.wine : _MoreColors.line,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : _MoreColors.muted,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PainMapEditor extends StatelessWidget {
  const _PainMapEditor({required this.selectedZones, required this.onToggle});

  final Set<String> selectedZones;
  final ValueChanged<String> onToggle;

  static const _zones = [
    'Head & Neck',
    'Upper Chest',
    'Upper Back',
    'Lower Back',
    'Pelvis & Hips',
    'Lower Body',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 320;
            final body = Container(
              height: 252,
              decoration: BoxDecoration(
                color: _MoreColors.roseSurface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const CustomPaint(
                painter: _BodyMapPainter(),
                child: SizedBox.expand(),
              ),
            );
            final selector = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('QUICK SELECTOR', style: _MoreText.caption),
                const SizedBox(height: 8),
                for (final zone in _zones)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: _ZoneButton(
                      label: zone,
                      selected: selectedZones.contains(zone),
                      onTap: () => onToggle(zone),
                    ),
                  ),
              ],
            );
            if (compact) {
              return Column(
                children: [
                  SizedBox(width: double.infinity, child: body),
                  const SizedBox(height: 14),
                  selector,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: body),
                const SizedBox(width: 14),
                Expanded(flex: 6, child: selector),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        const Divider(color: _MoreColors.line),
        const SizedBox(height: 12),
        const Text('Selected Pain Zones:', style: _MoreText.supporting),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final zone in selectedZones)
              InputChip(
                label: Text(zone),
                onDeleted: () => onToggle(zone),
                deleteIconColor: Colors.white,
                backgroundColor: _MoreColors.wine,
                side: BorderSide.none,
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                shape: const StadiumBorder(),
              ),
            ActionChip(
              label: const Text('+ Add Area'),
              onPressed: () => onToggle('Lower Body'),
              side: const BorderSide(color: _MoreColors.wine),
              backgroundColor: Colors.white,
              labelStyle: const TextStyle(
                color: _MoreColors.wine,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              shape: const StadiumBorder(),
            ),
          ],
        ),
      ],
    );
  }
}

class _ZoneButton extends StatelessWidget {
  const _ZoneButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _MoreColors.roseSurface : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? _MoreColors.wine : _MoreColors.line,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: selected ? _MoreColors.wine : _MoreColors.mutedLight,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? _MoreColors.wine : _MoreColors.muted,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BodyMapPainter extends CustomPainter {
  const _BodyMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xffe7cfd5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final centerX = size.width / 2;

    canvas.drawCircle(Offset(centerX, 28), 12, line);
    final torso = Path()
      ..moveTo(centerX - 20, 44)
      ..cubicTo(centerX - 44, 74, centerX - 38, 112, centerX - 22, 132)
      ..cubicTo(centerX - 38, 166, centerX - 46, 205, centerX - 44, 232)
      ..moveTo(centerX + 20, 44)
      ..cubicTo(centerX + 44, 74, centerX + 38, 112, centerX + 22, 132)
      ..cubicTo(centerX + 38, 166, centerX + 46, 205, centerX + 44, 232);
    canvas.drawPath(torso, line);

    const dotColor = Color(0xffc9b5b9);
    final dot = Paint()..color = Colors.white;
    final dotBorder = Paint()
      ..color = dotColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final points = [
      Offset(centerX, 28),
      Offset(centerX - 30, 88),
      Offset(centerX + 28, 68),
      Offset(centerX + 44, 124),
      Offset(centerX - 20, 144),
      Offset(centerX + 16, 190),
      Offset(centerX - 34, 202),
    ];
    for (final point in points) {
      canvas.drawCircle(point, 7, dot);
      canvas.drawCircle(point, 7, dotBorder);
    }
    _drawHotspot(canvas, Offset(centerX - 30, 88), 8);
    _drawHotspot(canvas, Offset(centerX + 2, 132), 11);
  }

  void _drawHotspot(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius * 2.2,
      Paint()..color = _MoreColors.wine.withValues(alpha: 0.12),
    );
    canvas.drawCircle(center, radius, Paint()..color = _MoreColors.wine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

abstract final class _MoreColors {
  static const background = Color(0xfffff9f7);
  static const ink = Color(0xff302126);
  static const muted = Color(0xff846f75);
  static const mutedLight = Color(0xffc7b9bc);
  static const wine = Color(0xffa21849);
  static const wineShadow = Color(0x4da21849);
  static const hero = Color(0xffffedf2);
  static const heroLine = Color(0xffffcfdd);
  static const roseTint = Color(0xfff9e9ee);
  static const roseSurface = Color(0xfffff0f3);
  static const line = Color(0xffeadde0);
  static const green = Color(0xff16b886);
  static const pink = Color(0xffffc8e5);
  static const lilac = Color(0xffc0a8ff);
  static const cardAccent = Color(0xffc85f82);
  static const warning = Color(0xfffff7be);
  static const warningLine = Color(0xffffd54f);
  static const warningIcon = Color(0xfffffbe4);
  static const warningInk = Color(0xff9a430b);
}

abstract final class _MoreText {
  static const sectionTitle = TextStyle(
    color: _MoreColors.ink,
    fontSize: 19,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.2,
  );
  static const cardTitle = TextStyle(
    color: _MoreColors.ink,
    fontSize: 18,
    height: 1.1,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.15,
  );
  static const supporting = TextStyle(
    color: _MoreColors.muted,
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );
  static const supportingDark = TextStyle(
    color: _MoreColors.muted,
    fontSize: 14,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );
  static const caption = TextStyle(
    color: _MoreColors.muted,
    fontSize: 11,
    height: 1.25,
    fontWeight: FontWeight.w500,
  );
}

abstract final class _MoreDecorations {
  static final card = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: _MoreColors.line),
    boxShadow: const [
      BoxShadow(color: Color(0x0f5a2938), blurRadius: 22, offset: Offset(0, 8)),
    ],
  );
}
