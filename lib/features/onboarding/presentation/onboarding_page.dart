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
    final totalSteps = _draft == null
        ? null
        : _totalStepsForStage(_draft!.stage);
    return Column(
      children: [
        _OnboardingHeader(
          step: _profileStep + 1,
          totalSteps: totalSteps,
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
              2 when _draft?.stage == OnboardingCareStage.postpartum =>
                _postpartumDeliveryStep(context),
              2 => _pregnancyDetailsStep(context),
              3 => _postpartumBirthStep(),
              _ => const SizedBox.shrink(),
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
        const _StepPrompt(
          title: 'Which stage are you in?',
          reason:
              'Your stage helps us show the right home, care plan, and digital companion.',
        ),
        const SizedBox(height: 22),
        for (final stage in OnboardingCareStage.values) ...[
          _StageCard(
            stage: stage,
            selected: _draft?.stage == stage,
            onTap: () => setState(() {
              _draft = OnboardingProfileDraft(stage: stage);
              _profileStep = 1;
              _validationMessage = '';
            }),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _basicsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepPrompt(
          title: 'A few basics first',
          reason:
              'Your name personalizes the app, and your age helps us tailor guidance safely.',
        ),
        const SizedBox(height: 24),
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
        _errorText(controllerError: true),
        _PrimaryButton(
          label: 'Continue',
          loading: widget.controller.busy,
          onPressed: widget.controller.busy ? null : _continueFromBasics,
        ),
      ],
    );
  }

  Future<void> _continueFromBasics() async {
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
    if (_draft!.stage == OnboardingCareStage.fertility) {
      setState(() => _validationMessage = '');
      await widget.controller.confirmProfile(_draft!);
      return;
    }
    setState(() {
      _profileStep = 2;
      _validationMessage = '';
    });
  }

  Widget _pregnancyDetailsStep(BuildContext context) {
    final draft = _draft!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepPrompt(
          title: 'About your pregnancy',
          reason:
              'Your due date and baby count help us time pregnancy guidance and prepare the right plan.',
        ),
        const SizedBox(height: 24),
        ..._pregnancyFields(context, draft),
        const SizedBox(height: 26),
        _errorText(controllerError: true),
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

  Widget _postpartumDeliveryStep(BuildContext context) {
    final draft = _draft!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepPrompt(
          title: 'When did you give birth?',
          reason:
              'The delivery date and pregnancy length help us time recovery and baby guidance.',
        ),
        const SizedBox(height: 24),
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
            if (selected != null) {
              setState(() => draft.deliveryDate = selected);
            }
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                key: const ValueKey('onboarding-gestational-weeks'),
                initialValue: draft.gestationalWeeks?.toString() ?? '',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Pregnancy weeks (optional)',
                ),
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
        const SizedBox(height: 26),
        _errorText(controllerError: true),
        _PrimaryButton(
          key: const ValueKey('onboarding-postpartum-delivery-continue'),
          label: 'Continue',
          onPressed: _continueFromPostpartumDelivery,
        ),
      ],
    );
  }

  void _continueFromPostpartumDelivery() {
    final draft = _draft!;
    if (draft.deliveryDate == null) {
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
    setState(() {
      _profileStep = 3;
      _validationMessage = '';
    });
  }

  Widget _postpartumBirthStep() {
    final draft = _draft!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepPrompt(
          title: 'How was your delivery?',
          reason:
              'Delivery method and baby count help personalize recovery and create the right baby profiles.',
        ),
        const SizedBox(height: 24),
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
          label: 'How many babies did you welcome?',
          value: draft.infantCount,
          onChanged: (value) => setState(() => draft.setInfantCount(value)),
        ),
        const SizedBox(height: 26),
        _errorText(),
        _PrimaryButton(
          key: const ValueKey('onboarding-postpartum-save'),
          label: 'Save and continue',
          loading: widget.controller.busy,
          onPressed: widget.controller.busy ? null : _submitProfile,
        ),
      ],
    );
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

  int _totalStepsForStage(OnboardingCareStage? stage) => switch (stage) {
    OnboardingCareStage.fertility => 3,
    OnboardingCareStage.pregnancy => 4,
    OnboardingCareStage.postpartum => 5,
    null => 4,
  };

  Widget _buildAvatarFlow(BuildContext context, OnboardingState state) {
    final totalSteps = _totalStepsForStage(state.stage);
    return Column(
      children: [
        _OnboardingHeader(step: totalSteps, totalSteps: totalSteps),
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
        _StepPrompt(
          title: failed
              ? 'Let’s try another photo'
              : 'Create your digital companion',
          reason: failed
              ? 'A clear, front-facing portrait helps us create a companion that feels more like you. We couldn’t use the last photo.'
              : 'A portrait helps us make your companion feel more like you.',
        ),
        const SizedBox(height: 18),
        _ReferenceAvatar(stage: state.stage, compact: true),
        const SizedBox(height: 18),
        _errorText(controllerError: true),
        _PrimaryButton(
          label: 'Upload a photo',
          icon: Icons.add_a_photo_outlined,
          loading: widget.controller.busy,
          onPressed: widget.controller.busy ? null : _showPortraitSourceSheet,
        ),
        const SizedBox(height: 10),
        const Padding(
          key: ValueKey('onboarding-photo-privacy-note'),
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: MomCozyV3Colors.mutedText,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your photo is used only to create your avatar. It is deleted after a successful generation, or automatically within 24 hours.',
                  style: TextStyle(
                    color: MomCozyV3Colors.mutedText,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: widget.controller.busy ? null : _confirmDefaultAvatar,
          child: const Text('Use the MomCozy character for now'),
        ),
      ],
    );
  }

  Future<void> _showPortraitSourceSheet() async {
    final source = await showModalBottomSheet<OnboardingPortraitSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text(
                  'Choose a photo',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              ListTile(
                key: const ValueKey('onboarding-camera-source'),
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () =>
                    Navigator.of(context).pop(OnboardingPortraitSource.camera),
              ),
              ListTile(
                key: const ValueKey('onboarding-library-source'),
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from library'),
                onTap: () =>
                    Navigator.of(context).pop(OnboardingPortraitSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null && mounted) await _choosePortrait(source);
  }

  Future<void> _confirmDefaultAvatar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Continue with MomCozy character?'),
        content: const Text(
          'You can use the original character for your current stage instead of creating a personalized one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await widget.controller.completeWithDefaultAvatar();
    }
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
          'Creating four companions…',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        const Text(
          'This can take a little while. Keep this screen open while we prepare four options for you.',
          textAlign: TextAlign.center,
          style: TextStyle(color: MomCozyV3Colors.mutedText, height: 1.45),
        ),
      ],
    );
  }

  Widget _reviewView(BuildContext context, OnboardingState state) {
    final candidates = state.avatar?.candidates ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepPrompt(
          title: 'Choose your companion',
          reason:
              'We created four interpretations so you can choose the one that feels most like you.',
        ),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: candidates.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) {
            final candidate = candidates[index];
            return _AvatarCandidateCard(
              key: ValueKey(
                'onboarding-avatar-candidate-${candidate.position}',
              ),
              candidate: candidate,
              selected:
                  widget.controller.selectedAvatarCandidateId == candidate.id,
              onTap: widget.controller.busy
                  ? null
                  : () => widget.controller.selectAvatarCandidate(candidate.id),
            );
          },
        ),
        const SizedBox(height: 12),
        _DefaultAvatarChoiceCard(
          key: const ValueKey('onboarding-avatar-default'),
          stage: state.stage,
          selected: widget.controller.defaultAvatarSelected,
          onTap: widget.controller.busy
              ? null
              : widget.controller.selectDefaultAvatar,
        ),
        const SizedBox(height: 20),
        _errorText(controllerError: true),
        _PrimaryButton(
          label: 'Continue with this avatar',
          loading: widget.controller.busy,
          onPressed:
              widget.controller.busy || !widget.controller.hasAvatarSelection
              ? null
              : widget.controller.confirmAvatarSelection,
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: widget.controller.busy ? null : _showPortraitSourceSheet,
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
  const _OnboardingHeader({required this.step, this.totalSteps, this.onBack});

  final int step;
  final int? totalSteps;
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
                value: totalSteps == null ? 0.2 : step / totalSteps!,
                minHeight: 6,
                backgroundColor: MomCozyV3Colors.divider,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            totalSteps == null ? 'Step $step' : '$step/$totalSteps',
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

class _StepPrompt extends StatelessWidget {
  const _StepPrompt({required this.title, required this.reason});

  final String title;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: MomCozyV3Colors.ink,
            fontSize: 29,
            height: 1.12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MomCozyV3Colors.surfaceTint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                size: 18,
                color: MomCozyV3Colors.brand,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Why we ask: ',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: reason),
                    ],
                  ),
                  style: const TextStyle(
                    color: MomCozyV3Colors.mutedText,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
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
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? MomCozyV3Colors.brand : MomCozyV3Colors.divider,
          width: selected ? 1.8 : 1,
        ),
      ),
      child: InkWell(
        key: ValueKey('onboarding-stage-${stage.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: MomCozyV3Colors.surfaceTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: MomCozyV3Colors.brand),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  stage.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
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

class _ReferenceAvatar extends StatelessWidget {
  const _ReferenceAvatar({required this.stage, this.compact = false});

  final OnboardingCareStage? stage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 270 : 330,
      decoration: BoxDecoration(
        color: MomCozyV3Colors.roseTint,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: Image.asset(
        _referenceAvatarAsset(stage),
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

class _AvatarCandidateCard extends StatelessWidget {
  const _AvatarCandidateCard({
    super.key,
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final OnboardingAvatarCandidate candidate;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Avatar option ${candidate.position}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: MomCozyV3Colors.roseTint,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? MomCozyV3Colors.brand
                    : MomCozyV3Colors.divider,
                width: selected ? 2.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 30),
                    child: _GeneratedAvatar(fileId: candidate.fileId),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 9,
                  child: Text(
                    'Option ${candidate.position}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (selected)
                  const Positioned(
                    top: 9,
                    right: 9,
                    child: _AvatarSelectedMark(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DefaultAvatarChoiceCard extends StatelessWidget {
  const _DefaultAvatarChoiceCard({
    super.key,
    required this.stage,
    required this.selected,
    required this.onTap,
  });

  final OnboardingCareStage? stage;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Continue with the MomCozy character',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 112),
            padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
            decoration: BoxDecoration(
              color: MomCozyV3Colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? MomCozyV3Colors.brand
                    : MomCozyV3Colors.divider,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 82,
                  height: 96,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ColoredBox(
                      color: MomCozyV3Colors.roseTint,
                      child: Image.asset(
                        _referenceAvatarAsset(stage),
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MomCozy original',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Continue with the character for your current stage',
                        style: TextStyle(
                          color: MomCozyV3Colors.mutedText,
                          fontSize: 12.5,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) const _AvatarSelectedMark(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarSelectedMark extends StatelessWidget {
  const _AvatarSelectedMark();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: MomCozyV3Colors.brand,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Icons.check_rounded, color: Colors.white, size: 16),
      ),
    );
  }
}

String _referenceAvatarAsset(OnboardingCareStage? stage) => switch (stage) {
  OnboardingCareStage.pregnancy =>
    'assets/images/me_baby_overview/pregnancy_avatar.png',
  OnboardingCareStage.postpartum =>
    'assets/images/me_baby_overview/postpartum_avatar.png',
  _ => 'assets/images/me_baby_overview/mom_avatar.png',
};

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
    ).mediaContentRepository.loadImageThumbnail(widget.fileId);
  }

  @override
  void didUpdateWidget(covariant _GeneratedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileId != widget.fileId) {
      _load = MomCozyRuntimeScope.of(
        context,
      ).mediaContentRepository.loadImageThumbnail(widget.fileId);
    }
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

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    super.key,
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
              children: [
                if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (icon != null) const SizedBox(width: 32),
              ],
            ),
    );
  }
}
