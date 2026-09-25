import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/appointment.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/mom_appointment_widgets.dart';
import 'package:momcozy_flutter_app/modules/services/presentation/mom_service_widgets.dart';

void main() {
  const legacy = CareProvider(
    id: 'legacy-provider',
    displayName: '王顾问',
    timezone: 'America/Los_Angeles',
    regions: ['CA'],
    languages: ['中文', 'English'],
    bio: 'Cozymate 泌乳咨询服务',
    sandbox: false,
  );
  test(
    'legacy expert profile displays English without modifying the stored identity',
    () {
      expect(legacy.publicName, startsWith('IBCLC consultant · '));
      expect(
        legacy.publicBio,
        'IBCLC support for feeding and lactation questions.',
      );
      expect(legacy.displayName, '王顾问');
      expect(legacy.bio, 'Cozymate 泌乳咨询服务');
      expect(legacy.languageLabel, 'Chinese · English');
    },
  );

  test(
    'English expert profile keeps its individual copy while updating retired branding',
    () {
      const provider = CareProvider(
        id: 'consultant',
        displayName: 'CozyMate Team',
        timezone: 'UTC',
        regions: ['CA'],
        languages: ['English'],
        bio: 'Cozymate helps with feeding.',
        sandbox: false,
      );
      expect(provider.publicName, 'Momcozy AI Team');
      expect(provider.publicBio, 'Momcozy AI helps with feeding.');
      expect(provider.displayName, 'CozyMate Team');
    },
  );

  test(
    'untranslated consultant identities remain distinct and stable across pages',
    () {
      const other = CareProvider(
        id: 'another-provider',
        displayName: '李顾问',
        timezone: 'UTC',
        regions: ['CA'],
        languages: ['English'],
        bio: '',
        sandbox: false,
      );
      expect(legacy.publicName, isNot(other.publicName));
      expect(
        legacy.publicName,
        englishCareExpertName('王顾问', providerId: legacy.id),
      );
      expect(
        legacy.publicName,
        matches(RegExp(r'^IBCLC consultant · [A-F0-9]{6}$')),
      );
    },
  );

  test('non-Latin legacy consultant profile uses a stable English label', () {
    const provider = CareProvider(
      id: 'consultant-korean',
      displayName: '김 상담사',
      timezone: 'UTC',
      regions: ['CA'],
      languages: ['한국어'],
      bio: '모유 수유 상담',
      sandbox: false,
    );
    expect(provider.publicName, startsWith('IBCLC consultant · '));
    expect(
      provider.publicBio,
      'IBCLC support for feeding and lactation questions.',
    );
    expect(provider.languageLabel, 'Korean');
    expect(provider.displayName, '김 상담사');
    expect(provider.bio, '모유 수유 상담');
  });

  testWidgets(
    'legacy booked consultant name stays English in appointment summary',
    (tester) async {
      final appointment = CareAppointment(
        id: 'appointment-1',
        episodeId: 'episode-1',
        providerId: legacy.id,
        providerName: 'CozyMate 王老师',
        startsAt: DateTime.utc(2026, 9, 24, 18),
        endsAt: DateTime.utc(2026, 9, 24, 19),
        timezone: 'America/Los_Angeles',
        region: 'CA',
        status: AppointmentStatus.confirmed,
        holdExpiresAt: DateTime.utc(2026, 9, 24, 18),
        version: 1,
        intakeVersion: 0,
      );
      expect(appointment.publicProviderName, startsWith('IBCLC consultant · '));
      expect(appointment.providerName, 'CozyMate 王老师');
      expect(appointment.publicProviderName, legacy.publicName);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MomAppointmentSummary(appointment: appointment)),
        ),
      );
      expect(find.text(appointment.publicProviderName), findsOneWidget);
      expect(find.textContaining('CozyMate'), findsNothing);
      expect(find.textContaining('王老师'), findsNothing);
    },
  );

  testWidgets(
    'expert team dialog shows only the English-facing legacy profile',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MomProviderTeamCard(providers: const [legacy])),
        ),
      );
      await tester.tap(find.text('Meet the team'));
      await tester.pumpAndSettle();
      expect(find.text('王顾问'), findsNothing);
      expect(find.textContaining('Cozymate'), findsNothing);
      expect(find.text(legacy.publicName), findsOneWidget);
      expect(
        find.text('IBCLC support for feeding and lactation questions.'),
        findsOneWidget,
      );
    },
  );
}
