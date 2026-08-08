import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/features/body_profile/domain/body_profile.dart';
import 'package:momcozy_flutter_app/features/body_profile/presentation/body_profile_controller.dart';

const _primaryPainZones = <PainZone>[
  PainZone.headNeck,
  PainZone.upperChest,
  PainZone.upperBack,
  PainZone.lowerBack,
  PainZone.pelvisHips,
  PainZone.lowerBody,
];

const _additionalPainZones = <PainZone>[
  PainZone.lowerAbdomen,
  PainZone.shouldersNeck,
  PainZone.other,
];

class MoreProfileOverviewPage extends StatefulWidget {
  const MoreProfileOverviewPage({super.key, required this.path});

  final String path;

  @override
  State<MoreProfileOverviewPage> createState() =>
      _MoreProfileOverviewPageState();
}

class _MoreProfileOverviewPageState extends State<MoreProfileOverviewPage> {
  BodyProfileController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    _controller = BodyProfileController(
      repository: MomCozyRuntimeScope.of(context).bodyProfileRepository,
    );
    unawaited(_controller!.load());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return ColoredBox(
      key: ValueKey('route-page-${widget.path}'),
      color: _ProfileColors.background,
      child: ValueListenableBuilder<BodyProfileState>(
        valueListenable: controller,
        builder: (context, state, _) {
          return RefreshIndicator(
            onRefresh: controller.load,
            color: _ProfileColors.wine,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              children: [
                _ProfileHeader(
                  profile: state.profile,
                  onBack: () => _leaveProfile(context),
                ),
                const SizedBox(height: 20),
                if (state.phase == BodyProfilePhase.loading &&
                    state.profile == null)
                  const _LoadingProfileCard()
                else if (state.phase == BodyProfilePhase.error &&
                    state.profile == null)
                  _ProfileErrorCard(onRetry: controller.load)
                else ...[
                  _RecoverySummaryCard(
                    profile: state.profile ?? const BodyProfile(),
                  ),
                  const SizedBox(height: 14),
                  const _SafetyCard(),
                  const SizedBox(height: 22),
                  _ConfirmedProfileContent(
                    profile: state.profile ?? const BodyProfile(),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const ValueKey('more-add-health-record'),
                  onPressed: () => context.go('/more/body-profile/edit'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: _ProfileColors.wine,
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    state.profile?.hasConfirmedData == true
                        ? 'Edit health record'
                        : 'Add a health record',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class MoreBodyProfileEditorPage extends StatefulWidget {
  const MoreBodyProfileEditorPage({
    super.key,
    required this.path,
    required this.onBack,
  });

  final String path;
  final VoidCallback onBack;

  @override
  State<MoreBodyProfileEditorPage> createState() =>
      _MoreBodyProfileEditorPageState();
}

class _MoreBodyProfileEditorPageState extends State<MoreBodyProfileEditorPage> {
  BodyProfileController? _controller;
  BodyProfile _loadedProfile = const BodyProfile();
  RecoveryFrequency? _urineLeakage;
  RecoveryFrequency? _lowerAbdominalPain;
  int? _pelvicFloorStrength;
  DiastasisSeverity? _diastasisSeverity;
  DeliveryType? _deliveryType;
  final Set<PainZone> _painZones = {};
  final _impactController = TextEditingController();
  final _woundController = TextEditingController();
  final _bleedingController = TextEditingController();
  final _bowelController = TextEditingController();
  bool _initialized = false;
  String? _validationError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final controller = BodyProfileController(
      repository: MomCozyRuntimeScope.of(context).bodyProfileRepository,
    );
    _controller = controller;
    controller.addListener(_handleControllerChanged);
    unawaited(controller.load());
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    final profile = _controller?.value.profile;
    if (profile != null && !_initialized) {
      _initialized = true;
      _loadedProfile = profile;
      _urineLeakage = profile.urineLeakage;
      _lowerAbdominalPain = profile.lowerAbdominalPain;
      _pelvicFloorStrength = profile.pelvicFloorStrength;
      _diastasisSeverity = profile.diastasisSeverity;
      _deliveryType = profile.deliveryType;
      _painZones
        ..clear()
        ..addAll(profile.painAreas.map((area) => area.zone));
      _impactController.text = profile.dailyImpactDescription;
      _woundController.text = profile.woundStatus;
      _bleedingController.text = profile.bleedingStatus;
      _bowelController.text = profile.bowelStatus;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleControllerChanged);
    _controller?.dispose();
    _impactController.dispose();
    _woundController.dispose();
    _bleedingController.dispose();
    _bowelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final controller = _controller;
    if (controller == null || controller.value.isBusy) return;
    final impact = _impactController.text.trim();
    final hasConfirmedValue =
        _urineLeakage != null ||
        _lowerAbdominalPain != null ||
        _pelvicFloorStrength != null ||
        _diastasisSeverity != null ||
        _deliveryType != null ||
        _painZones.isNotEmpty ||
        impact.isNotEmpty ||
        _woundController.text.trim().isNotEmpty ||
        _bleedingController.text.trim().isNotEmpty ||
        _bowelController.text.trim().isNotEmpty;
    if (!hasConfirmedValue) {
      setState(
        () => _validationError =
            'Confirm at least one recovery detail before saving.',
      );
      return;
    }
    setState(() => _validationError = null);
    final existingByZone = {
      for (final area in _loadedProfile.painAreas) area.zone: area,
    };
    final next = BodyProfile(
      urineLeakage: _urineLeakage,
      lowerAbdominalPain: _lowerAbdominalPain,
      pelvicFloorStrength: _pelvicFloorStrength,
      diastasisSeverity: _diastasisSeverity,
      dailyImpactDescription: impact,
      deliveryType: _deliveryType,
      woundStatus: _woundController.text.trim(),
      bleedingStatus: _bleedingController.text.trim(),
      bowelStatus: _bowelController.text.trim(),
      painAreas: [
        for (final zone in _painZones)
          existingByZone[zone] ?? BodyPainArea(zone: zone),
      ],
      hasConfirmedData: true,
    );
    final saved = await controller.save(next);
    if (!mounted || !saved) return;
    context.go('/more/body-profile');
  }

  Future<void> _showPainAreaPicker() async {
    final selectedZone = await showModalBottomSheet<PainZone>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: _ProfileColors.background,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add a pain area', style: _ProfileText.cardTitle),
              const SizedBox(height: 8),
              const Text(
                'Choose a more specific area. You can remove it again from the selected list.',
                style: _ProfileText.supporting,
              ),
              const SizedBox(height: 14),
              for (final zone in _additionalPainZones)
                ListTile(
                  key: ValueKey(
                    'body-profile-additional-pain-${zone.apiValue}',
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  minTileHeight: 52,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  selected: _painZones.contains(zone),
                  selectedColor: _ProfileColors.wine,
                  leading: CircleAvatar(
                    radius: 5,
                    backgroundColor: _painZones.contains(zone)
                        ? _ProfileColors.wine
                        : const Color(0xffb9a9ae),
                  ),
                  title: Text(zone.label),
                  trailing: Icon(
                    _painZones.contains(zone)
                        ? Icons.check_rounded
                        : Icons.add_rounded,
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(zone),
                ),
            ],
          ),
        );
      },
    );
    if (!mounted || selectedZone == null) return;
    setState(() {
      _painZones.contains(selectedZone)
          ? _painZones.remove(selectedZone)
          : _painZones.add(selectedZone);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller?.value ?? const BodyProfileState();
    final isLoading =
        state.phase == BodyProfilePhase.initial ||
        (state.phase == BodyProfilePhase.loading && state.profile == null);
    return ColoredBox(
      key: ValueKey('route-page-${widget.path}'),
      color: _ProfileColors.background,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              physics: const ClampingScrollPhysics(),
              children: [
                _EditorHeader(onBack: widget.onBack),
                const SizedBox(height: 22),
                const Text(
                  'Postpartum Recovery Tracker',
                  style: _ProfileText.accentTitle,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Keep track of your physical healing journey. Only details you confirm are saved.',
                  style: _ProfileText.supporting,
                ),
                const SizedBox(height: 22),
                if (isLoading)
                  const _LoadingProfileCard()
                else if (state.phase == BodyProfilePhase.error &&
                    state.profile == null)
                  _ProfileErrorCard(onRetry: _controller!.load)
                else ...[
                  _EditorCard(
                    title: 'Pelvic Floor Health',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FrequencyEditor(
                          title: 'Urine Leakage',
                          value: _urineLeakage,
                          onSelected: (value) =>
                              setState(() => _urineLeakage = value),
                        ),
                        const SizedBox(height: 20),
                        _FrequencyEditor(
                          title: 'Lower Abdominal Pain',
                          value: _lowerAbdominalPain,
                          onSelected: (value) =>
                              setState(() => _lowerAbdominalPain = value),
                        ),
                        const SizedBox(height: 22),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final value = _pelvicFloorStrength == null
                                ? 'Not set'
                                : _strengthLabel(_pelvicFloorStrength!);
                            final useStackedHeading =
                                MediaQuery.textScalerOf(context).scale(1) >
                                    1.3 ||
                                constraints.maxWidth < 280;
                            if (useStackedHeading) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pelvic Floor Strength',
                                    style: _ProfileText.fieldTitle,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(value, style: _ProfileText.accentValue),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Pelvic Floor Strength',
                                    style: _ProfileText.fieldTitle,
                                  ),
                                ),
                                Text(value, style: _ProfileText.accentValue),
                              ],
                            );
                          },
                        ),
                        Slider(
                          key: const ValueKey('body-profile-strength'),
                          value: (_pelvicFloorStrength ?? 3).toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          activeColor: _ProfileColors.wine,
                          inactiveColor: _ProfileColors.roseTint,
                          onChanged: state.isBusy
                              ? null
                              : (value) => setState(
                                  () => _pelvicFloorStrength = value.round(),
                                ),
                        ),
                        const Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Weak',
                                style: _ProfileText.supportingSmall,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Moderate',
                                textAlign: TextAlign.center,
                                style: _ProfileText.supportingSmall,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Strong',
                                textAlign: TextAlign.right,
                                style: _ProfileText.supportingSmall,
                              ),
                            ),
                          ],
                        ),
                        if (_pelvicFloorStrength != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              key: const ValueKey(
                                'body-profile-strength-clear',
                              ),
                              onPressed: state.isBusy
                                  ? null
                                  : () => setState(
                                      () => _pelvicFloorStrength = null,
                                    ),
                              child: const Text('Clear strength'),
                            ),
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
                        const Text(
                          'Separation Severity',
                          style: _ProfileText.fieldTitle,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final severity in DiastasisSeverity.values)
                              _ProfileChoiceChip(
                                chipKey: ValueKey(
                                  'body-profile-severity-${severity.apiValue}',
                                ),
                                label: severity.label,
                                selected: _diastasisSeverity == severity,
                                onSelected: state.isBusy
                                    ? null
                                    : (selected) => setState(
                                        () => _diastasisSeverity = selected
                                            ? severity
                                            : null,
                                      ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Daily Impact Description',
                          style: _ProfileText.fieldTitle,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          key: const ValueKey('body-profile-impact'),
                          controller: _impactController,
                          enabled: !state.isBusy,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 2000,
                          decoration: _fieldDecoration(
                            'Describe only what you have noticed…',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _EditorCard(
                    title: 'Pain Map',
                    subtitle: 'Tap areas where you feel discomfort or pain',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PainMapEditor(
                          selected: _painZones,
                          enabled: !state.isBusy,
                          onToggle: (zone) => setState(() {
                            _painZones.contains(zone)
                                ? _painZones.remove(zone)
                                : _painZones.add(zone);
                          }),
                        ),
                        if (_painZones.isNotEmpty) ...[
                          const Divider(height: 30),
                          const Text(
                            'Selected Pain Zones',
                            style: _ProfileText.fieldTitle,
                          ),
                          const SizedBox(height: 10),
                          _SelectedPainZones(
                            zones: _painZones,
                            enabled: !state.isBusy,
                            onRemove: (zone) =>
                                setState(() => _painZones.remove(zone)),
                          ),
                        ],
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          key: const ValueKey('body-profile-add-pain-area'),
                          onPressed: state.isBusy ? null : _showPainAreaPicker,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            foregroundColor: _ProfileColors.wine,
                            side: const BorderSide(color: _ProfileColors.pink),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Area'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _EditorCard(
                    title: 'Postpartum Recovery',
                    subtitle: 'Optional confirmed recovery details',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Delivery', style: _ProfileText.fieldTitle),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final type in DeliveryType.values)
                              _ProfileChoiceChip(
                                label: type.label,
                                selected: _deliveryType == type,
                                onSelected: state.isBusy
                                    ? null
                                    : (selected) => setState(
                                        () => _deliveryType = selected
                                            ? type
                                            : null,
                                      ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _RecoveryTextField(
                          controller: _woundController,
                          label: 'Wound status (optional)',
                          enabled: !state.isBusy,
                        ),
                        const SizedBox(height: 12),
                        _RecoveryTextField(
                          controller: _bleedingController,
                          label: 'Bleeding (optional)',
                          enabled: !state.isBusy,
                        ),
                        const SizedBox(height: 12),
                        _RecoveryTextField(
                          controller: _bowelController,
                          label: 'Bowel (optional)',
                          enabled: !state.isBusy,
                        ),
                      ],
                    ),
                  ),
                ],
                if (_validationError != null ||
                    (state.phase == BodyProfilePhase.error &&
                        state.profile != null)) ...[
                  const SizedBox(height: 14),
                  Text(
                    _validationError ??
                        'The profile could not be saved. Try again.',
                    key: const ValueKey('body-profile-error'),
                    style: _ProfileText.error,
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: FilledButton(
                key: const ValueKey('body-profile-save'),
                onPressed: isLoading || state.isBusy ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: _ProfileColors.wine,
                  shape: const StadiumBorder(),
                ),
                child: state.phase == BodyProfilePhase.saving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('Save Profile'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.onBack});

  final BodyProfile? profile;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleButton(
          buttonKey: const ValueKey('body-profile-back'),
          tooltip: 'Back',
          icon: Icons.chevron_left_rounded,
          onPressed: onBack,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              const Text('Body Profile', style: _ProfileText.pageTitle),
              const SizedBox(height: 4),
              Text(_updatedLabel(profile), style: _ProfileText.supportingSmall),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _CircleButton(
          tooltip: 'Body profile privacy',
          icon: Icons.more_horiz_rounded,
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => const AlertDialog(
              title: Text('Private health data'),
              content: Text(
                'Only details you explicitly confirm are saved in this profile. No recovery score is inferred.',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleButton(
          buttonKey: const ValueKey('more-body-profile-back'),
          tooltip: 'Back to Body Profile',
          icon: Icons.arrow_back_rounded,
          onPressed: onBack,
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Body Profile',
            textAlign: TextAlign.center,
            style: _ProfileText.pageTitle,
          ),
        ),
        const SizedBox(width: 12),
        const _CircleButton(
          tooltip: 'Only confirmed values are saved',
          icon: Icons.help_outline_rounded,
        ),
      ],
    );
  }
}

class _RecoverySummaryCard extends StatelessWidget {
  const _RecoverySummaryCard({required this.profile});

  final BodyProfile profile;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      if (profile.deliveryType != null) profile.deliveryType!.label,
      if (profile.diastasisSeverity != null)
        '${profile.diastasisSeverity!.label} core separation',
      if (profile.painAreas.isNotEmpty)
        '${profile.painAreas.length} pain ${profile.painAreas.length == 1 ? 'area' : 'areas'}',
    ];
    return _ProfileCard(
      tint: _ProfileColors.summaryTint,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your recovery profile',
                  style: _ProfileText.summaryTitle,
                ),
                const SizedBox(height: 6),
                Text(
                  profile.hasConfirmedData
                      ? 'Only your confirmed records appear here. Add details anytime.'
                      : 'No confirmed recovery details yet. Add details anytime.',
                  style: _ProfileText.supporting,
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final chip in chips) _SummaryChip(chip)],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _UnavailableScoreRing(),
        ],
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ProfileColors.safetyTint,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        key: const ValueKey('body-profile-safety'),
        borderRadius: BorderRadius.circular(24),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text('Safety comes first'),
            content: Text(
              'This profile does not diagnose symptoms. Seek urgent medical help if you feel seriously unwell or unsafe.',
            ),
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: _ProfileColors.warning,
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Safety comes first', style: _ProfileText.safetyTitle),
                    SizedBox(height: 3),
                    Text(
                      'Know when to seek urgent care',
                      style: _ProfileText.supportingDark,
                    ),
                  ],
                ),
              ),
              Text('View', style: _ProfileText.accentValue),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmedProfileContent extends StatelessWidget {
  const _ConfirmedProfileContent({required this.profile});

  final BodyProfile profile;

  @override
  Widget build(BuildContext context) {
    if (!profile.hasConfirmedData) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Confirmed profile', style: _ProfileText.sectionTitle),
          SizedBox(height: 12),
          _EmptyProfileCard(),
          SizedBox(height: 14),
          _PrivacyCard(),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Confirmed profile',
                style: _ProfileText.sectionTitle,
              ),
            ),
            Text(_updatedLabel(profile), style: _ProfileText.supporting),
          ],
        ),
        const SizedBox(height: 12),
        if (profile.urineLeakage != null ||
            profile.lowerAbdominalPain != null ||
            profile.pelvicFloorStrength != null)
          _ConfirmedSectionCard(
            title: 'Pelvic floor & bladder',
            accent: _ProfileColors.green,
            rows: [
              if (profile.urineLeakage != null)
                ('Urine leakage', profile.urineLeakage!.label),
              if (profile.lowerAbdominalPain != null)
                ('Lower abdominal pain', profile.lowerAbdominalPain!.label),
              if (profile.pelvicFloorStrength != null)
                (
                  'Pelvic floor strength',
                  _strengthLabel(profile.pelvicFloorStrength!),
                ),
            ],
          ),
        if (profile.diastasisSeverity != null ||
            profile.dailyImpactDescription.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ConfirmedSectionCard(
            title: 'Core & abdomen',
            accent: _ProfileColors.pink,
            rows: [
              if (profile.diastasisSeverity != null)
                ('Separation severity', profile.diastasisSeverity!.label),
              if (profile.dailyImpactDescription.isNotEmpty)
                ('Daily impact', profile.dailyImpactDescription),
            ],
          ),
        ],
        if (profile.painAreas.isNotEmpty) ...[
          const SizedBox(height: 14),
          _PainAreasCard(areas: profile.painAreas),
        ],
        if (profile.deliveryType != null ||
            profile.woundStatus.isNotEmpty ||
            profile.bleedingStatus.isNotEmpty ||
            profile.bowelStatus.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ConfirmedSectionCard(
            title: 'Postpartum recovery',
            accent: _ProfileColors.wine,
            rows: [
              if (profile.deliveryType != null)
                ('Delivery', profile.deliveryType!.label),
              if (profile.woundStatus.isNotEmpty)
                ('Wound', profile.woundStatus),
              if (profile.bleedingStatus.isNotEmpty)
                ('Bleeding', profile.bleedingStatus),
              if (profile.bowelStatus.isNotEmpty)
                ('Bowel', profile.bowelStatus),
            ],
          ),
        ],
        const SizedBox(height: 14),
        const _PrivacyCard(),
      ],
    );
  }
}

