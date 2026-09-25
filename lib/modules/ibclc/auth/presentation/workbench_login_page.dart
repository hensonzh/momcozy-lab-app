import '../../../../shared/widgets/momcozy_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../domain/shared/product_failure.dart';
import '../../../../shared/design_system/momcozy_design_system.dart';
import '../application/workbench_auth_controller.dart';

class WorkbenchLoginPage extends StatefulWidget {
  const WorkbenchLoginPage({super.key, required this.controller});
  final WorkbenchAuthController controller;
  @override
  State<WorkbenchLoginPage> createState() => _WorkbenchLoginPageState();
}

class _WorkbenchLoginPageState extends State<WorkbenchLoginPage> {
  final email = TextEditingController(),
      password = TextEditingController(),
      code = TextEditingController();
  bool obscure = true;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = widget.controller;
    FocusScope.of(context).unfocus();
    if (auth.challenge == null) {
      await auth.begin(email.text, password.text);
      if (mounted && auth.challenge != null) password.clear();
    } else {
      await auth.verify(code.text);
      if (mounted) code.clear();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final auth = widget.controller;
      final mfa = auth.challenge != null;
      return Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth < 500 ? 20 : 48,
                vertical: 32,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 64).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(
                          constraints.maxWidth < 500 ? 22 : 36,
                        ),
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: const MomCozyWordmark(width: 124),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'IBCLC Workbench',
                                style: TextStyle(
                                  color: MomCozyColors.mutedForeground,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                auth.identityPending
                                    ? 'Confirming your work identity'
                                    : mfa
                                    ? 'Verify your identity'
                                    : 'Access your workbench',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                auth.identityPending
                                    ? 'Once your work credentials are verified, you can access your workspace.'
                                    : mfa
                                    ? 'Enter the 6-digit code currently shown in your authenticator app.'
                                    : 'Sign in with your work email to complete two-step verification.',
                                style: const TextStyle(
                                  color: MomCozyColors.mutedForeground,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (auth.restoring)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: CircularProgressIndicator(
                                      semanticsLabel: 'Restoring sign-in',
                                    ),
                                  ),
                                )
                              else if (auth.identityPending) ...[
                                if (!auth.busy)
                                  FilledButton(
                                    onPressed: auth.restore,
                                    child: const Text('Verify work identity again'),
                                  ),
                                TextButton(
                                  onPressed: auth.busy ? null : auth.logout,
                                  child: const Text('Use another account'),
                                ),
                              ] else if (!mfa) ...[
                                TextField(
                                  controller: email,
                                  enabled: !auth.busy,
                                  decoration: const InputDecoration(
                                    labelText: 'Work email',
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.username],
                                  autocorrect: false,
                                  textInputAction: TextInputAction.next,
                                ),
                                const SizedBox(height: 18),
                                TextField(
                                  controller: password,
                                  enabled: !auth.busy,
                                  obscureText: obscure,
                                  autofillHints: const [AutofillHints.password],
                                  enableSuggestions: false,
                                  autocorrect: false,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    suffixIcon: IconButton(
                                      tooltip: obscure ? 'Show password' : 'Hide password',
                                      onPressed: () =>
                                          setState(() => obscure = !obscure),
                                      icon: Icon(
                                        obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  onSubmitted: (_) => _submit(),
                                ),
                              ] else ...[
                                Text(
                                  email.text.trim(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                TextField(
                                  controller: code,
                                  enabled: !auth.busy,
                                  autofocus: true,
                                  keyboardType: TextInputType.number,
                                  autofillHints: const [
                                    AutofillHints.oneTimeCode,
                                  ],
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Authenticator code',
                                  ),
                                  onSubmitted: (_) => _submit(),
                                ),
                              ],
                              if (auth.validation != null ||
                                  auth.failure != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 18),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      auth.validation ??
                                          _failureMessage(auth.failure!, mfa),
                                      style: const TextStyle(
                                        color: MomCozyColors.danger,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              if (!auth.restoring && !auth.identityPending) ...[
                                const SizedBox(height: 24),
                                FilledButton(
                                  onPressed: auth.busy ? null : _submit,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    child: Text(
                                      auth.busy
                                          ? 'Verifying…'
                                          : mfa
                                          ? 'Enter workbench'
                                          : 'Continue',
                                    ),
                                  ),
                                ),
                                if (mfa)
                                  TextButton(
                                    onPressed: auth.busy
                                        ? null
                                        : () {
                                            code.clear();
                                            auth.restart();
                                          },
                                    child: const Text('Back to email sign-in'),
                                  ),
                              ],
                              const SizedBox(height: 24),
                              const Row(
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    size: 17,
                                    color: MomCozyColors.care,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Work accounts require two-step verification',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: MomCozyColors.mutedForeground,
                                      ),
                                    ),
                                  ),
                                ],
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
          ),
        ),
      );
    },
  );
}

String _failureMessage(ProductFailure failure, bool mfa) =>
    switch (failure.code) {
      'mfa_invalid' => 'That code is incorrect or has already been used. Enter a new code from your authenticator app.',
      'mfa_locked' => 'Too many attempts. Sign in again in 10 minutes.',
      'mfa_challenge_expired' => 'This verification has expired. Enter your email and password again.',
      'mfa_not_configured' ||
      'workbench_not_enabled' => 'An authenticator has not been set up for this work account. Contact your account administrator.',
      'mfa_rate_limited' || 'rate_limit_exceeded' => 'Too many sign-in attempts. Try again later.',
      'auth_storage_failed' => 'Could not securely save your sign-in. Check your browser storage settings and try again.',
      _ => switch (failure.kind) {
        ProductFailureKind.offline => 'You are offline. Connect and try again.',
        ProductFailureKind.unauthenticated =>
          mfa ? 'Identity verification failed. Sign in again.' : 'Incorrect email or password, or your session has expired.',
        ProductFailureKind.forbidden => 'This account cannot access the workbench right now. Contact your account administrator.',
        ProductFailureKind.invalid => 'Check your entries and try again.',
        ProductFailureKind.conflict ||
        ProductFailureKind.unavailable => 'Could not sign in right now. Try again later.',
      },
    };
