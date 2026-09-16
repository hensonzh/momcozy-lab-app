import 'dart:async';
import 'dart:typed_data';
import '../../auth/presentation/auth_login_chrome.dart';

import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/widgets/date_time_picker.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../shared/widgets/product_feedback.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_text_roles.dart';
import 'package:momcozy_flutter_app/features/onboarding/data/platform_portrait_picker.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/onboarding.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';

typedef OnboardingPortraitPicker =
    Future<OnboardingPortrait?> Function(OnboardingPortraitSource source);
typedef OnboardingAvatarImageLoader = Future<Uint8List> Function(String fileId);

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.controller,
    this.pickPortrait,
    this.entryPath = '/',
    this.avatarTaskMode = false,
    this.avatarThumbnailLoader,
    this.onAvatarTaskCompleted,
  });

  final OnboardingController controller;
  final OnboardingPortraitPicker? pickPortrait;
  final String entryPath;
  final bool avatarTaskMode;
  final OnboardingAvatarImageLoader? avatarThumbnailLoader;
  final VoidCallback? onAvatarTaskCompleted;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final OnboardingPortraitPicker _pickPortrait =
      widget.pickPortrait ?? OnboardingPlatformPortraitPicker().pick;
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _profileScroll = ScrollController();
  int _profileStep = 0;
  final OnboardingProfileDraft _draft = OnboardingProfileDraft();
  bool _editingConfirmedProfile = false;
  bool _activatingAvatar = false;
  bool _avatarReturnScheduled = false;
  String _validationMessage = '';

  @override
  void dispose() {
    _profileScroll.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = authLoginTheme(Theme.of(context));
    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: authRose,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 52),
            textStyle: theme.textTheme.labelLarge!.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          return Scaffold(
            backgroundColor: authBackground,
            body: MomCozyPageBody(
              child: switch (controller.phase) {
                OnboardingGatePhase.idle ||
                OnboardingGatePhase.loading => const ProductLoadingView(),
                OnboardingGatePhase.failure => SingleChildScrollView(
                  child: ProductEmptyView(
                    title: 'We couldn’t load your setup',
                    description: controller.errorMessage,
                    icon: Icons.cloud_off_rounded,
                    action: MomCozyPrimaryButton(
                      onPressed: controller.load,
                      child: const Text('Try again'),
                    ),
                  ),
                ),
                OnboardingGatePhase.ready => _buildReady(context),
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildReady(BuildContext context) {
    final state = widget.controller.state;
    if (state == null) return const ProductLoadingView();
    if (!state.profileConfirmed || _editingConfirmedProfile) {
      return _buildProfileFlow(context);
    }
    return _buildAvatarFlow(context, state);
  }

  void _goToProfileStep(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _profileStep = step;
      _validationMessage = '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _profileScroll.hasClients) _profileScroll.jumpTo(0);
    });
  }

  Widget _buildProfileFlow(BuildContext context) {
    return Column(
      children: [
        _OnboardingHeader(
          step: _profileStep + 1,
          totalSteps: 4,
          onBack: _profileStep == 0 || widget.controller.busy
              ? null
              : () => _goToProfileStep(_profileStep - 1),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _profileScroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
            child: switch (_profileStep) {
              0 => _basicsStep(),
              1 => _postpartumDeliveryStep(context),
              2 => _postpartumBirthStep(),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
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
        const SizedBox(height: MomCozySpacing.section),
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
        const SizedBox(height: MomCozySpacing.page),
        TextField(
          key: const ValueKey('onboarding-age'),
          controller: _ageController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Age',
            hintText: 'e.g. 32',
          ),
        ),
        const SizedBox(height: MomCozySpacing.section),
        _errorText(controllerError: true),
        MomCozyPrimaryButton(
          loading: widget.controller.busy,
          onPressed: widget.controller.busy ? null : _continueFromBasics,
          child: const Text('Continue'),
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
    _draft
      ..displayName = _nameController.text.trim()
      ..age = age;
    _goToProfileStep(1);
  }

  Widget _postpartumDeliveryStep(BuildContext context) {
    final draft = _draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepPrompt(
          title: 'Tell us about your delivery',
          reason:
              'Your delivery date helps personalize postpartum recovery and your baby’s age-based guidance.',
        ),
        const SizedBox(height: MomCozySpacing.section),
        _DateField(
          label: 'Delivery date',
          value: draft.deliveryDate,
          onTap: () async {
            final today = DateUtils.dateOnly(DateTime.now());
            final selected = await showMomCozyDatePicker(
              context: context,
              initialDate: draft.deliveryDate ?? today,
              firstDate: DateTime(today.year - 2),
              lastDate: today,
            );
            if (selected != null) setState(() => draft.deliveryDate = selected);
          },
        ),
        const SizedBox(height: MomCozySpacing.section),
        _errorText(controllerError: true),
        MomCozyPrimaryButton(
          key: const ValueKey('onboarding-postpartum-delivery-continue'),
          onPressed: _continueFromPostpartumDelivery,
          child: const Text('Continue'),
        ),
      ],
    );
  }

  void _continueFromPostpartumDelivery() {
    if (_draft.deliveryDate == null) {
      setState(() => _validationMessage = 'Choose your delivery date.');
      return;
    }
    _goToProfileStep(2);
  }

  Widget _postpartumBirthStep() {
    final draft = _draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepPrompt(
          title: 'How was your delivery?',
          reason:
              'Delivery method and baby count help personalize recovery and create the right baby profiles.',
        ),
        const SizedBox(height: MomCozySpacing.section),
        DropdownButtonFormField<String?>(
          initialValue: draft.deliveryType,
          isExpanded: true,
          itemHeight: null,
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
        const SizedBox(height: MomCozySpacing.page),
        _CountField(
          label: 'How many babies did you welcome?',
          value: draft.infantCount,
          onChanged: (value) => setState(() => draft.setInfantCount(value)),
        ),
        const SizedBox(height: MomCozySpacing.section),
        _errorText(controllerError: true),
        MomCozyPrimaryButton(
          key: const ValueKey('onboarding-postpartum-save'),
          loading: widget.controller.busy,
          onPressed: widget.controller.busy ? null : _submitProfile,
          child: const Text('Save and continue'),
        ),
      ],
    );
  }

  Future<void> _submitProfile() async {
    final draft = _draft;
    if (draft.deliveryDate == null) {
      setState(() => _validationMessage = 'Choose your delivery date.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _validationMessage = '');
    await _confirmProfile(draft);
  }

  Future<void> _confirmProfile(OnboardingProfileDraft draft) async {
    final confirmed = await widget.controller.confirmProfile(draft);
    if (!mounted || !confirmed) return;
    setState(() => _editingConfirmedProfile = false);
  }

  Widget _buildAvatarFlow(BuildContext context, OnboardingState state) {
    if (widget.avatarTaskMode &&
        _activatingAvatar &&
        state.isCompleted &&
        state.pendingAvatar == null) {
      _scheduleAvatarTaskReturn();
    }
    final flowStatus =
        _activatingAvatar && state.isCompleted && state.pendingAvatar == null
        ? OnboardingStatus.completed
        : state.pendingAvatar?.status ??
              (widget.avatarTaskMode && state.avatarSetupCompleted
                  ? OnboardingStatus.avatarRequired
                  : state.status);
    const totalSteps = 4;
    final canReturnToProfile = !state.canEnterApp && !widget.controller.busy;
    return Column(
      children: [
        if (widget.avatarTaskMode)
          _AvatarTaskHeader(
            onBack: widget.controller.busy || _activatingAvatar
                ? null
                : _leaveAvatarTaskPage,
          )
        else
          _OnboardingHeader(
            step: totalSteps,
            totalSteps: totalSteps,
            backKey: const ValueKey('onboarding-avatar-back'),
            onBack: canReturnToProfile ? _returnToProfileFlow : null,
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
            child: switch (flowStatus) {
              OnboardingStatus.avatarGenerating => _generatingView(state),
              OnboardingStatus.avatarReview => _reviewView(context, state),
              OnboardingStatus.avatarFailed => _avatarChoiceView(
                state,
                failed: true,
              ),
              OnboardingStatus.completed =>
                const _AvatarActivationSuccessView(),
              _ => _avatarChoiceView(state),
            },
          ),
        ),
      ],
    );
  }

  void _returnToProfileFlow() {
    widget.controller.clearError();
    setState(() {
      _profileStep = 2;
      _editingConfirmedProfile = true;
      _validationMessage = '';
    });
  }

  Widget _avatarChoiceView(OnboardingState state, {bool failed = false}) {
    final replacing = state.avatarSetupCompleted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepPrompt(
          title: failed
              ? 'Let’s try another photo'
              : replacing
              ? 'Create a new digital companion'
              : 'Create your digital companion',
          reason: failed
              ? 'A clear, front-facing portrait helps us create a companion that feels more like you. We couldn’t use the last photo.'
              : replacing
              ? 'Your current companion stays active until you choose and confirm a new one.'
              : 'A portrait helps us make your companion feel more like you.',
        ),
        const SizedBox(height: MomCozySpacing.card),
        const _ReferenceAvatar(compact: true),
        const SizedBox(height: MomCozySpacing.card),
        _errorText(controllerError: true),
        MomCozyPrimaryButton(
          icon: Icons.add_a_photo_outlined,
          loading: widget.controller.busy,
          onPressed: widget.controller.busy ? null : _showPortraitSourceSheet,
          child: const Text('Upload a photo'),
        ),
        const SizedBox(height: MomCozySpacing.statusGap),
        Padding(
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
                  color: MomCozyColors.mutedForeground,
                ),
              ),
              SizedBox(width: MomCozySpacing.compact),
              Expanded(
                child: Text(
                  'Your photo is used only to create your avatar. It is deleted after a successful generation, or automatically within 24 hours.',
                  style: MomCozyTextRoles.paragraphOf(context).copyWith(
                    color: MomCozyColors.mutedForeground,
                    fontSize: MomCozyTypography.secondarySize,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MomCozySpacing.xs),
        if (state.canContinueWithDefault)
          TextButton(
            onPressed: widget.controller.busy ? null : _confirmDefaultAvatar,
            child: const Text('Use the MomCozy character for now'),
          )
        else if (failed && state.pendingAvatar != null)
          TextButton(
            onPressed: widget.controller.busy ? null : _keepCurrentAvatar,
            child: const Text('Keep my current companion'),
          ),
      ],
    );
  }

  Future<void> _showPortraitSourceSheet() async {
    final source = await showModalBottomSheet<OnboardingPortraitSource>(
      context: context,
      sheetAnimationStyle: MomCozyMotion.animationStyle(context),
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
                  style: TextStyle(
                    fontSize: MomCozyTypography.headingSize,
                    fontWeight: FontWeight.w700,
                  ),
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
      animationStyle: MomCozyMotion.animationStyle(context),
      builder: (context) => AlertDialog(
        title: const Text('Continue with MomCozy character?'),
        content: const Text(
          'You can use the MomCozy postpartum companion instead of creating a personalized one.',
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
      await _activateAvatar(widget.controller.completeWithDefaultAvatar);
    }
  }

  Future<void> _choosePortrait(OnboardingPortraitSource source) async {
    widget.controller.clearError();
    try {
      final portrait = await _pickPortrait(source);
      if (portrait == null) return;
      final accepted = await widget.controller.uploadAndGenerate(portrait);
      if (!mounted ||
          !accepted ||
          widget.controller.state?.canEnterApp != true) {
        return;
      }
      if (widget.avatarTaskMode) {
        _leaveAvatarTaskPage();
        return;
      }
      await _showGenerationHandoff();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _validationMessage = error is FormatException
            ? error.message
            : 'We couldn’t open that photo. Please try another one.',
      );
    }
  }

  Future<void> _showGenerationHandoff() async {
    final enterApp = await showDialog<bool>(
      context: context,
      animationStyle: MomCozyMotion.animationStyle(context),
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: const CircleAvatar(
            radius: 28,
            backgroundColor: MomCozyColors.roseSoft,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: MomCozyColors.primaryDark,
              size: 28,
            ),
          ),
          title: const Text(
            'Your digital companion is being created',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Creating four options can take a few minutes. We’ll keep working in the cloud, so you can start using the app now. We’ll let you know when they’re ready.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Wait here'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Enter the app'),
            ),
          ],
        ),
      ),
    );
    if (enterApp == true && mounted) context.go(widget.entryPath);
  }

  void _leaveAvatarTaskPage({bool showCompletion = false}) {
    final onReturned = showCompletion ? widget.onAvatarTaskCompleted : null;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      context.pop();
    } else {
      context.go(widget.entryPath);
    }
    if (onReturned != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onReturned());
    }
  }

  void _scheduleAvatarTaskReturn() {
    if (_avatarReturnScheduled) return;
    _avatarReturnScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _leaveAvatarTaskPage(showCompletion: true);
    });
  }

  Widget _generatingView(OnboardingState state) {
    return _AvatarGenerationWaitingView(
      phase:
          state.pendingAvatar?.phase ?? OnboardingAvatarGenerationPhase.unknown,
    );
  }

  Widget _reviewView(BuildContext context, OnboardingState state) {
    final candidates = state.pendingAvatar?.candidates ?? const [];
    final thumbnailLoader =
        widget.avatarThumbnailLoader ??
        MomCozyRuntimeScope.of(
          context,
        ).mediaContentRepository.loadImageThumbnail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepPrompt(
          title: 'Choose your companion',
          reason:
              'We created four interpretations so you can choose the one that feels most like you.',
        ),
        const SizedBox(height: MomCozySpacing.card),
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
              loadThumbnail: thumbnailLoader,
              selected:
                  widget.controller.selectedAvatarCandidateId == candidate.id,
              onTap: widget.controller.busy || _activatingAvatar
                  ? null
                  : () => widget.controller.selectAvatarCandidate(candidate.id),
            );
          },
        ),
        const SizedBox(height: MomCozySpacing.content),
        if (state.canContinueWithDefault)
          _DefaultAvatarChoiceCard(
            key: const ValueKey('onboarding-avatar-default'),
            selected: widget.controller.defaultAvatarSelected,
            onTap: widget.controller.busy || _activatingAvatar
                ? null
                : widget.controller.selectDefaultAvatar,
          ),
        const SizedBox(height: MomCozySpacing.card),
        _errorText(controllerError: true),
        MomCozyPrimaryButton(
          loading: widget.controller.busy || _activatingAvatar,
          onPressed:
              widget.controller.busy ||
                  _activatingAvatar ||
                  !widget.controller.hasAvatarSelection
              ? null
              : _confirmAvatarSelection,
          child: const Text('Continue with this avatar'),
        ),
        const SizedBox(height: MomCozySpacing.statusGap),
        OutlinedButton(
          onPressed: widget.controller.busy || _activatingAvatar
              ? null
              : _showPortraitSourceSheet,
          child: const Text('Try another photo'),
        ),
        if (state.avatarSetupCompleted) ...[
          const SizedBox(height: MomCozySpacing.compact),
          TextButton(
            onPressed: widget.controller.busy || _activatingAvatar
                ? null
                : _keepCurrentAvatar,
            child: const Text('Keep my current companion'),
          ),
        ],
      ],
    );
  }

  Future<void> _keepCurrentAvatar() async {
    final dismissed = await widget.controller.dismissPendingAvatar();
    if (dismissed && mounted) _leaveAvatarTaskPage();
  }

  Future<void> _confirmAvatarSelection() async {
    await _activateAvatar(widget.controller.confirmAvatarSelection);
  }

  Future<void> _activateAvatar(Future<bool> Function() action) async {
    if (_activatingAvatar) return;
    setState(() => _activatingAvatar = true);
    final completed = await action();
    if (!mounted) return;
    if (completed && widget.avatarTaskMode) {
      _scheduleAvatarTaskReturn();
      return;
    }
    setState(() => _activatingAvatar = false);
  }

  Widget _errorText({bool controllerError = false}) {
    final message = controllerError && widget.controller.errorMessage.isNotEmpty
        ? widget.controller.errorMessage
        : _validationMessage;
    if (message.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(MomCozySpacing.content),
        decoration: BoxDecoration(
          color: MomCozyColors.errorSurface,
          borderRadius: BorderRadius.circular(MomCozyRadii.control),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: MomCozyColors.danger,
            ),
            const SizedBox(width: MomCozySpacing.statusGap),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.step,
    this.totalSteps,
    this.backKey,
    this.onBack,
  });

  final int step;
  final int? totalSteps;
  final Key? backKey;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 20, 8),
      child: Row(
        children: [
          SizedBox.square(
            dimension: MomCozyTapTargets.minimum,
            child: onBack == null
                ? null
                : IconButton(
                    key: backKey,
                    tooltip: 'Back',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
          ),
          const SizedBox(width: MomCozySpacing.compact),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MomCozyRadii.pill),
              child: LinearProgressIndicator(
                value: totalSteps == null ? 0.2 : step / totalSteps!,
                minHeight: 6,
                backgroundColor: MomCozyColors.border,
              ),
            ),
          ),
          const SizedBox(width: MomCozySpacing.content),
          Text(
            totalSteps == null ? 'Step $step' : '$step/$totalSteps',
            style: const TextStyle(
              color: MomCozyColors.mutedForeground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarTaskHeader extends StatelessWidget {
  const _AvatarTaskHeader({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 8),
      child: Row(
        children: [
          SizedBox.square(
            dimension: MomCozyTapTargets.minimum,
            child: IconButton(
              key: const ValueKey('onboarding-avatar-back'),
              tooltip: 'Back to the app',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const SizedBox(width: MomCozySpacing.compact),
          const Expanded(
            child: Text(
              'Digital companion',
              style: TextStyle(
                color: MomCozyColors.foreground,
                fontSize: MomCozyTypography.sectionSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarActivationSuccessView extends StatelessWidget {
  const _AvatarActivationSuccessView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('avatar-activation-success'),
      padding: const EdgeInsets.only(top: 72),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 38,
            backgroundColor: MomCozyColors.careSoft,
            child: Icon(
              Icons.check_rounded,
              color: MomCozyColors.care,
              size: 42,
            ),
          ),
          const SizedBox(height: MomCozySpacing.section),
          const Text(
            'Your digital companion is ready',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MomCozyColors.foreground,
              fontSize: MomCozyTypography.pageTitleSize,
              height: 1.43,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: MomCozySpacing.statusGap),
          Text(
            'Applying your choice and returning you to the app…',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.merge(MomCozyTextRoles.paragraphOf(context))
                .copyWith(color: MomCozyColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class _StepPrompt extends StatelessWidget {
  const _StepPrompt({required this.title, required this.reason});
  final String title, reason;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontFamily: 'LibreCaslonDisplay',
          color: authInk,
          fontSize: 32,
          height: 1.2,
          fontWeight: FontWeight.w400,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        reason,
        style: MomCozyTextRoles.paragraphOf(
          context,
        ).copyWith(fontSize: 14, color: authMuted),
      ),
    ],
  );
}

class _AvatarGenerationWaitingView extends StatelessWidget {
  const _AvatarGenerationWaitingView({required this.phase});

  final OnboardingAvatarGenerationPhase phase;

  @override
  Widget build(BuildContext context) {
    final statusTitle = switch (phase) {
      OnboardingAvatarGenerationPhase.queued => 'Waiting to start',
      OnboardingAvatarGenerationPhase.generating =>
        'Creating your four options',
      _ => 'Preparing your options',
    };
    final statusDescription = switch (phase) {
      OnboardingAvatarGenerationPhase.queued =>
        'Your photo is uploaded. Image creation will begin as soon as a generation slot is available.',
      OnboardingAvatarGenerationPhase.generating =>
        'We’re using your photo and the MomCozy illustration style. This is usually the longest part.',
      _ =>
        'We’re preparing your photo and the MomCozy illustration style for image creation.',
    };

    return Column(
      key: const ValueKey('onboarding-avatar-generation-waiting'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepPrompt(
          title: 'Your four options are on the way',
          reason:
              'Your photo has been received. When all four MomCozy-style companions are ready, this page will update so you can choose your favorite.',
        ),
        const SizedBox(height: MomCozySpacing.section),
        const _AvatarGenerationRecipe(),
        const SizedBox(height: MomCozySpacing.page),
        _AvatarGenerationTimeline(
          statusTitle: statusTitle,
          statusDescription: statusDescription,
        ),
        const SizedBox(height: MomCozySpacing.headingGap),
        const _AvatarGenerationWaitNote(),
      ],
    );
  }
}

class _AvatarGenerationRecipe extends StatelessWidget {
  const _AvatarGenerationRecipe();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label:
          'Your uploaded photo and the MomCozy illustration style are being used to create four avatar options.',
      child: ExcludeSemantics(
        child: MomCozySurface(
          key: const ValueKey('onboarding-avatar-generation-recipe'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What’s happening',
                style: TextStyle(
                  color: MomCozyColors.foreground,
                  fontSize: MomCozyTypography.bodySize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: MomCozySpacing.headingGap),
              LayoutBuilder(
                builder: (context, constraints) {
                  final textScale = MediaQuery.textScalerOf(context).scale(1);
                  final stacked = constraints.maxWidth < 268 || textScale > 1.3;
                  final photo = const _AvatarGenerationRecipeNode(
                    label: 'Your photo',
                    visual: _AvatarPhotoReceivedVisual(),
                  );
                  const style = _AvatarGenerationRecipeNode(
                    label: 'MomCozy style',
                    visual: _AvatarReferenceStyleVisual(),
                  );
                  const options = _AvatarGenerationRecipeNode(
                    width: 84,
                    label: '4 options',
                    visual: _AvatarOptionsVisual(),
                  );

                  if (stacked) {
                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            photo,
                            const _AvatarGenerationOperator(
                              icon: Icons.add_rounded,
                            ),
                            style,
                          ],
                        ),
                        const SizedBox(height: MomCozySpacing.compact),
                        const Icon(
                          Icons.arrow_downward_rounded,
                          color: MomCozyColors.primaryDark,
                          size: 22,
                        ),
                        const SizedBox(height: MomCozySpacing.compact),
                        options,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      photo,
                      const _AvatarGenerationOperator(icon: Icons.add_rounded),
                      style,
                      const _AvatarGenerationOperator(
                        icon: Icons.arrow_forward_rounded,
                      ),
                      options,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarGenerationRecipeNode extends StatelessWidget {
  const _AvatarGenerationRecipeNode({
    required this.label,
    required this.visual,
    this.width = 72,
  });

  final String label;
  final Widget visual;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          visual,
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MomCozyColors.mutedForeground,
              fontSize: MomCozyTypography.captionSize,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarGenerationOperator extends StatelessWidget {
  const _AvatarGenerationOperator({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 0),
      child: Icon(icon, color: MomCozyColors.primaryDark, size: 20),
    );
  }
}

class _AvatarPhotoReceivedVisual extends StatelessWidget {
  const _AvatarPhotoReceivedVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 58,
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: MomCozyColors.secondary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_a_photo_outlined,
                color: MomCozyColors.primaryDark,
                size: 25,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: MomCozyColors.care,
                shape: BoxShape.circle,
                border: Border.all(color: MomCozyColors.raised, width: 2),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: MomCozyColors.raised,
                size: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarReferenceStyleVisual extends StatelessWidget {
  const _AvatarReferenceStyleVisual();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MomCozyColors.roseSoft,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(color: MomCozyColors.border),
          ),
        ),
        child: Icon(
          Icons.auto_awesome_rounded,
          color: MomCozyColors.primaryDark,
          size: 27,
        ),
      ),
    );
  }
}

class _AvatarOptionsVisual extends StatelessWidget {
  const _AvatarOptionsVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 58,
      child: Column(
        children: [
          _row(),
          const SizedBox(height: MomCozySpacing.xs),
          _row(),
        ],
      ),
    );
  }

  Widget _row() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _AvatarOptionPlaceholder(),
        SizedBox(width: MomCozySpacing.xs),
        _AvatarOptionPlaceholder(),
      ],
    );
  }
}

class _AvatarOptionPlaceholder extends StatelessWidget {
  const _AvatarOptionPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 30,
      height: 27,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MomCozyColors.roseSoft,
          borderRadius: BorderRadius.all(
            Radius.circular(MomCozyRadii.thumbnail),
          ),
        ),
        child: Icon(
          Icons.person_outline_rounded,
          color: MomCozyColors.primaryDark,
          size: 16,
        ),
      ),
    );
  }
}

class _AvatarGenerationTimeline extends StatelessWidget {
  const _AvatarGenerationTimeline({
    required this.statusTitle,
    required this.statusDescription,
  });

  final String statusTitle;
  final String statusDescription;

  @override
  Widget build(BuildContext context) {
    return MomCozySurface(
      key: const ValueKey('onboarding-avatar-generation-timeline'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where we are',
            style: TextStyle(
              color: MomCozyColors.foreground,
              fontSize: MomCozyTypography.bodySize,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: MomCozySpacing.headingGap),
          const _AvatarGenerationStep(
            state: _AvatarGenerationStepState.complete,
            title: 'Photo uploaded',
          ),
          const _AvatarGenerationConnector(active: true),
          _AvatarGenerationStep(
            key: const ValueKey('onboarding-avatar-generation-current-status'),
            state: _AvatarGenerationStepState.active,
            title: statusTitle,
            description: statusDescription,
          ),
          const _AvatarGenerationConnector(active: false),
          const _AvatarGenerationStep(
            state: _AvatarGenerationStepState.upcoming,
            title: 'Choose your favorite',
          ),
        ],
      ),
    );
  }
}

enum _AvatarGenerationStepState { complete, active, upcoming }

class _AvatarGenerationStep extends StatelessWidget {
  const _AvatarGenerationStep({
    super.key,
    required this.state,
    required this.title,
    this.description,
  });

  final _AvatarGenerationStepState state;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final active = state == _AvatarGenerationStepState.active;
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: switch (state) {
              _AvatarGenerationStepState.complete => MomCozyColors.primaryDark,
              _AvatarGenerationStepState.active => MomCozyColors.roseSoft,
              _AvatarGenerationStepState.upcoming => MomCozyColors.secondary,
            },
            shape: BoxShape.circle,
            border: active
                ? Border.all(color: MomCozyColors.primaryDark)
                : null,
          ),
          alignment: Alignment.center,
          child: switch (state) {
            _AvatarGenerationStepState.complete => const Icon(
              Icons.check_rounded,
              color: MomCozyColors.raised,
              size: 17,
            ),
            _AvatarGenerationStepState.active => const SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            _AvatarGenerationStepState.upcoming => const Icon(
              Icons.favorite_outline_rounded,
              color: MomCozyColors.mutedForeground,
              size: 16,
            ),
          },
        ),
        const SizedBox(width: MomCozySpacing.content),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: active
                        ? MomCozyColors.foreground
                        : state == _AvatarGenerationStepState.upcoming
                        ? MomCozyColors.mutedForeground
                        : MomCozyColors.foreground,
                    fontSize: MomCozyTypography.bodySize,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    description!,
                    style: MomCozyTextRoles.paragraphOf(context).copyWith(
                      color: MomCozyColors.mutedForeground,
                      fontSize: MomCozyTypography.secondarySize,
                    ),
                  ),
                  const SizedBox(height: MomCozySpacing.statusGap),
                  const LinearProgressIndicator(
                    minHeight: 4,
                    borderRadius: BorderRadius.all(
                      Radius.circular(MomCozyRadii.pill),
                    ),
                    backgroundColor: MomCozyColors.border,
                    semanticsLabel: 'Avatar generation in progress',
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );

    if (!active) return content;
    return Semantics(
      liveRegion: true,
      label: 'Current step: $title. $description',
      child: ExcludeSemantics(child: content),
    );
  }
}

