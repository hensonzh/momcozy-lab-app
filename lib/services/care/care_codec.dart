import '../../domain/care/care_episode.dart';
import '../../domain/care/care_order.dart';
import '../../domain/care/service_package.dart';
import '../shared/json_value.dart';

const episodeStatusWire = EnumWire<CareEpisodeStatus>({
  CareEpisodeStatus.provisioningPending: 'provisioning_pending',
  CareEpisodeStatus.active: 'active',
  CareEpisodeStatus.paused: 'paused',
  CareEpisodeStatus.completed: 'completed',
  CareEpisodeStatus.cancelled: 'cancelled',
});
const careStageWire = EnumWire<CareStage>({
  CareStage.preparation: 'preparation',
  CareStage.initialConsultation: 'initial_consultation',
  CareStage.activeCare: 'active_care',
  CareStage.followUp: 'follow_up',
  CareStage.conclusion: 'conclusion',
});
const orderStatusWire = EnumWire<CareOrderStatus>({
  CareOrderStatus.pending: 'pending',
  CareOrderStatus.processing: 'processing',
  CareOrderStatus.requiresAction: 'requires_action',
  CareOrderStatus.reconciling: 'reconciling',
  CareOrderStatus.paid: 'paid',
  CareOrderStatus.failed: 'failed',
  CareOrderStatus.cancelled: 'cancelled',
});
const paymentModeWire = EnumWire<PaymentMode>({
  PaymentMode.sandbox: 'sandbox',
  PaymentMode.disabled: 'disabled',
});
const paymentOutcomeWire = EnumWire<SandboxPaymentOutcome>({
  SandboxPaymentOutcome.succeeded: 'succeeded',
  SandboxPaymentOutcome.declined: 'declined',
  SandboxPaymentOutcome.requiresAction: 'requires_action',
  SandboxPaymentOutcome.reconciling: 'reconciling',
  SandboxPaymentOutcome.cancelled: 'cancelled',
});

ServicePackage readServicePackage(Map<String, Object?> json) => ServicePackage(
  id: jsonString(json['id']),
  name: jsonString(json['name']),
  subtitle: jsonString(json['subtitle']),
  description: jsonString(json['description']),
  durationDays: jsonInt(json['duration_days']),
  sessions: jsonInt(json['sessions']),
  priceMinor: jsonInt(json['price_minor']),
  currency: jsonString(json['currency']),
  highlights: jsonStrings(json['highlights']),
  expertServices: jsonStrings(json['expert_services']),
  continuousServices: jsonStrings(json['continuous_services']),
);

CareProvider readCareProvider(Map<String, Object?> json) => CareProvider(
  id: jsonString(json['user_id']),
  displayName: jsonString(json['display_name']),
  timezone: jsonString(json['timezone']),
  regions: jsonStrings(json['regions']),
  languages: jsonStrings(json['languages']),
  bio: jsonString(json['bio']),
  sandbox: jsonBool(json['sandbox']),
);

ServiceCatalog readServiceCatalog(Map<String, Object?> json) => ServiceCatalog(
  packages: jsonList(json['packages'], readServicePackage),
  providers: jsonList(json['providers'], readCareProvider),
  availableRegions: jsonStrings(json['available_regions']),
  paymentMode: paymentModeWire.read(json['payment_mode'])!,
);

CareEpisode readCareEpisode(Map<String, Object?> json) => CareEpisode(
  id: jsonString(json['id']),
  orderId: jsonString(json['order_id']),
  packageId: jsonString(json['package_id']),
  babyId: json['baby_id'] == null ? null : jsonString(json['baby_id']),
  assignedIbclcId: json['assigned_ibclc_id'] == null
      ? null
      : jsonString(json['assigned_ibclc_id']),
  status: episodeStatusWire.read(json['status'])!,
  stage: careStageWire.read(json['stage'])!,
  totalSessions: jsonInt(json['total_sessions']),
  remainingSessions: jsonInt(json['remaining_sessions']),
  startsAt: json['starts_at'] == null ? null : jsonInstant(json['starts_at']),
  endsAt: json['ends_at'] == null ? null : jsonInstant(json['ends_at']),
  version: jsonInt(json['version']),
);

CareOrder readCareOrder(Map<String, Object?> json) => CareOrder(
  id: jsonString(json['id']),
  packageId: jsonString(json['package_id']),
  status: orderStatusWire.read(json['status'])!,
  priceMinor: jsonInt(json['price_minor']),
  durationDays: jsonInt(json['duration_days']),
  totalSessions: jsonInt(json['total_sessions']),
  currency: jsonString(json['currency']),
  paymentMode: paymentModeWire.read(json['payment_mode'])!,
  region: jsonString(json['region']),
  version: jsonInt(json['version']),
  createdAt: jsonInstant(json['created_at']),
  updatedAt: jsonInstant(json['updated_at']),
);

Purchase readPurchase(Map<String, Object?> json) => Purchase(
  order: readCareOrder(jsonObject(json['order'])),
  episode: json['episode'] == null
      ? null
      : readCareEpisode(jsonObject(json['episode'])),
);
CareOverview readCareOverview(Map<String, Object?> json) => CareOverview(
  orders: jsonList(json['orders'], readCareOrder),
  episodes: jsonList(json['episodes'], readCareEpisode),
);
ServiceEligibility readEligibility(Map<String, Object?> json) =>
    ServiceEligibility(
      id: jsonString(json['id']),
      packageId: jsonString(json['package_id']),
      region: jsonString(json['region']),
      eligible: jsonBool(json['eligible']),
      reason: jsonString(json['reason']),
      expiresAt: jsonInstant(json['expires_at']),
    );
