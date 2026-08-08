import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/onboarding/data/platform_portrait_picker.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/onboarding.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';

typedef OnboardingPortraitPicker =
    Future<OnboardingPortrait?> Function(OnboardingPortraitSource source);

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.controller,
    this.pickPortrait,
  });

  final OnboardingController controller;
  final OnboardingPortraitPicker? pickPortrait;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final OnboardingPortraitPicker _pickPortrait =
      widget.pickPortrait ?? OnboardingPlatformPortraitPicker().pick;
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  int _profileStep = 0;
  OnboardingProfileDraft? _draft;
  String _validationMessage = '';

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return Scaffold(
          backgroundColor: MomCozyV3Colors.background,
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: MomCozyLayout.maxAppWidth,
                ),
                child: switch (controller.phase) {
                  OnboardingGatePhase.idle ||
                  OnboardingGatePhase.loading => const _LoadingView(),
                  OnboardingGatePhase.failure => _LoadFailureView(
                    message: controller.errorMessage,
                    onRetry: controller.load,
                  ),
                  OnboardingGatePhase.ready => _buildReady(context),
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReady(BuildContext context) {
    final state = widget.controller.state;
    if (state == null) return const _LoadingView();
    if (!state.profileConfirmed) return _buildProfileFlow(context);
    return _buildAvatarFlow(context, state);
  }

  Widget _buildProfileFlow(BuildContext context) {
    return Column(
      children: [
        _OnboardingHeader(
          step: _profileStep + 1,
          totalSteps: 4,
          onBack: _profileStep == 0
              ? null
              : () => setState(() {
                  _profileStep -= 1;
                  _validationMessage = '';
                }),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: switch (_profileStep) {
              0 => _stageStep(),
              1 => _basicsStep(),
              _ => _stageDetailsStep(context),
            },
          ),
        ),
      ],
    );
  }

  Widget _stageStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _IntroCopy(
          eyebrow: 'LET’S GET TO KNOW YOU',
          title: 'Which stage are you in?',
          body:
              'We’ll personalize your home, care plan, and digital companion around where you are today.',
        ),
        const SizedBox(height: 28),
        for (final stage in OnboardingCareStage.values) ...[
          _StageCard(
            stage: stage,
            selected: _draft?.stage == stage,
            onTap: () => setState(() {
              _draft = OnboardingProfileDraft(stage: stage);
              _validationMessage = '';
            }),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 16),
        _errorText(),
        _PrimaryButton(
          label: 'Continue',
          onPressed: () {
            if (_draft == null) {
              setState(() => _validationMessage = 'Choose your current stage.');
              return;
            }
            setState(() {
              _profileStep = 1;
              _validationMessage = '';
            });
          },
        ),
      ],
    );
  }

  Widget _basicsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _IntroCopy(
          eyebrow: 'ABOUT YOU',
          title: 'A few basics first',
          body:
              'This helps MomCozy address you naturally and tailor age-aware guidance.',
        ),
        const SizedBox(height: 28),
        TextField(
          key: const ValueKey('onboarding-display-name'),
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'What should we call you?',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('onboarding-age'),
          controller: _ageController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Age',
            hintText: 'e.g. 32',
          ),
        ),
        const SizedBox(height: 28),
        _errorText(),
        _PrimaryButton(label: 'Continue', onPressed: _continueFromBasics),
      ],
    );
  }

  void _continueFromBasics() {
    final age = int.tryParse(_ageController.text.trim());
    if (_nameController.text.trim().isEmpty) {
      setState(
        () => _validationMessage = 'Enter the name you’d like us to use.',
      );
      return;
    }
    if (age == null || age < 12 || age > 70) {
      setState(() => _validationMessage = 'Enter an age between 12 and 70.');
      return;
    }
    _draft!
      ..displayName = _nameController.text.trim()
      ..age = age;
    setState(() {
      _profileStep = 2;
      _validationMessage = '';
    });
  }

  Widget _stageDetailsStep(BuildContext context) {
    final draft = _draft!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IntroCopy(
          eyebrow: draft.stage.title.toUpperCase(),
          title: switch (draft.stage) {
            OnboardingCareStage.fertility => 'You’re all set',
            OnboardingCareStage.pregnancy => 'Tell us about this pregnancy',
            OnboardingCareStage.postpartum => 'Tell us about your delivery',
          },
          body: switch (draft.stage) {
            OnboardingCareStage.fertility =>
              'We’ll start with gentle preconception and cycle-aware support.',
            OnboardingCareStage.pregnancy =>
              'Your due date lets us calculate the right gestational guidance.',
            OnboardingCareStage.postpartum =>
              'One shared delivery record keeps your information and each baby’s profile consistent.',
          },
        ),
        const SizedBox(height: 26),
        if (draft.stage == OnboardingCareStage.pregnancy)
          ..._pregnancyFields(context, draft),
        if (draft.stage == OnboardingCareStage.postpartum)
          ..._postpartumFields(context, draft),
        const SizedBox(height: 26),
        _errorText(),
        _PrimaryButton(
          label: 'Save and continue',
          loading: widget.controller.busy,
          onPressed: widget.controller.busy ? null : _submitProfile,
        ),
      ],
    );
  }

  List<Widget> _pregnancyFields(
    BuildContext context,
    OnboardingProfileDraft draft,
  ) {
    return [
      _DateField(
        label: 'Expected due date',
        value: draft.expectedDueDate,
        onTap: () async {
          final today = DateUtils.dateOnly(DateTime.now());
          final firstDate = today.subtract(const Duration(days: 42));
          final lastDate = today.add(const Duration(days: 321));
          final selected = await showDatePicker(
            context: context,
            initialDate:
                draft.expectedDueDate ?? today.add(const Duration(days: 120)),
            firstDate: firstDate,
            lastDate: lastDate,
          );
          if (selected != null) {
            setState(() => draft.expectedDueDate = selected);
          }
        },
      ),
      const SizedBox(height: 16),
      _CountField(
        label: 'Expected babies',
        value: draft.expectedInfantCount,
        onChanged: (value) => setState(() => draft.expectedInfantCount = value),
      ),
    ];
  }

  List<Widget> _postpartumFields(
    BuildContext context,
    OnboardingProfileDraft draft,
  ) {
    return [
      _DateField(
        label: 'Delivery date',
        value: draft.deliveryDate,
        onTap: () async {
          final today = DateUtils.dateOnly(DateTime.now());
          final selected = await showDatePicker(
            context: context,
            initialDate: draft.deliveryDate ?? today,
            firstDate: DateTime(today.year - 2),
            lastDate: today,
          );
          if (selected != null) setState(() => draft.deliveryDate = selected);
        },
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              key: const ValueKey('onboarding-gestational-weeks'),
              initialValue: draft.gestationalWeeks?.toString() ?? '',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Weeks (optional)'),
              onChanged: (value) =>
                  draft.gestationalWeeks = int.tryParse(value),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: draft.gestationalDays,
              decoration: const InputDecoration(labelText: 'Days'),
              items: [
                for (var day = 0; day <= 6; day++)
                  DropdownMenuItem(value: day, child: Text('$day')),
              ],
              onChanged: (value) => draft.gestationalDays = value ?? 0,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String?>(
        initialValue: draft.deliveryType,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Delivery method (optional)',
        ),
        items: const [
          DropdownMenuItem(value: null, child: Text('Prefer not to say yet')),
          DropdownMenuItem(value: 'vaginal', child: Text('Vaginal birth')),
          DropdownMenuItem(value: 'cesarean', child: Text('Cesarean birth')),
          DropdownMenuItem(value: 'assisted', child: Text('Assisted birth')),
          DropdownMenuItem(value: 'other', child: Text('Other')),
        ],
        onChanged: (value) => draft.deliveryType = value,
      ),
      const SizedBox(height: 16),
      _CountField(
        label: 'Number of babies',
        value: draft.infantCount,
        onChanged: (value) => setState(() => draft.setInfantCount(value)),
      ),
      const SizedBox(height: 18),
      for (var index = 0; index < draft.infants.length; index++) ...[
        _InfantFields(index: index, infant: draft.infants[index]),
        if (index != draft.infants.length - 1) const SizedBox(height: 12),
      ],
    ];
  }

  Future<void> _submitProfile() async {
    final draft = _draft!;
    if (draft.stage == OnboardingCareStage.pregnancy &&
        draft.expectedDueDate == null) {
      setState(() => _validationMessage = 'Choose your expected due date.');
      return;
    }
    if (draft.stage == OnboardingCareStage.postpartum &&
        draft.deliveryDate == null) {
      setState(() => _validationMessage = 'Choose your delivery date.');
      return;
    }
    if (draft.gestationalWeeks != null &&
        (draft.gestationalWeeks! < 0 || draft.gestationalWeeks! > 45)) {
      setState(
        () =>
            _validationMessage = 'Gestational weeks must be between 0 and 45.',
      );
      return;
    }
    setState(() => _validationMessage = '');
    await widget.controller.confirmProfile(draft);
  }

  Widget _buildAvatarFlow(BuildContext context, OnboardingState state) {
    return Column(
      children: [
        const _OnboardingHeader(step: 4, totalSteps: 4),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: switch (state.status) {
              OnboardingStatus.avatarGenerating => _generatingView(state),
              OnboardingStatus.avatarReview => _reviewView(context, state),
              OnboardingStatus.avatarFailed => _avatarChoiceView(
                state,
                failed: true,
              ),
              _ => _avatarChoiceView(state),
            },
          ),
        ),
      ],
    );
  }

  Widget _avatarChoiceView(OnboardingState state, {bool failed = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IntroCopy(
          eyebrow: 'YOUR DIGITAL COMPANION',
          title: failed ? 'Let’s try another photo' : 'Make her feel like you',
          body: failed
              ? 'We couldn’t create your avatar from that photo. A clear, front-facing portrait usually works best.'
              : 'Upload a clear portrait. We’ll combine your likeness with our ${state.stage?.title.toLowerCase() ?? 'stage'} character style.',
        ),
        const SizedBox(height: 22),
        _ReferenceAvatar(stage: state.stage),
        const SizedBox(height: 18),
        const _PrivacyNote(),
        const SizedBox(height: 22),
        _errorText(controllerError: true),
        _PrimaryButton(
          label: 'Take a photo',
          icon: Icons.camera_alt_rounded,
          loading: widget.controller.busy,
          onPressed: widget.controller.busy
              ? null
              : () => _choosePortrait(OnboardingPortraitSource.camera),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: widget.controller.busy
              ? null
              : () => _choosePortrait(OnboardingPortraitSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Choose from library'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: widget.controller.busy
              ? null
              : widget.controller.completeWithDefaultAvatar,
          child: const Text('Use the MomCozy character for now'),
        ),
      ],
    );
  }

  Future<void> _choosePortrait(OnboardingPortraitSource source) async {
    widget.controller.clearError();
    try {
      final portrait = await _pickPortrait(source);
      if (portrait == null) return;
      await widget.controller.uploadAndGenerate(portrait);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _validationMessage = error is FormatException
            ? error.message
            : 'We couldn’t open that photo. Please try another one.',
      );
    }
  }

  Widget _generatingView(OnboardingState state) {
    return Column(
      children: [
        const SizedBox(height: 36),
        SizedBox(
          width: 230,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _ReferenceAvatar(stage: state.stage, compact: true),
              const Positioned(
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: MomCozyV3Colors.surface,
                    shape: BoxShape.circle,
                    boxShadow: MomCozyShadows.soft,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(13),
                    child: SizedBox.square(
                      dimension: 25,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Creating your digital companion…',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        const Text(
          'This usually takes about a minute. You can keep this screen open while we finish.',
          textAlign: TextAlign.center,
          style: TextStyle(color: MomCozyV3Colors.mutedText, height: 1.45),
        ),
      ],
    );
  }

  Widget _reviewView(BuildContext context, OnboardingState state) {
    final fileId = state.avatar?.outputFileId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _IntroCopy(
          eyebrow: 'MEET YOUR DIGITAL YOU',
          title: 'How does she look?',
          body:
              'You can use this avatar now or choose a different portrait and try again.',
        ),
        const SizedBox(height: 22),
        Container(
          height: 390,
          decoration: BoxDecoration(
            color: MomCozyV3Colors.roseTint,
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.all(16),
          child: fileId == null
              ? _ReferenceAvatar(stage: state.stage)
              : _GeneratedAvatar(fileId: fileId),
        ),
        const SizedBox(height: 22),
        _errorText(controllerError: true),
        _PrimaryButton(
          label: 'Use this avatar',
          loading: widget.controller.busy,
          onPressed: widget.controller.busy
              ? null
              : widget.controller.completeWithGeneratedAvatar,
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: widget.controller.busy
              ? null
              : () => _choosePortrait(OnboardingPortraitSource.gallery),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('Try another photo'),
        ),
      ],
    );
  }

  Widget _errorText({bool controllerError = false}) {
    final message = controllerError && widget.controller.errorMessage.isNotEmpty
        ? widget.controller.errorMessage
        : _validationMessage;
    if (message.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xffffecec),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: MomCozyV3Colors.danger,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _LoadFailureView extends StatelessWidget {
  const _LoadFailureView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 52,
            color: MomCozyV3Colors.brand,
          ),
          const SizedBox(height: 18),
          const Text(
            'We couldn’t load your setup',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 22),
          _PrimaryButton(label: 'Try again', onPressed: onRetry),
        ],
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.step,
    required this.totalSteps,
    this.onBack,
  });

  final int step;
  final int totalSteps;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 20, 8),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 44,
            child: onBack == null
                ? null
                : IconButton(
                    tooltip: 'Back',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: step / totalSteps,
                minHeight: 6,
                backgroundColor: MomCozyV3Colors.divider,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$step/$totalSteps',
            style: const TextStyle(
              color: MomCozyV3Colors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroCopy extends StatelessWidget {
  const _IntroCopy({
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: MomCozyV3Colors.brand,
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: MomCozyV3Colors.ink,
            fontSize: 31,
            height: 1.12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: const TextStyle(
            color: MomCozyV3Colors.mutedText,
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.stage,
    required this.selected,
    required this.onTap,
  });

  final OnboardingCareStage stage;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (stage) {
      OnboardingCareStage.fertility => Icons.favorite_outline_rounded,
      OnboardingCareStage.pregnancy => Icons.pregnant_woman_rounded,
      OnboardingCareStage.postpartum => Icons.child_friendly_rounded,
    };
    return Material(
      color: selected ? MomCozyV3Colors.roseTint : MomCozyV3Colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? MomCozyV3Colors.brand : MomCozyV3Colors.divider,
          width: selected ? 1.8 : 1,
        ),
      ),
      child: InkWell(
        key: ValueKey('onboarding-stage-${stage.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: MomCozyV3Colors.surfaceTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: MomCozyV3Colors.brand),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stage.subtitle,
                      style: const TextStyle(color: MomCozyV3Colors.mutedText),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected
                    ? MomCozyV3Colors.brand
                    : MomCozyV3Colors.divider,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final display = value == null
        ? 'Choose date'
        : '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MomCozyRadii.control),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: [
            Expanded(child: Text(display)),
            const Icon(Icons.calendar_today_outlined, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CountField extends StatelessWidget {
  const _CountField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (var count = 1; count <= 6; count++)
          DropdownMenuItem(value: count, child: Text('$count')),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

class _InfantFields extends StatelessWidget {
  const _InfantFields({required this.index, required this.infant});

  final int index;
  final OnboardingInfantDraft infant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MomCozyV3Colors.surfaceTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Baby ${index + 1}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: infant.nickname,
            decoration: const InputDecoration(labelText: 'Nickname (optional)'),
            onChanged: (value) => infant.nickname = value,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: infant.sex,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Sex (optional)'),
            items: const [
              DropdownMenuItem(
                value: null,
                child: Text('Prefer not to say yet'),
              ),
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'intersex', child: Text('Intersex')),
              DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
            ],
            onChanged: (value) => infant.sex = value,
          ),
        ],
      ),
    );
  }
}

class _ReferenceAvatar extends StatelessWidget {
  const _ReferenceAvatar({required this.stage, this.compact = false});

  final OnboardingCareStage? stage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final asset = switch (stage) {
      OnboardingCareStage.pregnancy =>
        'assets/images/me_baby_overview/pregnancy_avatar.png',
      OnboardingCareStage.postpartum =>
        'assets/images/me_baby_overview/postpartum_avatar.png',
      _ => 'assets/images/me_baby_overview/mom_avatar.png',
    };
    return Container(
      height: compact ? 270 : 330,
      decoration: BoxDecoration(
        color: MomCozyV3Colors.roseTint,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.person_rounded,
          size: 120,
          color: MomCozyV3Colors.brand,
        ),
      ),
    );
  }
}

class _GeneratedAvatar extends StatefulWidget {
  const _GeneratedAvatar({required this.fileId});

  final String fileId;

  @override
  State<_GeneratedAvatar> createState() => _GeneratedAvatarState();
}

class _GeneratedAvatarState extends State<_GeneratedAvatar> {
  Future<Uint8List>? _load;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load ??= MomCozyRuntimeScope.of(
      context,
    ).mediaContentRepository.loadImage(widget.fileId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
          );
        }
        if (snapshot.hasError) {
          return const Center(
            child: Icon(Icons.broken_image_outlined, size: 52),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 19,
          color: MomCozyV3Colors.brand,
        ),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Your portrait is securely processed only to create this avatar. Our uploaded copy is deleted after success, or automatically within 24 hours.',
            style: TextStyle(color: MomCozyV3Colors.mutedText, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: MomCozyV3Colors.brand,
      ),
      child: loading
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
                Text(label),
              ],
            ),
    );
  }
}