class _ConfirmedSectionCard extends StatelessWidget {
  const _ConfirmedSectionCard({
    required this.title,
    required this.accent,
    required this.rows,
  });

  final String title;
  final Color accent;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 24,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: _ProfileText.cardTitle)),
            ],
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < rows.length; index += 1) ...[
            _ProfileValueRow(label: rows[index].$1, value: rows[index].$2),
            if (index < rows.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PainAreasCard extends StatelessWidget {
  const _PainAreasCard({required this.areas});

  final List<BodyPainArea> areas;

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 24,
                decoration: BoxDecoration(
                  color: _ProfileColors.lilac,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Pain map', style: _ProfileText.cardTitle),
              ),
              Text('${areas.length} active', style: _ProfileText.supporting),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final map = _PainBodyMap(
                selected: areas.map((area) => area.zone).toSet(),
              );
              final list = Column(
                children: [
                  for (var index = 0; index < areas.length; index += 1) ...[
                    _PainAreaRow(area: areas[index]),
                    if (index < areas.length - 1) const SizedBox(height: 10),
                  ],
                ],
              );
              if (constraints.maxWidth < 320 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                return Column(
                  children: [
                    SizedBox(width: 150, height: 190, child: map),
                    const SizedBox(height: 12),
                    list,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 112, height: 170, child: map),
                  const SizedBox(width: 12),
                  Expanded(child: list),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PainAreaRow extends StatelessWidget {
  const _PainAreaRow({required this.area});

  final BodyPainArea area;

  @override
  Widget build(BuildContext context) {
    final detail = <String>[
      if (area.intensity != null) '${area.intensity}/10',
      if (area.sensation.isNotEmpty) area.sensation,
      if (area.pattern.isNotEmpty) area.pattern,
    ].join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _ProfileColors.roseTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(area.zone.label, style: _ProfileText.fieldTitle),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(detail, style: _ProfileText.supporting),
          ],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: _ProfileText.supporting)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: _ProfileText.value,
          ),
        ),
      ],
    );
  }
}

