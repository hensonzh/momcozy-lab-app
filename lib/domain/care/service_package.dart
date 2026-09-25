import 'dart:convert';

import 'package:crypto/crypto.dart';

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

  /// Fallback copy is not a sufficient description of paid entitlements.
  /// Old catalog data remains readable, but purchase waits for English details.
  bool get hasEnglishPurchaseDetails =>
      [name, subtitle, description].every(
        (value) =>
            value.trim().isNotEmpty && !_unsupportedCareScript.hasMatch(value),
      ) &&
      [highlights, expertServices, continuousServices].every(
        (values) =>
            values.isNotEmpty &&
            values.every(
              (value) =>
                  value.trim().isNotEmpty &&
                  !_unsupportedCareScript.hasMatch(value),
            ),
      );

  // Historic API catalogs can still contain untranslated text. Only the
  // visible labels change; prices, included counts, and source data do not.
  String get publicName => englishCarePackageName(name, id: id);
  String get publicSubtitle => _englishProviderText(
    subtitle,
    nonEnglishFallback: 'Expert feeding support for your family.',
  );
  String get publicDescription => _englishProviderText(
    description,
    nonEnglishFallback:
        'This plan includes $sessions consultations over $durationDays days. Contact support to confirm the specific services before purchase.',
  );
  List<String> get publicHighlights => _englishPackageList(
    highlights,
    'Contact support to confirm the plan highlights.',
  );
  List<String> get publicExpertServices => _englishPackageList(
    expertServices,
    'This plan includes $sessions consultations. Contact support to confirm the format and length.',
  );
  List<String> get publicContinuousServices => _englishPackageList(
    continuousServices,
    'Contact support to confirm the included ongoing support.',
  );
}

String englishCarePackageName(String name, {required String id}) =>
    _unsupportedCareScript.hasMatch(name) || name.trim().isEmpty
    ? (_englishPackageNames[id] ?? 'Care plan · ${_displayCode(id)}')
    : name.replaceAll(_retiredProviderBrand, 'Momcozy AI');

const _englishPackageNames = <String, String>{
  'feeding-confidence': 'Feeding Confidence',
  'better-breastfeeding': 'Better Breastfeeding',
  'milk-supply-care': 'Milk Supply Care',
  'comfortable-feeding': 'Comfortable Feeding',
};

String _displayCode(String id) =>
    sha256.convert(utf8.encode(id)).toString().substring(0, 6).toUpperCase();

List<String> _englishPackageList(List<String> values, String fallback) {
  if (values.isEmpty) return const [];
  if (values.any(_unsupportedCareScript.hasMatch)) return [fallback];
  return values
      .map((value) => value.replaceAll(_retiredProviderBrand, 'Momcozy AI'))
      .toList();
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

  // Provider profiles from earlier catalogs may have no reviewed English copy.
  // Keep the source fields intact for reconciliation and professional review.
  String get publicName => englishCareExpertName(displayName, providerId: id);
  String get publicBio => bio.isEmpty
      ? ''
      : _englishProviderText(
          bio,
          nonEnglishFallback:
              'IBCLC support for feeding and lactation questions.',
        );

  String get languageLabel => languages.map(_englishLanguageName).join(' · ');
}

String _englishLanguageName(String raw) {
  final normalized = raw.trim();
  final lower = normalized.toLowerCase();
  const names = <String, String>{
    '\u4e2d\u6587': 'Chinese',
    '\u666e\u901a\u8bdd': 'Mandarin Chinese',
    '\u82f1\u8bed': 'English',
    'français': 'French',
    'español': 'Spanish',
    'deutsch': 'German',
    'português': 'Portuguese',
    'italiano': 'Italian',
    '\u65e5\u672c\u8a9e': 'Japanese',
    '\ud55c\uad6d\uc5b4': 'Korean',
  };
  final named = names[lower];
  if (named != null) return named;
  if (_retiredProviderBrand.hasMatch(normalized)) return 'Additional language';
  const codes = <String, String>{
    'en': 'English',
    'zh': 'Chinese',
    'fr': 'French',
    'es': 'Spanish',
    'de': 'German',
    'pt': 'Portuguese',
    'it': 'Italian',
    'ja': 'Japanese',
    'ko': 'Korean',
  };
  if (RegExp(r'^[a-z]{2,3}([_-][a-z]{2})?$').hasMatch(lower)) {
    return codes[lower.split(RegExp(r'[-_]')).first] ?? 'Additional language';
  }
  return _unsupportedCareScript.hasMatch(normalized) ||
          RegExp(r'[^\x00-\x7f]').hasMatch(normalized)
      ? 'Additional language'
      : normalized;
}

String englishCareExpertName(String name, {required String providerId}) {
  if (!_unsupportedCareScript.hasMatch(name) && name.trim().isNotEmpty) {
    return name.replaceAll(_retiredProviderBrand, 'Momcozy AI');
  }
  // Stable, non-reversible display code keeps multiple legacy consultants
  // distinguishable until their English public names have been reviewed.
  final code = sha256
      .convert(utf8.encode(providerId))
      .toString()
      .substring(0, 6)
      .toUpperCase();
  return 'IBCLC consultant · $code';
}

final _unsupportedCareScript = RegExp(
  r'[\u3400-\u9fff\u{20000}-\u{323af}\u3040-\u30ff\u31f0-\u31ff\uac00-\ud7af\u0400-\u052f\u0600-\u06ff\u0900-\u097f]',
  unicode: true,
);
final _retiredProviderBrand = RegExp(r'cozy[\s-]*mate', caseSensitive: false);

String _englishProviderText(String text, {required String nonEnglishFallback}) {
  if (_unsupportedCareScript.hasMatch(text)) return nonEnglishFallback;
  return text.replaceAll(_retiredProviderBrand, 'Momcozy AI');
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
