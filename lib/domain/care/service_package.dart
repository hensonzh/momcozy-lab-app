final class ServicePackage {
  const ServicePackage({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.durationDays,
    required this.sessions,
    required this.priceMinor,
    required this.currency,
    required this.highlights,
    required this.expertServices,
    required this.continuousServices,
  });
  final String id, name, subtitle, description, currency;
  final int durationDays, sessions, priceMinor;
  final List<String> highlights, expertServices, continuousServices;
  String get priceLabel => formatServicePrice(priceMinor, currency);
}

String formatServicePrice(int minor, String currency) {
  final whole = minor % 100 == 0
      ? '${minor ~/ 100}'
      : (minor / 100).toStringAsFixed(2);
  return currency == 'USD' ? '\$$whole' : '$currency $whole';
}

final class CareProvider {
  const CareProvider({
    required this.id,
    required this.displayName,
    required this.timezone,
    required this.regions,
    required this.languages,
    required this.bio,
    required this.sandbox,
  });
  final String id, displayName, timezone, bio;
  final List<String> regions, languages;
  final bool sandbox;
}

enum PaymentMode { sandbox, stripe, disabled }

final class ServiceCatalog {
  const ServiceCatalog({
    required this.packages,
    required this.providers,
    required this.availableRegions,
    required this.paymentMode,
  });
  final List<ServicePackage> packages;
  final List<CareProvider> providers;
  final List<String> availableRegions;
  final PaymentMode paymentMode;
}