class _FrequencyEditor extends StatelessWidget {
  const _FrequencyEditor({
    required this.title,
    required this.value,
    required this.onSelected,
  });

  final String title;
  final RecoveryFrequency? value;
  final ValueChanged<RecoveryFrequency?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _ProfileText.fieldTitle),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final frequency in RecoveryFrequency.values)
              _ProfileChoiceChip(
                chipKey: ValueKey(
                  'body-profile-${title.toLowerCase().replaceAll(' ', '-')}-${frequency.apiValue}',
                ),
                label: frequency.label,
                selected: value == frequency,
                onSelected: (selected) =>
                    onSelected(selected ? frequency : null),
              ),
          ],
        ),
      ],
    );
  }
}

class _ProfileChoiceChip extends StatelessWidget {
  const _ProfileChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.chipKey,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Key? chipKey;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      key: chipKey,
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: onSelected,
      selectedColor: _ProfileColors.wine,
      backgroundColor: _ProfileColors.roseTint,
      disabledColor: _ProfileColors.roseTint.withValues(alpha: 0.55),
      side: BorderSide(
        color: selected ? _ProfileColors.wine : _ProfileColors.line,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelStyle: TextStyle(
        color: selected ? Colors.white : _ProfileColors.muted,
        fontSize: 14,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 7),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PainMapEditor extends StatelessWidget {
  const _PainMapEditor({
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final Set<PainZone> selected;
  final bool enabled;
  final ValueChanged<PainZone> onToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final useStackedLayout = constraints.maxWidth < 300 || textScale > 1.3;
        final selector = _PainQuickSelector(
          selected: selected,
          enabled: enabled,
          useTwoColumns: useStackedLayout && textScale <= 1.3,
          onToggle: onToggle,
        );

        Widget map({required double width}) {
          return SizedBox(
            key: const ValueKey('body-profile-pain-map'),
            width: width,
            height: 260,
            child: _PainBodyMap(
              selected: selected,
              showAllMarkers: true,
              enabled: enabled,
              onToggle: onToggle,
            ),
          );
        }

        if (useStackedLayout) {
          final mapWidth = constraints.maxWidth < 180
              ? constraints.maxWidth
              : 180.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
                child: map(width: mapWidth),
              ),
              const SizedBox(height: 18),
              selector,
            ],
          );
        }

        final mapWidth = (constraints.maxWidth * 0.46).clamp(150.0, 160.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            map(width: mapWidth),
            const SizedBox(width: 16),
            Expanded(child: selector),
          ],
        );
      },
    );
  }
}

