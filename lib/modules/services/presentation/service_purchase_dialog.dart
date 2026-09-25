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
  if (!package.hasEnglishPurchaseDetails) return null;
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
        setState(
          () => _launchError =
              'Could not open the payment page. Try again or check your order status.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _launchError =
              'Could not open the payment page. Try again or check your order status.',
        );
      }
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
        eligibility ? 'Current plan' : 'Purchase plan',
        style: MomHomeTokens.text(11, color: MomHomeTokens.secondary),
      ),
      Text(
        '${widget.package.publicName} package',
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
      'Current state',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
    DropdownButtonFormField<String>(
      isExpanded: true,
      itemHeight: null,
      initialValue: c.region,
      hint: const Text('Select your current state'),
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
        'This service is not available in your state yet',
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
        'I confirm my state is correct and understand that this is not an emergency medical service.',
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
      child: Text(_busy ? 'Confirming…' : 'Confirm and continue'),
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
                    'Card',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Text(
                'For testing only. Card details are not sent.',
                style: TextStyle(fontSize: 10, color: MomHomeTokens.secondary),
              ),
            ],
          ),
          const Divider(height: 1),
          _field(
            'Test card number',
            _number,
            (v) => v?.replaceAll(RegExp(r'\D'), '').length == 16
                ? null
                : 'Enter a 16-digit test card number',
          ),
          LayoutBuilder(
            builder: (context, box) {
              final fields = [
                _field(
                  'Expiration date',
                  _expiry,
                  (v) => RegExp(r'^(0[1-9]|1[0-2])/\d{2}$').hasMatch(v ?? '')
                      ? null
                      : 'Use MM/YY format',
                ),
                _field(
                  'Security code',
                  _cvc,
                  (v) => RegExp(r'^\d{3,4}$').hasMatch(v ?? '')
                      ? null
                      : 'Enter 3–4 digits',
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
            'Billing ZIP code',
            _postal,
            (v) => (v ?? '').trim().length >= 3 ? null : 'Enter a ZIP code',
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
              ? 'Stripe Checkout · Securely complete payment with Stripe'
              : 'Test mode · Simulated payment with no real charge',
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
        _notice(
          'Purchase complete',
          'Your service package is now in your account. You can book now or later.',
        ),
        _button(
          'Book an appointment',
          () => Navigator.pop(context, purchase.episode),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Book later'),
        ),
      ] else if (status == CareOrderStatus.cancelled) ...[
        _notice(
          'Payment canceled',
          'No service benefits were added.',
          color: MomHomeTokens.secondary,
          surface: MomHomeTokens.neutralSurface,
          icon: Icons.info_outline,
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to plan'),
        ),
      ] else if (reconciling) ...[
        _notice(
          'Confirming payment',
          status == CareOrderStatus.paid
              ? 'Payment confirmed. We are updating your service benefits. Please check again shortly.'
              : 'Check this order before trying to pay again to avoid a duplicate charge.',
          color: MomCozyColors.amber,
          surface: MomCozyColors.amberSoft,
          icon: Icons.schedule,
        ),
        _button('Check status', () => _act(c.refreshPurchase)),
        if (!stripe && status != CareOrderStatus.paid)
          TextButton(
            onPressed: _busy
                ? null
                : () => _act(() => c.pay(SandboxPaymentOutcome.succeeded)),
            child: const Text('Complete simulated payment'),
          ),
      ] else if (stripe) ...[
        if (status == CareOrderStatus.failed)
          _notice(
            'Payment not completed',
            'You can reopen the payment page or check your order status first.',
            color: MomCozyColors.danger,
            surface: MomCozyColors.recordValidationSurface,
            icon: Icons.info_outline,
          ),
        const Text(
          'Make a one-time payment through Stripe Checkout.',
          style: TextStyle(fontSize: 12, height: 1.5),
        ),
        _button(_busy ? 'Preparing…' : 'Open Stripe Checkout', _openCheckout),
        TextButton(
          onPressed: _busy ? null : () => _act(c.refreshPurchase),
          child: const Text('I have paid · Check status'),
        ),
      ] else if (status == CareOrderStatus.requiresAction) ...[
        _notice(
          'Your bank needs to verify this payment',
          'This test simulates 3D Secure verification. Payment will be confirmed after verification.',
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
                child: const Text('Cancel payment'),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _act(() => c.pay(SandboxPaymentOutcome.succeeded)),
                style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
                child: Text(_busy ? 'Processing…' : 'Confirm verification'),
              ),
            ],
          ),
        ),
      ] else ...[
        if (status == CareOrderStatus.failed && c.failure == null)
          _notice(
            'Payment not completed',
            'The test card was declined. No service benefits were added. Try another test card.',
            color: MomCozyColors.danger,
            surface: MomCozyColors.recordValidationSurface,
            icon: Icons.schedule,
          ),
        _button(
          _busy
              ? 'Processing…'
              : c.uncertainPayment
              ? 'Try payment again'
              : 'Pay ${purchase.order.priceLabel}',
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
          child: const Text('Cancel payment'),
        ),
      ],
      if (!paid && status != CareOrderStatus.cancelled)
        Text(
          stripe
              ? 'By submitting, you agree to purchase this package. Stripe processes your payment.'
              : 'Local test only. No real charge will be made.',
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
            title: c.purchase == null
                ? 'Before you purchase'
                : 'Secure payment',
            closeLabel: 'Close purchase',
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
                  'Could not confirm your order',
                  switch (failure.kind) {
                    ProductFailureKind.unauthenticated =>
                      'Your session has expired. Sign in again to continue.',
                    ProductFailureKind.forbidden =>
                      'This account cannot access this order.',
                    ProductFailureKind.conflict =>
                      'The order status has changed. Check the latest status before continuing.',
                    ProductFailureKind.invalid =>
                      'Check your information and try again.',
                    _ =>
                      'Check your connection and try again. Your existing order will remain.',
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
                    child: Text(
                      c.purchase == null ? 'Try again' : 'Check status',
                    ),
                  ),
                ),
              if (_launchError != null)
                _notice(
                  'Payment page did not open',
                  _launchError!,
                  color: MomCozyColors.amber,
                  surface: MomCozyColors.amberSoft,
                  icon: Icons.open_in_new,
                ),
              if (c.uncertainPayment)
                const Text(
                  'Payment has not been confirmed. Your order is still available. Check its status or try paying again.',
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
