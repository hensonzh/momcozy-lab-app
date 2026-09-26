import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/shared/product_failure.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/widgets/date_time_picker.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../auth/presentation/auth_login_chrome.dart';
import '../domain/onboarding.dart';
import 'onboarding_controller.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.controller,
    this.entryPath = '/',
    this.now = DateTime.now,
  });

  final OnboardingController controller;
  final String entryPath;
  final DateTime Function() now;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _deliveryCountController = TextEditingController();
  final _profileScroll = ScrollController();
  int _profileStep = 0;
  final OnboardingProfileDraft _draft = OnboardingProfileDraft();
  String _validationMessage = '';

  @override
  void dispose() {
    _profileScroll.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _deliveryCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = authLoginTheme(Theme.of(context));
    return Theme(
      data: theme,
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
                OnboardingGatePhase.failure => Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ProductErrorView(
                      failure: const ProductFailure(
                        ProductFailureKind.unavailable,
                      ),
                      onRetry: () => widget.controller.load(),
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
    if (state.profileConfirmed) return const ProductLoadingView();
    return _buildProfileFlow(context);
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

  Widget _buildProfileFlow(BuildContext context) => Theme(
    data: authLoginTheme(Theme.of(context)),
    child: Column(
      children: [
        _SetupProgressHeader(
          step: _profileStep + 1,
          onBack: _profileStep == 0 || widget.controller.busy
              ? null
              : () => _goToProfileStep(_profileStep - 1),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _profileScroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: switch (_profileStep) {
              0 => _basicsStep(),
              1 => _postpartumDeliveryStep(context),
              2 => _postpartumBirthStep(),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
      ],
    ),
  );

  Widget _basicsStep() {
    return _ProfileStep(
      title: 'A few basics first',
      reason:
          'Your name personalizes the app, and your age helps us tailor guidance safely.',
      children: [
        _ProfileField(
          label: 'Name',
          child: TextField(
            key: const ValueKey('onboarding-display-name'),
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'What should we call you?',
            ),
          ),
        ),
        _ProfileField(
          label: 'Age',
          child: TextField(
            key: const ValueKey('onboarding-age'),
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'e.g. 32'),
          ),
        ),
        _ProfileField(
          label: 'Including this birth, how many times have you given birth?',
          child: TextField(
            key: const ValueKey('onboarding-delivery-count'),
            controller: _deliveryCountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'e.g. 1'),
          ),
        ),
        if (_validationMessage.isNotEmpty ||
            widget.controller.errorMessage.isNotEmpty)
          _errorText(),
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
        () => _validationMessage = 'Enter the name you\'d like us to use.',
      );
      return;
    }
    if (age == null || age < 12 || age > 70) {
      setState(() => _validationMessage = 'Enter an age between 12 and 70.');
      return;
    }
    final deliveryCount = int.tryParse(_deliveryCountController.text.trim());
    if (deliveryCount == null || deliveryCount < 1 || deliveryCount > 20) {
      setState(
        () => _validationMessage =
            'Enter how many times you have given birth (1–20).',
      );
      return;
    }
    _draft
      ..displayName = _nameController.text.trim()
      ..age = age
      ..setDeliveryCount(deliveryCount);
    _goToProfileStep(1);
  }

  Widget _postpartumDeliveryStep(BuildContext context) {
    final draft = _draft;
    return _ProfileStep(
      title: 'Tell us about your delivery',
      reason:
          'Your delivery date helps personalize postpartum recovery and your baby\'s age-based guidance.',
      children: [
        _DateField(
          label: 'Delivery date',
          value: draft.deliveryDate,
          onTap: () async {
            final today = DateUtils.dateOnly(widget.now());
            final selected = await showMomCozyDatePicker(
              context: context,
              theme: authLoginTheme(Theme.of(context)),
              initialDate: draft.deliveryDate ?? today,
              currentDate: today,
              firstDate: DateTime(today.year - 2),
              lastDate: today,
            );
            if (selected != null) setState(() => draft.deliveryDate = selected);
          },
        ),
        if (_validationMessage.isNotEmpty ||
            widget.controller.errorMessage.isNotEmpty)
          _errorText(),
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
    return _ProfileStep(
      title: 'How was your delivery?',
      reason:
          'Delivery method and baby count help personalize recovery and create the right baby profiles.',
      children: [
        _ProfileField(
          label: 'Delivery method (optional)',
          child: DropdownButtonFormField<String?>(
            initialValue: draft.deliveryType,
            style: MomHomeTokens.text(14),
            isExpanded: true,
            isDense: MediaQuery.textScalerOf(context).scale(14) <= 14 * 1.4,
            itemHeight: null,
            decoration: const InputDecoration(),
            items: const [
              DropdownMenuItem(
                value: null,
                child: Text('Prefer not to say yet'),
              ),
              DropdownMenuItem(value: 'vaginal', child: Text('Vaginal birth')),
              DropdownMenuItem(
                value: 'cesarean',
                child: Text('Cesarean birth'),
              ),
              DropdownMenuItem(
                value: 'assisted',
                child: Text('Assisted birth'),
              ),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (value) => draft.deliveryType = value,
          ),
        ),
        _CountField(
          label: 'How many babies did you welcome?',
          value: draft.infantCount,
          onChanged: (value) => setState(() => draft.setInfantCount(value)),
        ),
        if (draft.deliveryCount != null && draft.deliveryCount! > 1)
          _ProfileField(
            label: 'Before this delivery, had you ever had a cesarean birth?',
            child: DropdownButtonFormField<bool?>(
              key: const ValueKey('onboarding-previous-cesarean'),
              initialValue: draft.hasCesareanHistory,
              isExpanded: true,
              style: MomHomeTokens.text(14),
              decoration: const InputDecoration(),
              items: const [
                DropdownMenuItem<bool?>(
                  value: null,
                  child: Text('Not sure yet'),
                ),
                DropdownMenuItem<bool?>(value: true, child: Text('Yes')),
                DropdownMenuItem<bool?>(value: false, child: Text('No')),
              ],
              onChanged: (value) =>
                  setState(() => draft.hasCesareanHistory = value),
            ),
          ),
        if (_validationMessage.isNotEmpty ||
            widget.controller.errorMessage.isNotEmpty)
          _errorText(),
        MomCozyPrimaryButton(
          key: const ValueKey('onboarding-postpartum-save'),
          loading: widget.controller.busy,
          onPressed: widget.controller.busy ? null : _submitProfile,
          child: const Text('Save and start'),
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
    context.go(widget.entryPath);
  }

  Widget _errorText() {
    final message = widget.controller.errorMessage.isNotEmpty
        ? widget.controller.errorMessage
        : _validationMessage;
    return message.isEmpty
        ? const SizedBox.shrink()
        : AuthNotice(message, error: true);
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ExcludeSemantics(
        child: Text(
          label,
          style: MomHomeTokens.text(12, weight: FontWeight.w700),
        ),
      ),
      const SizedBox(height: 8),
      Semantics(label: label, child: child),
    ],
  );
}

class _ProfileStep extends StatelessWidget {
  const _ProfileStep({
    required this.title,
    required this.reason,
    required this.children,
  });
  final String title, reason;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MomSettingsCard(
        gradient: MomHomeTokens.plan,
        children: [
          Text(title, style: MomHomeTokens.text(24, weight: FontWeight.w700)),
          Text(
            reason,
            style: MomHomeTokens.text(
              13,
              color: MomHomeTokens.secondary,
              height: 1.55,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      MomSettingsCard(children: children),
    ],
  );
}

class _SetupProgressHeader extends StatelessWidget {
  const _SetupProgressHeader({required this.step, this.onBack});
  final int step;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Column(
      children: [
        Row(
          children: [
            SizedBox.square(
              dimension: 44,
              child: onBack == null
                  ? null
                  : IconButton(
                      tooltip: 'Back',
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    ),
            ),
            Expanded(
              child: Text(
                'Your setup',
                style: MomHomeTokens.text(
                  12,
                  weight: FontWeight.w700,
                  color: MomHomeTokens.secondary,
                ),
              ),
            ),
            Text(
              '$step/3',
              style: MomHomeTokens.text(
                12,
                weight: FontWeight.w700,
                color: MomHomeTokens.rose,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: step / 3,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
          backgroundColor: MomHomeTokens.mint,
          semanticsLabel: 'Setup step $step of 3',
        ),
      ],
    ),
  );
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
    return _ProfileField(
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: InputDecorator(
          decoration: const InputDecoration(),
          child: Row(
            children: [
              Expanded(child: Text(display)),
              const Icon(Icons.calendar_today_outlined, size: 20),
            ],
          ),
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
    return _ProfileField(
      label: label,
      child: DropdownButtonFormField<int>(
        initialValue: value,
        style: MomHomeTokens.text(14),
        decoration: const InputDecoration(),
        items: [
          for (var count = 1; count <= 6; count++)
            DropdownMenuItem(value: count, child: Text('$count')),
        ],
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }
}