class _AvatarGenerationConnector extends StatelessWidget {
  const _AvatarGenerationConnector({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 13),
      child: SizedBox(
        width: 2,
        height: 13,
        child: ColoredBox(
          color: active ? MomCozyColors.primaryDark : MomCozyColors.border,
        ),
      ),
    );
  }
}

class _AvatarGenerationWaitNote extends StatelessWidget {
  const _AvatarGenerationWaitNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('onboarding-avatar-generation-wait-note'),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: MomCozyColors.secondary,
        borderRadius: BorderRadius.circular(MomCozyRadii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.schedule_rounded,
              color: MomCozyColors.primaryDark,
              size: 19,
            ),
          ),
          SizedBox(width: MomCozySpacing.compact),
          Expanded(
            child: Text(
              'Image generation can take a few minutes. There’s nothing else you need to do—generation continues in the cloud if you briefly leave the app.',
              style: MomCozyTextRoles.paragraphOf(context).copyWith(
                color: MomCozyColors.mutedForeground,
                fontSize: MomCozyTypography.secondarySize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
  const _ReferenceAvatar({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 270 : 330,
      decoration: BoxDecoration(
        color: MomCozyColors.roseSoft,
        borderRadius: BorderRadius.circular(MomCozyRadii.featured),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: Image.asset(
        _referenceAvatarAsset,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.person_rounded,
          size: 120,
          color: MomCozyColors.primaryDark,
        ),
      ),
    );
  }
}

class _AvatarCandidateCard extends StatefulWidget {
  const _AvatarCandidateCard({
    super.key,
    required this.candidate,
    required this.loadThumbnail,
    required this.selected,
    required this.onTap,
  });

  final OnboardingAvatarCandidate candidate;
  final OnboardingAvatarImageLoader loadThumbnail;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_AvatarCandidateCard> createState() => _AvatarCandidateCardState();
}

class _AvatarCandidateCardState extends State<_AvatarCandidateCard> {
  bool _imageReady = false;

  @override
  void didUpdateWidget(covariant _AvatarCandidateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidate.fileId != widget.candidate.fileId) {
      _imageReady = false;
    }
  }

  void _handleImageReadyChanged(bool value) {
    if (!mounted || _imageReady == value) return;
    setState(() => _imageReady = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _imageReady && widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: 'Avatar option ${widget.candidate.position}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? widget.onTap : null,
          borderRadius: BorderRadius.circular(MomCozyRadii.card),
          child: AnimatedContainer(
            duration: MomCozyMotion.duration(
              context,
              const Duration(milliseconds: 160),
            ),
            decoration: BoxDecoration(
              color: MomCozyColors.roseSoft,
              borderRadius: BorderRadius.circular(MomCozyRadii.card),
              border: Border.all(
                color: widget.selected
                    ? MomCozyColors.primaryDark
                    : MomCozyColors.border,
                width: widget.selected ? 2.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 30),
                    child: _GeneratedAvatar(
                      fileId: widget.candidate.fileId,
                      loadThumbnail: widget.loadThumbnail,
                      onReadyChanged: _handleImageReadyChanged,
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 9,
                  child: Text(
                    'Option ${widget.candidate.position}',
                    style: const TextStyle(
                      fontSize: MomCozyTypography.secondarySize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.selected)
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
    required this.selected,
    required this.onTap,
  });

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
          borderRadius: BorderRadius.circular(MomCozyRadii.card),
          child: AnimatedContainer(
            duration: MomCozyMotion.duration(
              context,
              const Duration(milliseconds: 160),
            ),
            constraints: const BoxConstraints(minHeight: 112),
            padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
            decoration: BoxDecoration(
              color: MomCozyColors.raised,
              borderRadius: BorderRadius.circular(MomCozyRadii.card),
              border: Border.all(
                color: selected
                    ? MomCozyColors.primaryDark
                    : MomCozyColors.border,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 82,
                  height: 96,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(MomCozyRadii.control),
                    child: ColoredBox(
                      color: MomCozyColors.roseSoft,
                      child: Image.asset(
                        _referenceAvatarAsset,
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
                          fontSize: MomCozyTypography.titleSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: MomCozySpacing.xs),
                      Text(
                        'Continue with the MomCozy postpartum companion',
                        style: TextStyle(
                          color: MomCozyColors.mutedForeground,
                          fontSize: MomCozyTypography.secondarySize,
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
        color: MomCozyColors.primaryDark,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: EdgeInsets.all(MomCozySpacing.xs),
        child: Icon(Icons.check_rounded, color: MomCozyColors.raised, size: 16),
      ),
    );
  }
}

const _referenceAvatarAsset =
    'assets/images/me_baby_overview/postpartum_avatar.png';

class _GeneratedAvatar extends StatefulWidget {
  const _GeneratedAvatar({
    required this.fileId,
    required this.loadThumbnail,
    required this.onReadyChanged,
  });

  final String fileId;
  final OnboardingAvatarImageLoader loadThumbnail;
  final ValueChanged<bool> onReadyChanged;

  @override
  State<_GeneratedAvatar> createState() => _GeneratedAvatarState();
}

class _GeneratedAvatarState extends State<_GeneratedAvatar> {
  Future<Uint8List>? _load;
  int _loadEpoch = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load ??= _startLoad();
  }

  @override
  void didUpdateWidget(covariant _GeneratedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileId != widget.fileId ||
        oldWidget.loadThumbnail != widget.loadThumbnail) {
      _load = _startLoad();
    }
  }

  Future<Uint8List> _startLoad() {
    final epoch = ++_loadEpoch;
    late final Future<Uint8List> load;
    try {
      load = widget.loadThumbnail(widget.fileId);
    } catch (error, stackTrace) {
      load = Future<Uint8List>.error(error, stackTrace);
    }
    load.then<void>(
      (_) {
        if (mounted && epoch == _loadEpoch) widget.onReadyChanged(true);
      },
      onError: (Object _) {
        if (mounted && epoch == _loadEpoch) widget.onReadyChanged(false);
      },
    );
    return load;
  }

  void _retry() {
    widget.onReadyChanged(false);
    final load = _startLoad();
    setState(() {
      _load = load;
    });
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
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image_outlined, size: 32),
                TextButton(
                  key: ValueKey(
                    'onboarding-avatar-image-retry-${widget.fileId}',
                  ),
                  onPressed: _retry,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
