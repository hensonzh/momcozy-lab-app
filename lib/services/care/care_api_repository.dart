import '../../core/network/api_json_transport.dart';
import '../../domain/care/care_order.dart';
import '../../domain/care/service_package.dart';
import '../shared/product_failure_mapper.dart';
import 'care_codec.dart';

class CareApiRepository implements CareRepository, StripeCheckoutRepository {
  const CareApiRepository({required this.transport});
  final ApiJsonTransport transport;
  @override
  Future<ServiceCatalog> catalog() => withProductFailure(
    () async => readServiceCatalog(await transport.getJson('/v1/care/catalog')),
  );
  @override
  Future<CareOverview> overview() => withProductFailure(
    () async => readCareOverview(await transport.getJson('/v1/care/overview')),
  );
  @override
  Future<ServiceEligibility> checkEligibility({
    required String packageId,
    required String region,
  }) => withProductFailure(
    () async => readEligibility(
      await transport.postJson(
        '/v1/care/eligibility',
        body: {
          'package_id': packageId,
          'region': region,
          'acknowledges_non_emergency': true,
        },
      ),
    ),
  );
  @override
  Future<Purchase> createOrder({
    required String eligibilityId,
    required String idempotencyKey,
  }) => withProductFailure(
    () async => readPurchase(
      await transport.postJson(
        '/v1/care/orders',
        body: {'eligibility_id': eligibilityId},
        headers: {'Idempotency-Key': idempotencyKey},
      ),
    ),
  );
  @override
  Future<Purchase> purchase(String orderId) => withProductFailure(
    () async => readPurchase(
      await transport.getJson(
        '/v1/care/orders/${Uri.encodeComponent(orderId)}',
      ),
    ),
  );
  @override
  Future<StripeCheckout> stripeCheckout(String orderId) => withProductFailure(() async {
    final json = await transport.postJson('/v1/care/orders/${Uri.encodeComponent(orderId)}/checkout');
    final url = Uri.tryParse(json['checkout_url'] as String? ?? '');
    if (url == null || !url.isAbsolute || url.scheme != 'https') {
      throw StateError('Stripe returned an invalid Checkout URL');
    }
    return StripeCheckout(url: url, purchase: readPurchase((json['purchase'] as Map).cast<String, Object?>()));
  });
  @override
  Future<Purchase> sandboxPayment(
    String orderId, {
    required int expectedVersion,
    required SandboxPaymentOutcome outcome,
  }) => withProductFailure(
    () async => readPurchase(
      await transport.postJson(
        '/v1/care/orders/${Uri.encodeComponent(orderId)}/sandbox-payment',
        body: {
          'expected_version': expectedVersion,
          'outcome': paymentOutcomeWire.write(outcome),
        },
      ),
    ),
  );
}