class _PainQuickSelector extends StatelessWidget {
  const _PainQuickSelector({
    required this.selected,
    required this.enabled,
    required this.useTwoColumns,
    required this.onToggle,
  });

  final Set<PainZone> selected;
  final bool enabled;
  final bool useTwoColumns;
  final ValueChanged<PainZone> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('body-profile-pain-quick-selector'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('QUICK SELECTOR', style: _ProfileText.eyebrow),
        const SizedBox(height: 8),
        if (useTwoColumns)
          LayoutBuilder(
            builder: (context, constraints) {
              final chipWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final zone in _primaryPainZones)
                    SizedBox(
                      width: chipWidth,
                      child: _PainZoneChip(
                        zone: zone,
                        selected: selected.contains(zone),
                        enabled: enabled,
                        onToggle: onToggle,
                      ),
                    ),
                ],
              );
            },
          )
        else
          for (var index = 0; index < _primaryPainZones.length; index++) ...[
            SizedBox(
              width: double.infinity,
              child: _PainZoneChip(
                zone: _primaryPainZones[index],
                selected: selected.contains(_primaryPainZones[index]),
                enabled: enabled,
                onToggle: onToggle,
              ),
            ),
            if (index < _primaryPainZones.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _PainZoneChip extends StatelessWidget {
  const _PainZoneChip({
    required this.zone,
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final PainZone zone;
  final bool selected;
  final bool enabled;
  final ValueChanged<PainZone> onToggle;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      key: ValueKey('body-profile-pain-${zone.apiValue}'),
      avatar: CircleAvatar(
        radius: 4,
        backgroundColor: selected
            ? _ProfileColors.wine
            : const Color(0xffb9a9ae),
      ),
      label: Text(zone.label),
      selected: selected,
      showCheckmark: false,
      selectedColor: _ProfileColors.roseTint,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? _ProfileColors.pink : _ProfileColors.line,
      ),
      shape: const StadiumBorder(),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      labelStyle: TextStyle(
        color: selected ? _ProfileColors.wine : _ProfileColors.muted,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
      onSelected: enabled ? (_) => onToggle(zone) : null,
    );
  }
}

class _SelectedPainZones extends StatelessWidget {
  const _SelectedPainZones({
    required this.zones,
    required this.enabled,
    required this.onRemove,
  });

  final Set<PainZone> zones;
  final bool enabled;
  final ValueChanged<PainZone> onRemove;

  @override
  Widget build(BuildContext context) {
    final useRows = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    if (!useRows) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final zone in zones)
            InputChip(
              key: ValueKey('body-profile-selected-pain-${zone.apiValue}'),
              label: Text(zone.label),
              selected: true,
              selectedColor: _ProfileColors.wine,
              labelStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              deleteIconColor: Colors.white,
              onDeleted: enabled ? () => onRemove(zone) : null,
            ),
        ],
      );
    }

    return Column(
      children: [
        for (var index = 0; index < zones.length; index++) ...[
          _SelectedPainZoneRow(
            zone: zones.elementAt(index),
            enabled: enabled,
            onRemove: onRemove,
          ),
          if (index < zones.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SelectedPainZoneRow extends StatelessWidget {
  const _SelectedPainZoneRow({
    required this.zone,
    required this.enabled,
    required this.onRemove,
  });

  final PainZone zone;
  final bool enabled;
  final ValueChanged<PainZone> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('body-profile-selected-pain-${zone.apiValue}'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.only(left: 14),
      decoration: BoxDecoration(
        color: _ProfileColors.wine,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                zone.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            key: ValueKey('body-profile-remove-selected-pain-${zone.apiValue}'),
            tooltip: 'Remove ${zone.label}',
            onPressed: enabled ? () => onRemove(zone) : null,
            color: Colors.white,
            disabledColor: Colors.white54,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _PainBodyMap extends StatelessWidget {
  const _PainBodyMap({
    required this.selected,
    this.showAllMarkers = false,
    this.enabled = false,
    this.onToggle,
  });

  final Set<PainZone> selected;
  final bool showAllMarkers;
  final bool enabled;
  final ValueChanged<PainZone>? onToggle;

  @override
  Widget build(BuildContext context) {
    final labels = selected.map((zone) => zone.label).join(', ');
    return Semantics(
      label: selected.isEmpty
          ? 'No pain areas selected'
          : 'Pain areas: $labels',
      hint: enabled && onToggle != null
          ? 'Tap a body marker to select or remove that pain area'
          : null,
      image: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _ProfileColors.roseTint,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                key: showAllMarkers
                    ? const ValueKey('body-profile-pain-map-canvas')
                    : null,
                behavior: HitTestBehavior.opaque,
                onTapUp: enabled && onToggle != null
                    ? (details) {
                        final zone = _painZoneAt(
                          details.localPosition,
                          constraints.biggest,
                        );
                        if (zone != null) onToggle!(zone);
                      }
                    : null,
                child: CustomPaint(
                  painter: _PainBodyPainter(
                    selected: selected,
                    showAllMarkers: showAllMarkers,
                  ),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PainBodyPainter extends CustomPainter {
  const _PainBodyPainter({
    required this.selected,
    required this.showAllMarkers,
  });

  final Set<PainZone> selected;
  final bool showAllMarkers;

  @override
  void paint(Canvas canvas, Size size) {
    Offset point(double x, double y) => Offset(size.width * x, size.height * y);
    final outline = Paint()
      ..color = const Color(0xffdccbd0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2;

    canvas.drawCircle(point(0.5, 0.1), size.shortestSide * 0.075, outline);
    canvas.drawLine(point(0.47, 0.17), point(0.45, 0.22), outline);
    canvas.drawLine(point(0.53, 0.17), point(0.55, 0.22), outline);

    final torso = Path()
      ..moveTo(size.width * 0.45, size.height * 0.22)
      ..cubicTo(
        size.width * 0.31,
        size.height * 0.23,
        size.width * 0.27,
        size.height * 0.38,
        size.width * 0.39,
        size.height * 0.54,
      )
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.61,
        size.width * 0.34,
        size.height * 0.69,
        size.width * 0.36,
        size.height * 0.91,
      )
      ..moveTo(size.width * 0.55, size.height * 0.22)
      ..cubicTo(
        size.width * 0.69,
        size.height * 0.23,
        size.width * 0.73,
        size.height * 0.38,
        size.width * 0.61,
        size.height * 0.54,
      )
      ..cubicTo(
        size.width * 0.66,
        size.height * 0.61,
        size.width * 0.66,
        size.height * 0.69,
        size.width * 0.64,
        size.height * 0.91,
      )
      ..moveTo(size.width * 0.39, size.height * 0.54)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.6,
        size.width * 0.61,
        size.height * 0.54,
      )
      ..moveTo(size.width * 0.5, size.height * 0.6)
      ..lineTo(size.width * 0.5, size.height * 0.91);
    canvas.drawPath(torso, outline);
    canvas.drawLine(point(0.34, 0.27), point(0.2, 0.58), outline);
    canvas.drawLine(point(0.66, 0.27), point(0.8, 0.58), outline);

    for (final zone in PainZone.values) {
      if (zone == PainZone.other) continue;
      final active = selected.contains(zone);
      if (!active && !showAllMarkers) continue;
      final marker = _painMarkerPoint(zone, size);
      if (active) {
        canvas.drawCircle(
          marker,
          13,
          Paint()..color = _ProfileColors.pink.withValues(alpha: 0.18),
        );
        canvas.drawCircle(marker, 7, Paint()..color = _ProfileColors.wine);
      } else {
        canvas.drawCircle(marker, 5, Paint()..color = Colors.white);
        canvas.drawCircle(
          marker,
          5,
          Paint()
            ..color = const Color(0xffb9a9ae)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PainBodyPainter oldDelegate) {
    return oldDelegate.showAllMarkers != showAllMarkers ||
        !setEquals(oldDelegate.selected, selected);
  }
}

Offset _painMarkerPoint(PainZone zone, Size size) {
  final normalized = switch (zone) {
    PainZone.headNeck => const Offset(0.5, 0.2),
    PainZone.shouldersNeck => const Offset(0.34, 0.27),
    PainZone.upperChest => const Offset(0.49, 0.32),
    PainZone.upperBack => const Offset(0.65, 0.36),
    PainZone.lowerAbdomen => const Offset(0.45, 0.5),
    PainZone.lowerBack => const Offset(0.65, 0.52),
    PainZone.pelvisHips => const Offset(0.5, 0.62),
    PainZone.lowerBody => const Offset(0.5, 0.82),
    PainZone.other => const Offset(0.75, 0.58),
  };
  return Offset(normalized.dx * size.width, normalized.dy * size.height);
}

PainZone? _painZoneAt(Offset position, Size size) {
  PainZone? nearest;
  var nearestDistanceSquared = double.infinity;
  for (final zone in PainZone.values) {
    if (zone == PainZone.other) continue;
    final distanceSquared =
        (_painMarkerPoint(zone, size) - position).distanceSquared;
    if (distanceSquared < nearestDistanceSquared) {
      nearest = zone;
      nearestDistanceSquared = distanceSquared;
    }
  }
  const minimumTapRadius = 22.0;
  return nearestDistanceSquared <= minimumTapRadius * minimumTapRadius
      ? nearest
      : null;
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 24,
                decoration: BoxDecoration(
                  color: _ProfileColors.pink,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: _ProfileText.cardTitle)),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(subtitle!, style: _ProfileText.supporting),
          ],
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}

class _RecoveryTextField extends StatelessWidget {
  const _RecoveryTextField({
    required this.controller,
    required this.label,
    required this.enabled,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLength: 255,
      decoration: _fieldDecoration(label),
    );
  }
}

class _EmptyProfileCard extends StatelessWidget {
  const _EmptyProfileCard();

  @override
  Widget build(BuildContext context) {
    return const _ProfileCard(
      child: Column(
        children: [
          _RoundIcon(icon: Icons.assignment_outlined, size: 68, iconSize: 32),
          SizedBox(height: 18),
          Text(
            'No body profile data yet',
            textAlign: TextAlign.center,
            style: _ProfileText.cardTitle,
          ),
          SizedBox(height: 10),
          Text(
            'Add only the recovery details you have personally confirmed.',
            textAlign: TextAlign.center,
            style: _ProfileText.supporting,
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return const _ProfileCard(
      tint: _ProfileColors.roseTint,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: _ProfileColors.wine,
            size: 28,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nothing is inferred', style: _ProfileText.cardTitleSmall),
                SizedBox(height: 7),
                Text(
                  'Momcozy does not estimate a recovery score or prefill symptoms from missing data.',
                  style: _ProfileText.supportingDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingProfileCard extends StatelessWidget {
  const _LoadingProfileCard();

  @override
  Widget build(BuildContext context) {
    return const _ProfileCard(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: _ProfileColors.wine),
        ),
      ),
    );
  }
}

class _ProfileErrorCard extends StatelessWidget {
  const _ProfileErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      child: Column(
        children: [
          const _RoundIcon(
            icon: Icons.cloud_off_outlined,
            size: 68,
            iconSize: 32,
          ),
          const SizedBox(height: 16),
          const Text('Body profile unavailable', style: _ProfileText.cardTitle),
          const SizedBox(height: 8),
          const Text(
            'Your confirmed data could not be loaded.',
            textAlign: TextAlign.center,
            style: _ProfileText.supporting,
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.child, this.tint = Colors.white});

  final Widget child;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _ProfileColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0d000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _UnavailableScoreRing extends StatelessWidget {
  const _UnavailableScoreRing();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Recovery score is not calculated',
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _ProfileColors.pink, width: 7),
        ),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('—', style: _ProfileText.score),
              Text('SCORE', style: _ProfileText.scoreLabel),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(label, style: _ProfileText.accentValue),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.buttonKey,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: buttonKey,
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        backgroundColor: Colors.white,
        foregroundColor: _ProfileColors.ink,
        side: const BorderSide(color: _ProfileColors.line),
        shape: const CircleBorder(),
      ),
      icon: Icon(icon),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, this.size = 48, this.iconSize = 24});

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: _ProfileColors.roseTint,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: _ProfileColors.wine, size: iconSize),
    );
  }
}

InputDecoration _fieldDecoration(String label) {
  return InputDecoration(
    hintText: label,
    filled: true,
    fillColor: _ProfileColors.roseTint,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
  );
}

String _strengthLabel(int value) {
  return switch (value) {
    1 => 'Weak (Level 1)',
    2 => 'Low (Level 2)',
    3 => 'Moderate (Level 3)',
    4 => 'Good (Level 4)',
    _ => 'Strong (Level 5)',
  };
}

String _updatedLabel(BodyProfile? profile) {
  final updated = profile?.updatedAt?.toLocal();
  if (updated == null) return 'Not updated yet';
  final today = DateTime.now();
  if (updated.year == today.year &&
      updated.month == today.month &&
      updated.day == today.day) {
    return 'Updated today';
  }
  return 'Updated ${updated.year}-${updated.month.toString().padLeft(2, '0')}-${updated.day.toString().padLeft(2, '0')}';
}

void _leaveProfile(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/me');
  }
}

abstract final class _ProfileColors {
  static const background = Color(0xfffff9f8);
  static const wine = Color(0xff9d1748);
  static const ink = Color(0xff261b20);
  static const muted = Color(0xff806f76);
  static const roseTint = Color(0xffffedf2);
  static const summaryTint = Color(0xffffe8ee);
  static const safetyTint = Color(0xfffff8c8);
  static const warning = Color(0xffa54a10);
  static const green = Color(0xff22b888);
  static const pink = Color(0xffd65f8a);
  static const lilac = Color(0xffa997ff);
  static const line = Color(0xffeee2e5);
}

abstract final class _ProfileText {
  static const pageTitle = TextStyle(
    color: _ProfileColors.ink,
    fontSize: 27,
    height: 1.1,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.7,
  );
  static const summaryTitle = TextStyle(
    color: _ProfileColors.wine,
    fontSize: 24,
    height: 1.1,
    fontWeight: FontWeight.w900,
  );
  static const sectionTitle = TextStyle(
    color: _ProfileColors.ink,
    fontSize: 22,
    fontWeight: FontWeight.w900,
  );
  static const accentTitle = TextStyle(
    color: _ProfileColors.wine,
    fontSize: 20,
    fontWeight: FontWeight.w900,
  );
  static const cardTitle = TextStyle(
    color: _ProfileColors.ink,
    fontSize: 21,
    height: 1.2,
    fontWeight: FontWeight.w900,
  );
  static const cardTitleSmall = TextStyle(
    color: _ProfileColors.ink,
    fontSize: 18,
    height: 1.2,
    fontWeight: FontWeight.w900,
  );
  static const fieldTitle = TextStyle(
    color: _ProfileColors.ink,
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w800,
  );
  static const value = TextStyle(
    color: _ProfileColors.ink,
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w800,
  );
  static const supporting = TextStyle(
    color: _ProfileColors.muted,
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );
  static const supportingSmall = TextStyle(
    color: _ProfileColors.muted,
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
  static const supportingDark = TextStyle(
    color: _ProfileColors.ink,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );
  static const accentValue = TextStyle(
    color: _ProfileColors.wine,
    fontSize: 14,
    fontWeight: FontWeight.w900,
  );
  static const safetyTitle = TextStyle(
    color: _ProfileColors.warning,
    fontSize: 17,
    fontWeight: FontWeight.w900,
  );
  static const eyebrow = TextStyle(
    color: _ProfileColors.muted,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );
  static const score = TextStyle(
    color: _ProfileColors.wine,
    fontSize: 24,
    height: 1,
    fontWeight: FontWeight.w900,
  );
  static const scoreLabel = TextStyle(
    color: _ProfileColors.muted,
    fontSize: 9,
    fontWeight: FontWeight.w800,
  );
  static const error = TextStyle(
    color: _ProfileColors.wine,
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );
}
