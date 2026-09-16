import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../core/routing/external_url_launcher.dart';
import '../../../domain/care/care_episode.dart';
import '../../../domain/care/care_order.dart';
import '../../../domain/care/service_package.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/widgets/momcozy_line_icon.dart';
import '../application/service_purchase_controller.dart';

Future<CareEpisode?> showServicePurchase(
  BuildContext context, {
  required CareRepository repository,
  required ServicePackage package,
  required ServiceCatalog catalog,
  Purchase? purchase,
}) async {
  final controller = ServicePurchaseController(
    repository: repository,
    packageId: package.id,
    purchase: purchase,
  );
  try {
    return await showDialog<CareEpisode>(
      context: context,
      animationStyle: MomCozyMotion.animationStyle(context),
      barrierDismissible: false,
      builder: (context) => ServicePurchaseDialog(
        controller: controller,
        package: package,
        catalog: catalog,
      ),
    );
  } finally {
    controller.dispose();
  }
}

class ServicePurchaseDialog extends StatefulWidget {
  const ServicePurchaseDialog({
    super.key,
    required this.controller,
    required this.package,
    required this.catalog,
    this.urlLauncher = const PlatformExternalUrlLauncher(),
  });
  final ServicePurchaseController controller;
  final ServicePackage package;
  final ServiceCatalog catalog;
  final ExternalUrlLauncher urlLauncher;
  @override
  State<ServicePurchaseDialog> createState() => _ServicePurchaseDialogState();
}

class _ServicePurchaseDialogState extends State<ServicePurchaseDialog> {
  final _number = TextEditingController(text: '4242 4242 4242 4242');
  final _expiry = TextEditingController(text: '12/34');
  final _cvc = TextEditingController(text: '123');
  final _postal = TextEditingController(text: '94107');
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  bool _openingCheckout = false, _submittedCard = false;
  String? _launchError;
  ServicePurchaseController get c => widget.controller;
  bool get _busy => c.busy || _openingCheckout;

  @override
  void dispose() {
    _number.dispose();
    _expiry.dispose();
    _cvc.dispose();
    _postal.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _act(Future<void> Function() action, {bool top = false}) async {
    if (_busy) return;
    if (_launchError != null) setState(() => _launchError = null);
    FocusScope.of(context).unfocus();
    await action();
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && _scroll.hasClients) {
      await MomCozyMotion.scrollTo(
        context,
        _scroll,
        top || c.purchase?.order.status == CareOrderStatus.paid
            ? 0
            : _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _openCheckout() async {
    if (_busy) return;
    setState(() {
      _openingCheckout = true;
      _launchError = null;
    });
    try {
      await c.startStripeCheckout();
      if (!mounted) return;
      final url = c.checkoutUrl;
      if (url != null && !await widget.urlLauncher.open(url) && mounted) {
        setState(() => _launchError = '暂时无法打开支付页面，请重试或查询订单结果。');
      }
    } catch (_) {
      if (mounted) setState(() => _launchError = '暂时无法打开支付页面，请重试或查询订单结果。');
    } finally {
      if (mounted) setState(() => _openingCheckout = false);
    }
  }

  Widget _stack(List<Widget> children, {double gap = 14}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(height: gap),
        children[i],
      ],
    ],
  );

  Widget _notice(
    String title,
    String body, {
    Color color = MomHomeTokens.teal,
    Color surface = MomHomeTokens.mint,
    IconData icon = Icons.check_circle_outline,
    Widget? action,
  }) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: _stack([
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: MomHomeTokens.text(
                  14,
                  weight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        if (body.isNotEmpty)
          Text(body, style: MomHomeTokens.text(13, height: 1.55, color: color)),
        ?action,
      ]),
    ),
  );

  Widget _button(String label, VoidCallback action) =>
      FilledButton(onPressed: _busy ? null : action, child: Text(label));

