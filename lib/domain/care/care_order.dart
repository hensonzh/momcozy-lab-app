import 'care_episode.dart';
import 'service_package.dart';

enum CareOrderStatus {
  pending,
  processing,
  requiresAction,
  reconciling,
  paid,
  failed,
  cancelled,
}

final class StripeCheckout {
  const StripeCheckout({required this.url, required this.purchase});
  final Uri url;
  final Purchase purchase;
}

enum SandboxPaymentOutcome {
  succeeded,
  declined,
  requiresAction,
  reconciling,
  cancelled,
}

final class CareOrder {
  const CareOrder({
    required this.id,
    required this.packageId,
    required this.status,
    required this.priceMinor,
    required this.currency,
    required this.durationDays,
    required this.totalSessions,
    required this.paymentMode,
    required this.region,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id, packageId, currency, region;
  final CareOrderStatus status;
  final int priceMinor, durationDays, totalSessions, version;
  final PaymentMode paymentMode;
  final DateTime createdAt, updatedAt;
  String get priceLabel => formatServicePrice(priceMinor, currency);
  bool get canResume =>
      ![CareOrderStatus.paid, CareOrderStatus.cancelled].contains(status);
}

final class Purchase {
  const Purchase({required this.order, this.episode});
  final CareOrder order;
  final CareEpisode? episode;
}

final class CareOverview {
  const CareOverview({required this.orders, required this.episodes});
  final List<CareOrder> orders;
  final List<CareEpisode> episodes;
}

final class ServiceEligibility {
  const ServiceEligibility({
    required this.id,
    required this.packageId,
    required this.region,
    required this.eligible,
    required this.expiresAt,
    required this.reason,
  });
  final String id, packageId, region, reason;
  final bool eligible;
  final DateTime expiresAt;
}

abstract interface class CareRepository {
  Future<ServiceCatalog> catalog();
  Future<CareOverview> overview();
  Future<ServiceEligibility> checkEligibility({
    required String packageId,
    required String region,
  });
  Future<Purchase> createOrder({
    required String eligibilityId,
    required String idempotencyKey,
  });
  Future<Purchase> purchase(String orderId);
  Future<Purchase> sandboxPayment(
    String orderId, {
    required int expectedVersion,
    required SandboxPaymentOutcome outcome,
  });
}

abstract interface class StripeCheckoutRepository {
  Future<StripeCheckout> stripeCheckout(String orderId);
}
