import 'package:flutter/material.dart';
import '../../../core/routing/external_url_launcher.dart';
import '../../../domain/care/care_episode.dart';
import '../../../domain/care/care_order.dart';
import '../../../domain/care/service_package.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
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
  });
  final ServicePurchaseController controller;
  final ServicePackage package;
  final ServiceCatalog catalog;
  @override
  State<ServicePurchaseDialog> createState() => _ServicePurchaseDialogState();
}

class _ServicePurchaseDialogState extends State<ServicePurchaseDialog> {
  final _number = TextEditingController(text: '4242 4242 4242 4242');
  final _expiry = TextEditingController(text: '12/34');
  final _cvc = TextEditingController(text: '123');
  final _postal = TextEditingController(text: '94107');
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _number.dispose();
    _expiry.dispose();
    _cvc.dispose();
    _postal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final purchase = controller.purchase;
      final status = purchase?.order.status;
      final paid = status == CareOrderStatus.paid && purchase?.episode != null;
      return PopScope(
        canPop: !controller.busy,
        child: Dialog(
          insetPadding: const EdgeInsets.all(MomCozySpacing.page),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MomCozyLayout.maxAppWidth,
              maxHeight: MediaQuery.sizeOf(context).height * .88,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(MomCozySpacing.section),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          purchase == null ? '购买前确认' : '安全支付',
                          style: const TextStyle(
                            fontSize: MomCozyTypography.headingSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭购买',
                        onPressed: controller.busy
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: MomCozySpacing.content),
                  Text(
                    '${widget.package.name}服务包 · ${purchase?.order.priceLabel ?? widget.package.priceLabel}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: MomCozySpacing.card),
                  if (purchase == null) ...[
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      itemHeight: null,
                      initialValue: controller.region,
                      decoration: const InputDecoration(labelText: '当前所在州'),
                      items:
                          {'CA', 'NY', 'TX', ...widget.catalog.availableRegions}
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
                      onChanged: controller.busy ? null : controller.setRegion,
                    ),
                    if (controller.region != null &&
                        !widget.catalog.availableRegions.contains(
                          controller.region,
                        ))
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          '当前服务暂未覆盖该州',
                          style: TextStyle(color: MomCozyColors.danger),
                        ),
                      ),
                    CheckboxListTile(
                      value: controller.acknowledged,
                      onChanged: controller.busy
                          ? null
                          : (value) => controller.acknowledge(value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '我确认所在州正确，并了解这不是紧急医疗服务。',
                        style: TextStyle(
                          fontSize: MomCozyTypography.secondarySize,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed:
                          controller.canConfirm &&
                              widget.catalog.availableRegions.contains(
                                controller.region,
                              )
                          ? controller.confirmEligibility
                          : null,
                      child: Text(controller.busy ? '正在确认…' : '确认并继续'),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(MomCozySpacing.content),
                      decoration: BoxDecoration(
                        color: MomCozyColors.careSoft,
                        borderRadius: BorderRadius.circular(
                          MomCozyRadii.control,
                        ),
                      ),
                      child: Text(
                        widget.catalog.paymentMode == PaymentMode.stripe
                            ? 'Stripe Checkout · 安全跳转到 Stripe 完成付款'
                            : '测试模式 · 模拟支付，不会产生真实扣款',
                        style: TextStyle(
                          fontSize: MomCozyTypography.captionSize,
                          color: MomCozyColors.care,
                        ),
                      ),
                    ),
                    const SizedBox(height: MomCozySpacing.page),
                    if (paid) ...[
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 48,
                        color: MomCozyColors.care,
                      ),
                      const SizedBox(height: MomCozySpacing.content),
                      const Text(
                        '购买成功',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: MomCozyTypography.headingSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: MomCozySpacing.statusGap),
                      const Text('服务包已加入你的账户，可以现在或稍后开始预约。'),
                      const SizedBox(height: MomCozySpacing.card),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(context, purchase.episode),
                        child: const Text('开始预约'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('稍后预约'),
                      ),
                    ] else if (widget.catalog.paymentMode ==
                        PaymentMode.stripe) ...[
                      const Text(
                        '使用 Stripe Checkout 完成一次性付款。',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: MomCozySpacing.page),
                      FilledButton(
                        onPressed: controller.busy
                            ? null
                            : () async {
                                await controller.startStripeCheckout();
                                final url = controller.checkoutUrl;
                                if (url != null && context.mounted) {
                                  await const PlatformExternalUrlLauncher()
                                      .open(url);
                                }
                              },
                        child: Text(
                          controller.busy ? '正在准备…' : '打开 Stripe Checkout',
                        ),
                      ),
                      if (status == CareOrderStatus.processing)
                        TextButton(
                          onPressed: controller.busy
                              ? null
                              : controller.refreshPurchase,
                          child: const Text('我已完成付款，查询结果'),
                        ),
                    ] else if (status == CareOrderStatus.cancelled) ...[
                      const Text('本次付款已取消，没有创建服务权益。'),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('返回方案'),
                      ),
                    ] else if (status == CareOrderStatus.requiresAction) ...[
                      const Text(
                        '完成测试支付验证',
                        style: TextStyle(
                          fontSize: MomCozyTypography.sectionSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: MomCozySpacing.content),
                      const Text('确认后将继续这笔模拟付款。'),
                      const SizedBox(height: MomCozySpacing.page),
                      FilledButton(
                        onPressed: controller.busy
                            ? null
                            : () => controller.pay(
                                SandboxPaymentOutcome.succeeded,
                              ),
                        child: Text(controller.busy ? '正在处理…' : '确认验证'),
                      ),
                      TextButton(
                        onPressed: controller.busy
                            ? null
                            : () => controller.pay(
                                SandboxPaymentOutcome.cancelled,
                              ),
                        child: const Text('取消付款'),
                      ),
                    ] else if (status == CareOrderStatus.reconciling ||
                        status == CareOrderStatus.processing) ...[
                      const Text(
                        '正在确认付款结果',
                        style: TextStyle(
                          fontSize: MomCozyTypography.sectionSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: MomCozySpacing.statusGap),
                      const Text('请先查询这笔订单，避免重复付款。'),
                      const SizedBox(height: MomCozySpacing.page),
                      FilledButton(
                        onPressed: controller.busy
                            ? null
                            : controller.refreshPurchase,
                        child: const Text('查询结果'),
                      ),
                      TextButton(
                        onPressed: controller.busy
                            ? null
                            : () => controller.pay(
                                SandboxPaymentOutcome.succeeded,
                              ),
                        child: const Text('完成模拟付款'),
                      ),
                    ] else ...[
                      if (status == CareOrderStatus.failed)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                            '付款未完成，没有创建服务权益。可以更换测试卡后重试。',
                            style: TextStyle(color: MomCozyColors.danger),
                          ),
                        ),
                      AbsorbPointer(
                        absorbing:
                            controller.busy || controller.uncertainPayment,
                        child: Form(
                          key: _form,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _number,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '测试卡号',
                                ),
                                validator: (value) =>
                                    value
                                            ?.replaceAll(RegExp(r'\D'), '')
                                            .length ==
                                        16
                                    ? null
                                    : '请填写 16 位测试卡号',
                              ),
                              const SizedBox(height: MomCozySpacing.headingGap),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _expiry,
                                      keyboardType: TextInputType.datetime,
                                      decoration: const InputDecoration(
                                        labelText: '有效期',
                                      ),
                                      validator: (value) =>
                                          RegExp(
                                            r'^(0[1-9]|1[0-2])/\d{2}$',
                                          ).hasMatch(value ?? '')
                                          ? null
                                          : '格式为 MM/YY',
                                    ),
                                  ),
                                  const SizedBox(width: MomCozySpacing.content),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _cvc,
                                      keyboardType: TextInputType.number,
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                        labelText: '安全码',
                                      ),
                                      validator: (value) =>
                                          RegExp(
                                            r'^\d{3,4}$',
                                          ).hasMatch(value ?? '')
                                          ? null
                                          : '填写 3–4 位数字',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: MomCozySpacing.headingGap),
                              TextFormField(
                                controller: _postal,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '账单邮编',
                                ),
                                validator: (value) =>
                                    (value ?? '').trim().length >= 3
                                    ? null
                                    : '请填写邮编',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: MomCozySpacing.card),
                      FilledButton(
                        onPressed: controller.busy
                            ? null
                            : () {
                                if (_form.currentState!.validate()) {
                                  controller.submitTestCard(_number.text);
                                }
                              },
                        child: Text(
                          controller.busy
                              ? '正在处理…'
                              : controller.uncertainPayment
                              ? '重试这笔付款'
                              : '支付 ${purchase.order.priceLabel}',
                        ),
                      ),
                      TextButton(
                        onPressed:
                            controller.busy || controller.uncertainPayment
                            ? null
                            : () => controller.pay(
                                SandboxPaymentOutcome.cancelled,
                              ),
                        child: const Text('取消付款'),
                      ),
                    ],
                  ],
                  if (controller.validationMessage case final message?)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        message,
                        style: const TextStyle(color: MomCozyColors.danger),
                      ),
                    ),
                  if (controller.failure case final failure?)
                    ProductErrorView(
                      failure: failure,
                      onRetry: purchase != null
                          ? controller.refreshPurchase
                          : controller.confirmEligibility,
                    ),
                  if (controller.uncertainPayment)
                    const Text(
                      '付款结果未确认，订单仍然保留。请查询结果或重试这笔付款。',
                      style: TextStyle(
                        fontSize: MomCozyTypography.captionSize,
                        color: MomCozyColors.mutedForeground,
                      ),
                    ),
                  if (controller.failure?.kind == ProductFailureKind.conflict)
                    const Text('请核对最新订单状态后继续。'),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