  Widget _summary({bool eligibility = false}) => MomSettingsCard(
    gradient: MomHomeTokens.milk,
    children: [
      Text(
        eligibility ? '当前方案' : '购买方案',
        style: MomHomeTokens.text(11, color: MomHomeTokens.secondary),
      ),
      Text(
        '${widget.package.name}服务包',
        style: MomHomeTokens.text(18, weight: FontWeight.w700),
      ),
      Text(
        c.purchase?.order.priceLabel ?? widget.package.priceLabel,
        style: MomHomeTokens.text(
          22,
          weight: FontWeight.w700,
          color: MomHomeTokens.rose,
        ),
      ),
    ],
  );

  List<Widget> _eligibility() => [
    _summary(eligibility: true),
    const Text(
      '当前所在州',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
    DropdownButtonFormField<String>(
      isExpanded: true,
      itemHeight: null,
      initialValue: c.region,
      hint: const Text('请选择当前所在州'),
      style: MomHomeTokens.text(13),
      items: {'CA', 'NY', 'TX', ...widget.catalog.availableRegions}
          .map(
            (value) => DropdownMenuItem(
              value: value,
              child: Text(switch (value) {
                'CA' => 'California (CA)',
                'NY' => 'New York (NY)',
                'TX' => 'Texas (TX)',
                _ => value,
              }),
            ),
          )
          .toList(),
      onChanged: _busy ? null : c.setRegion,
    ),
    if (c.region != null && !widget.catalog.availableRegions.contains(c.region))
      _notice(
        '当前服务暂未覆盖该州',
        '',
        color: MomCozyColors.amber,
        surface: MomCozyColors.amberSoft,
        icon: Icons.shield_outlined,
      ),
    CheckboxListTile(
      value: c.acknowledged,
      onChanged: _busy ? null : (v) => c.acknowledge(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: const Text(
        '我确认所在州正确，并了解这不是紧急医疗服务。',
        style: TextStyle(fontSize: 12, height: 1.5),
      ),
    ),
    FilledButton(
      onPressed:
          !_busy &&
              c.canConfirm &&
              widget.catalog.availableRegions.contains(c.region)
          ? () => _act(c.confirmEligibility, top: true)
          : null,
      child: Text(_busy ? '正在确认…' : '确认并继续'),
    ),
  ];
  Widget _field(
    String label,
    TextEditingController controller,
    String? Function(String?) validator, {
    bool obscure = false,
  }) => Semantics(
    label: label,
    child: _stack([
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: MomHomeTokens.secondary,
        ),
      ),
      TextFormField(
        controller: controller,
        obscureText: obscure,
        readOnly:
            _busy ||
            c.uncertainPayment ||
            c.purchase?.order.status == CareOrderStatus.requiresAction,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 13),
        validator: validator,
        decoration: const InputDecoration(errorMaxLines: 3),
      ),
    ], gap: 6),
  );

  Widget _cardForm({required bool disabled}) => AbsorbPointer(
    absorbing: disabled,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MomHomeTokens.surface,
        border: Border.all(color: MomHomeTokens.border),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Form(
        key: _form,
        child: _stack([
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MomCozyLineIcon(
                    MomCozyLineGlyph.lock,
                    size: 20,
                    color: MomHomeTokens.teal,
                  ),
                  SizedBox(width: 7),
                  Text(
                    '银行卡',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Text(
                '仅模拟验证，不发送卡信息',
                style: TextStyle(fontSize: 10, color: MomHomeTokens.secondary),
              ),
            ],
          ),
          const Divider(height: 1),
          _field(
            '测试卡号',
            _number,
            (v) => v?.replaceAll(RegExp(r'\D'), '').length == 16
                ? null
                : '请填写 16 位测试卡号',
          ),
          LayoutBuilder(
            builder: (context, box) {
              final fields = [
                _field(
                  '有效期',
                  _expiry,
                  (v) => RegExp(r'^(0[1-9]|1[0-2])/\d{2}$').hasMatch(v ?? '')
                      ? null
                      : '格式为 MM/YY',
                ),
                _field(
                  '安全码',
                  _cvc,
                  (v) => RegExp(r'^\d{3,4}$').hasMatch(v ?? '')
                      ? null
                      : '填写 3–4 位数字',
                  obscure: true,
                ),
              ];
              if (box.maxWidth < 260 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.4) {
                return _stack(fields, gap: 11);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: 9),
                  Expanded(child: fields[1]),
                ],
              );
            },
          ),
          _field(
            '账单邮编',
            _postal,
            (v) => (v ?? '').trim().length >= 3 ? null : '请填写邮编',
          ),
        ], gap: 11),
      ),
    ),
  );

  List<Widget> _payment() {
    final purchase = c.purchase!, status = purchase.order.status;
    final stripe = purchase.order.paymentMode == PaymentMode.stripe;
    final paid = status == CareOrderStatus.paid && purchase.episode != null;
    final reconciling =
        status == CareOrderStatus.reconciling ||
        status == CareOrderStatus.processing ||
        status == CareOrderStatus.paid && purchase.episode == null;
    final testFields =
        !stripe &&
        !paid &&
        status != CareOrderStatus.cancelled &&
        !reconciling &&
        (status != CareOrderStatus.requiresAction || _submittedCard);
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: MomHomeTokens.mint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          stripe
              ? 'Stripe Checkout · 安全跳转到 Stripe 完成付款'
              : '测试模式 · 模拟支付，不会产生真实扣款',
          style: const TextStyle(
            fontSize: 11,
            height: 1.5,
            color: MomHomeTokens.teal,
          ),
        ),
      ),
      _summary(),
      if (testFields)
        _cardForm(
          disabled:
              _busy ||
              c.uncertainPayment ||
              status == CareOrderStatus.requiresAction,
        ),
      if (paid) ...[
        _notice('购买成功', '服务包已加入你的账户，可以现在或稍后开始预约。'),
        _button('开始预约', () => Navigator.pop(context, purchase.episode)),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('稍后预约'),
        ),
      ] else if (status == CareOrderStatus.cancelled) ...[
        _notice(
          '付款已取消',
          '没有创建服务权益。',
          color: MomHomeTokens.secondary,
          surface: MomHomeTokens.neutralSurface,
          icon: Icons.info_outline,
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('返回方案'),
        ),
      ] else if (reconciling) ...[
        _notice(
          '正在确认付款结果',
          status == CareOrderStatus.paid
              ? '付款已确认，正在同步服务权益，请稍后查询。'
              : '请先查询这笔订单，避免重复付款。',
          color: MomCozyColors.amber,
          surface: MomCozyColors.amberSoft,
          icon: Icons.schedule,
        ),
        _button('查询结果', () => _act(c.refreshPurchase)),
        if (!stripe && status != CareOrderStatus.paid)
          TextButton(
            onPressed: _busy
                ? null
                : () => _act(() => c.pay(SandboxPaymentOutcome.succeeded)),
            child: const Text('完成模拟付款'),
          ),
      ] else if (stripe) ...[
        if (status == CareOrderStatus.failed)
          _notice(
            '付款未完成',
            '可以重新打开支付页面，或先查询订单结果。',
            color: MomCozyColors.danger,
            surface: MomCozyColors.recordValidationSurface,
            icon: Icons.info_outline,
          ),
        const Text(
          '使用 Stripe Checkout 完成一次性付款。',
          style: TextStyle(fontSize: 12, height: 1.5),
        ),
        _button(_busy ? '正在准备…' : '打开 Stripe Checkout', _openCheckout),
        TextButton(
          onPressed: _busy ? null : () => _act(c.refreshPurchase),
          child: const Text('我已完成付款，查询结果'),
        ),
      ] else if (status == CareOrderStatus.requiresAction) ...[
        _notice(
          '银行需要验证此付款',
          '模拟 3D Secure 验证。完成验证后才会确认这笔付款。',
          color: MomCozyColors.violet,
          surface: MomCozyColors.violetSoft,
          icon: Icons.shield_outlined,
          action: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 6,
            children: [
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _act(() => c.pay(SandboxPaymentOutcome.cancelled)),
                child: const Text('取消付款'),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _act(() => c.pay(SandboxPaymentOutcome.succeeded)),
                style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
                child: Text(_busy ? '正在处理…' : '确认验证'),
              ),
            ],
          ),
        ),
      ] else ...[
        if (status == CareOrderStatus.failed && c.failure == null)
          _notice(
            '付款未完成',
            '测试卡被拒绝，没有创建服务权益。可以更换测试卡后重试。',
            color: MomCozyColors.danger,
            surface: MomCozyColors.recordValidationSurface,
            icon: Icons.schedule,
          ),
        _button(
          _busy
              ? '正在处理…'
              : c.uncertainPayment
              ? '重试这笔付款'
              : '支付 ${purchase.order.priceLabel}',
          () {
            if (_form.currentState?.validate() == true) {
              _submittedCard = true;
              _act(() => c.submitTestCard(_number.text));
            }
          },
        ),
        TextButton(
          onPressed: _busy || c.uncertainPayment
              ? null
              : () => _act(() => c.pay(SandboxPaymentOutcome.cancelled)),
          child: const Text('取消付款'),
        ),
      ],
      if (!paid && status != CareOrderStatus.cancelled)
        Text(
          stripe ? '提交即表示你同意购买该服务包。付款由 Stripe 处理。' : '仅用于本地测试，不会产生真实扣款。',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            height: 1.5,
            color: MomHomeTokens.secondary,
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final fields = c.purchase == null ? _eligibility() : _payment();
        return PopScope(
          canPop: !_busy,
          child: MomSettingsFlowDialog(
            title: c.purchase == null ? '购买前确认' : '安全支付',
            closeLabel: '关闭购买',
            onClose: _busy ? null : () => Navigator.pop(context),
            maxHeight: c.purchase == null ? 560 : 720,
            scrollController: _scroll,
            child: _stack([
              ...fields,
              if (c.validationMessage case final message?)
                _notice(
                  message,
                  '',
                  color: MomCozyColors.danger,
                  surface: MomCozyColors.recordValidationSurface,
                  icon: Icons.info_outline,
                ),
              if (c.failure case final failure?)
                _notice(
                  '暂时无法确认订单',
                  switch (failure.kind) {
                    ProductFailureKind.unauthenticated => '登录已过期，请重新登录后继续。',
                    ProductFailureKind.forbidden => '当前账号无法操作这笔订单。',
                    ProductFailureKind.conflict => '订单状态已更新，请查询最新结果后继续。',
                    ProductFailureKind.invalid => '请核对填写的信息后重试。',
                    _ => '请检查网络后重试。已有订单会继续保留。',
                  },
                  color: MomCozyColors.amber,
                  surface: MomCozyColors.amberSoft,
                  icon: Icons.info_outline,
                  action: TextButton(
                    onPressed: _busy
                        ? null
                        : () => _act(
                            c.purchase == null
                                ? c.confirmEligibility
                                : c.refreshPurchase,
                          ),
                    child: Text(c.purchase == null ? '重试' : '查询结果'),
                  ),
                ),
              if (_launchError != null)
                _notice(
                  '未打开支付页面',
                  _launchError!,
                  color: MomCozyColors.amber,
                  surface: MomCozyColors.amberSoft,
                  icon: Icons.open_in_new,
                ),
              if (c.uncertainPayment)
                const Text(
                  '付款结果未确认，订单仍然保留。请查询结果或重试这笔付款。',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: MomHomeTokens.secondary,
                  ),
                ),
            ]),
          ),
        );
      },
    ),
  );
}
