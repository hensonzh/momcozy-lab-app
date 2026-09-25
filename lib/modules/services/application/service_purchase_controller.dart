import 'package:flutter/foundation.dart';
import '../../../domain/care/care_order.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/mutation_key.dart';

class ServicePurchaseController extends ChangeNotifier {
  ServicePurchaseController({
    required this.repository,
    required this.packageId,
    this.purchase,
    DateTime Function()? now,
    String Function()? mutationKey,
  }) : now = now ?? DateTime.now,
       mutationKey = mutationKey ?? newMutationKey;
  final CareRepository repository;
  final String packageId;
  final DateTime Function() now;
  final String Function() mutationKey;
  Purchase? purchase;
  String? region;
  bool acknowledged = false;
  ServiceEligibility? eligibility;
  bool busy = false;
  ProductFailure? failure;
  String? validationMessage;
  Uri? checkoutUrl;
  String? _createKey;
  SandboxPaymentOutcome? _pendingOutcome;
  bool _disposed = false;
  bool get uncertainPayment => _pendingOutcome != null && !busy;
  bool get canConfirm => region != null && acknowledged && !busy;

  void setRegion(String? value) {
    if (busy) return;
    region = value;
    validationMessage = null;
    eligibility = null;
    _createKey = null;
    failure = null;
    notifyListeners();
  }

  void acknowledge(bool value) {
    if (busy) return;
    acknowledged = value;
    notifyListeners();
  }

  Future<void> confirmEligibility() async {
    if (!canConfirm) return;
    busy = true;
    failure = null;
    validationMessage = null;
    notifyListeners();
    try {
      if (eligibility == null || !eligibility!.expiresAt.isAfter(now())) {
        final result = await repository.checkEligibility(
          packageId: packageId,
          region: region!,
        );
        if (_disposed) return;
        eligibility = result;
        _createKey = mutationKey();
      }
      if (!eligibility!.eligible) {
        validationMessage = 'This service is not available in your state yet.';
      } else {
        final result = await repository.createOrder(
          eligibilityId: eligibility!.id,
          idempotencyKey: _createKey!,
        );
        if (_disposed) return;
        purchase = result;
      }
    } catch (error) {
      if (_disposed) return;
      failure = _failure(error);
    }
    busy = false;
    notifyListeners();
  }

  Future<void> startStripeCheckout() async {
    final current = purchase;
    if (busy || current == null) return;
    busy = true;
    failure = null;
    checkoutUrl = null;
    notifyListeners();
    try {
      if (repository is! StripeCheckoutRepository) {
        throw UnsupportedError('Stripe Checkout is not configured');
      }
      final result = await (repository as StripeCheckoutRepository)
          .stripeCheckout(current.order.id);
      if (_disposed) return;
      purchase = result.purchase;
      checkoutUrl = result.url;
    } catch (error) {
      if (_disposed) return;
      failure = _failure(error);
    }
    busy = false;
    notifyListeners();
  }

  Future<void> submitTestCard(String number) async {
    if (busy) return;
    final digits = number.replaceAll(RegExp(r'\D'), '');
    final outcome = switch (digits) {
      '4242424242424242' => SandboxPaymentOutcome.succeeded,
      '4000000000009995' => SandboxPaymentOutcome.declined,
      '4000002500003155' => SandboxPaymentOutcome.requiresAction,
      _ => null,
    };
    if (outcome == null) {
      validationMessage = 'Enter the test card number: 4242 4242 4242 4242';
      notifyListeners();
      return;
    }
    await pay(outcome);
  }

  Future<void> pay(SandboxPaymentOutcome outcome) async {
    final current = purchase;
    if (busy || current == null) return;
    busy = true;
    failure = null;
    validationMessage = null;
    notifyListeners();
    final submitted = _pendingOutcome ?? outcome;
    try {
      final result = await repository.sandboxPayment(
        current.order.id,
        expectedVersion: current.order.version,
        outcome: submitted,
      );
      if (_disposed) return;
      purchase = result;
      _pendingOutcome = null;
    } catch (error) {
      if (_disposed) return;
      failure = _failure(error);
      _pendingOutcome =
          [
            ProductFailureKind.offline,
            ProductFailureKind.unavailable,
          ].contains(failure!.kind)
          ? submitted
          : null;
    }
    busy = false;
    notifyListeners();
  }

  Future<void> refreshPurchase() async {
    final current = purchase;
    if (busy || current == null) return;
    busy = true;
    failure = null;
    notifyListeners();
    try {
      final result = await repository.purchase(current.order.id);
      if (_disposed) return;
      purchase = result;
      _pendingOutcome = null;
    } catch (error) {
      if (_disposed) return;
      failure = _failure(error);
    }
    busy = false;
    notifyListeners();
  }

  ProductFailure _failure(Object value) => value is ProductFailure
      ? value
      : const ProductFailure(ProductFailureKind.unavailable);
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
