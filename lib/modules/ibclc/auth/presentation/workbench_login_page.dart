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
                                'IBCLC 工作台',
                                style: TextStyle(
                                  color: MomCozyColors.mutedForeground,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                auth.identityPending
                                    ? '正在确认工作身份'
                                    : mfa
                                    ? '验证你的身份'
                                    : '进入病例环境',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                auth.identityPending
                                    ? '工作资料验证完成后，即可进入你的工作区。'
                                    : mfa
                                    ? '请输入认证器中当前显示的 6 位验证码。'
                                    : '使用工作邮箱登录，继续完成两步验证。',
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
                                      semanticsLabel: '正在恢复登录',
                                    ),
                                  ),
                                )
                              else if (auth.identityPending) ...[
                                if (!auth.busy)
                                  FilledButton(
                                    onPressed: auth.restore,
                                    child: const Text('重新确认工作身份'),
                                  ),
                                TextButton(
                                  onPressed: auth.busy ? null : auth.logout,
                                  child: const Text('使用其他账号'),
                                ),
                              ] else if (!mfa) ...[
                                TextField(
                                  controller: email,
                                  enabled: !auth.busy,
                                  decoration: const InputDecoration(
                                    labelText: '工作邮箱',
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
                                    labelText: '密码',
                                    suffixIcon: IconButton(
                                      tooltip: obscure ? '显示密码' : '隐藏密码',
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
                                    labelText: '认证器验证码',
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
                                          ? '正在验证…'
                                          : mfa
                                          ? '进入工作台'
                                          : '继续',
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
                                    child: const Text('返回邮箱登录'),
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
                                      '工作账号需要两步验证',
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
      'mfa_invalid' => '验证码不正确或已使用，请输入认证器中的新验证码。',
      'mfa_locked' => '验证次数过多，请 10 分钟后重新登录。',
      'mfa_challenge_expired' => '本次验证已过期，请重新输入邮箱和密码。',
      'mfa_not_configured' ||
      'workbench_not_enabled' => '工作账号尚未配置认证器，请联系账号管理员。',
      'mfa_rate_limited' || 'rate_limit_exceeded' => '登录尝试过于频繁，请稍后重试。',
      'auth_storage_failed' => '无法安全保存登录状态，请检查浏览器存储设置后重试。',
      _ => switch (failure.kind) {
        ProductFailureKind.offline => '网络未连接，请连接后重试。',
        ProductFailureKind.unauthenticated =>
          mfa ? '本次身份验证未通过，请重新登录。' : '邮箱或密码不正确，或登录已过期。',
        ProductFailureKind.forbidden => '该账号暂时无法进入工作台，请联系账号管理员。',
        ProductFailureKind.invalid => '请检查输入内容后重试。',
        ProductFailureKind.conflict ||
        ProductFailureKind.unavailable => '暂时无法完成登录，请稍后重试。',
      },
    };
