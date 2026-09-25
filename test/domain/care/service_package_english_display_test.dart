import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';

void main() {
  const legacy = ServicePackage(
    id: 'feeding-confidence',
    name: '喂养信心计划',
    subtitle: 'Cozymate 喂养支持',
    description: '了解宝宝的喂养需求。',
    durationDays: 7,
    sessions: 2,
    priceMinor: 21900,
    currency: 'USD',
    highlights: ['查看宝宝是否吃饱'],
    expertServices: ['首次视频咨询 60 分钟', '后续咨询 20 分钟'],
    continuousServices: ['记录喂养', '跟踪进展'],
  );

  test('known legacy package uses English without inventing entitlements', () {
    expect(legacy.publicName, 'Feeding Confidence');
    expect(legacy.publicSubtitle, 'Expert feeding support for your family.');
    expect(
      legacy.publicDescription,
      'This plan includes 2 consultations over 7 days. Contact support to confirm the specific services before purchase.',
    );
    expect(legacy.publicExpertServices, [
      'This plan includes 2 consultations. Contact support to confirm the format and length.',
    ]);
    expect(legacy.publicContinuousServices, [
      'Contact support to confirm the included ongoing support.',
    ]);
    expect(legacy.name, '喂养信心计划');
    expect(legacy.expertServices.first, '首次视频咨询 60 分钟');
    expect(legacy.durationDays, 7);
    expect(legacy.sessions, 2);
    expect(legacy.priceMinor, 21900);
    expect(legacy.hasEnglishPurchaseDetails, isFalse);
  });

  test('English package keeps current details and updates retired brand', () {
    const current = ServicePackage(
      id: 'custom',
      name: 'Cozymate Care',
      subtitle: 'Support for feeding',
      description: 'Cozy Mate helps with feeding.',
      durationDays: 7,
      sessions: 1,
      priceMinor: 5000,
      currency: 'USD',
      highlights: ['Cozymate support'],
      expertServices: ['Video consultation'],
      continuousServices: ['Daily tracking'],
    );
    expect(current.publicName, 'Momcozy AI Care');
    expect(current.publicSubtitle, 'Support for feeding');
    expect(current.publicDescription, 'Momcozy AI helps with feeding.');
    expect(current.publicExpertServices, ['Video consultation']);
    expect(current.publicContinuousServices, ['Daily tracking']);
    expect(current.hasEnglishPurchaseDetails, isTrue);
  });

  test(
    'unreviewed package avoids fabricated benefits or untranslated copy',
    () {
      const other = ServicePackage(
        id: 'legacy-unreviewed',
        name: '特殊计划',
        subtitle: '特殊支持',
        description: '特别说明',
        durationDays: 4,
        sessions: 1,
        priceMinor: 9999,
        currency: 'USD',
        highlights: ['特别权益'],
        expertServices: ['特殊咨询'],
        continuousServices: ['持续支持'],
      );
      expect(other.publicName, startsWith('Care plan · '));
      expect(other.publicSubtitle, contains('support'));
      expect(other.publicDescription, contains('support'));
      expect(other.publicExpertServices.single, contains('confirm'));
      expect(other.publicContinuousServices.single, contains('confirm'));
      expect(other.name, '特殊计划');
      expect(other.hasEnglishPurchaseDetails, isFalse);
    },
  );
}
