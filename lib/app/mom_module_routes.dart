import '../modules/consultation/presentation/home_consultation_dialog.dart';
import '../modules/profile/presentation/privacy_page.dart';
import '../features/notifications/presentation/notification_scope.dart';
import '../features/notifications/presentation/notification_settings_page.dart';
import '../modules/services/presentation/appointment_detail_page.dart';
import '../modules/services/presentation/appointment_cancel_dialog.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../domain/care/appointment.dart';
import '../domain/shared/local_date.dart';
import '../modules/mom/application/mother_home_controller.dart';
import '../modules/mom/presentation/lactation_page.dart';
import '../modules/mom/presentation/mother_diary_editor.dart';
import '../modules/mom/presentation/mother_diary_page.dart';
import '../modules/mom/presentation/mother_home_page.dart';
import '../modules/services/presentation/expert_support_section.dart';
import '../modules/services/presentation/service_catalog_page.dart';
import '../modules/services/presentation/service_package_page.dart';
import '../modules/services/presentation/service_progress_page.dart';
import '../modules/services/presentation/service_renew_page.dart';
import '../services/care/care_api_repository.dart';
import '../services/lactation/lactation_api_repository.dart';
import '../services/mother/mother_diary_api_repository.dart';
import '../services/mother/mother_profile_api_repository.dart';
import 'momcozy_api_runtime.dart';
import '../services/appointments/appointment_api_repository.dart';
import '../services/consultations/intake_api_repository.dart';
import '../modules/services/presentation/booking_page.dart';
import '../modules/services/presentation/intake_page.dart';
import '../modules/consultation/application/room_controller.dart';
import '../modules/consultation/presentation/room_page.dart';
import '../services/consultations/room_api_repository.dart';
import '../services/consultations/livekit_consultation_media.dart';
import '../services/documentation/documentation_api_repository.dart';
import '../modules/services/application/summary_controller.dart';
import '../modules/services/presentation/consultation_summary_page.dart';

Widget buildMotherHome(BuildContext context) {
  final runtime = MomCozyRuntimeScope.of(context);
  final care = CareApiRepository(transport: runtime.jsonTransport);
  return MotherHomePage(
    key: ValueKey(runtime),
    controller: MotherHomeController(
      profileRepository: MotherProfileApiRepository(
        transport: runtime.jsonTransport,
        ownerUserId: runtime.currentSession.userId,
        timezoneProvider: runtime.timezoneProvider,
      ),
      diaryRepository: MotherDiaryApiRepository(
        transport: runtime.jsonTransport,
      ),
      lactationRepository: LactationApiRepository(
        transport: runtime.jsonTransport,
      ),
      ownerUserId: runtime.currentSession.userId,
      now: runtime.now,
    ),
    observability: runtime.observability,
    onLactationDetails: () => context.push('/me/lactation'),
    onRecoveryDetails: () => context.push('/me/diary'),
    onAsk: (text) => context.go('/', extra: {'agentPrefill': text}),
    expertSupport: ExpertSupportSection(
      observability: runtime.observability,
      repository: care,
      appointmentRepository: AppointmentApiRepository(
        transport: runtime.jsonTransport,
      ),
      now: runtime.now,
      onAppointment: (appointment) =>
          _openHomeAppointment(context, runtime, appointment),
      onIntake: (appointment) =>
          context.push('/services/appointments/${appointment.id}/intake'),
      onJoin: (appointment) =>
          context.push('/services/appointments/${appointment.id}/room'),
      onCatalog: () => context.push('/services'),
      onProgress: (episode) => context.push('/services/episodes/${episode.id}'),
      onBook: (episode) =>
          context.push('/services/episodes/${episode.id}/booking'),
    ),
  );
}

Future<void> _openHomeAppointment(
  BuildContext context,
  MomCozyApiRuntime runtime,
  CareAppointment appointment,
) async {
  if (appointment.status != AppointmentStatus.confirmed) {
    await context.push('/services/appointments/${appointment.id}');
    return;
  }
  final destination = await showHomeConsultationDialog(
    context,
    createController: () => ConsultationRoomController(
      repository: ConsultationRoomApiRepository(
        transport: runtime.jsonTransport,
      ),
      consents: IntakeApiRepository(transport: runtime.jsonTransport),
      appointmentId: appointment.id,
      media: LiveKitConsultationMedia(),
      now: runtime.now,
    ),
    appointments: AppointmentApiRepository(transport: runtime.jsonTransport),
  );
  if (!context.mounted || destination == null) return;
  final route = switch (destination) {
    HomeConsultationDestination.intake =>
      '/services/appointments/${appointment.id}/intake',
    HomeConsultationDestination.rebook =>
      '/services/episodes/${appointment.episodeId}/booking',
    HomeConsultationDestination.summary =>
      '/services/appointments/${appointment.id}/summary',
  };
  await context.push(route);
}

void _back(BuildContext context) =>
    context.canPop() ? context.pop() : context.go('/me');

final momModuleRoutes = <GoRoute>[
  GoRoute(
    path: '/privacy',
    builder: (context, state) {
      final runtime = MomCozyRuntimeScope.of(context);
      return PrivacyPage(
        care: CareApiRepository(transport: runtime.jsonTransport),
        consents: IntakeApiRepository(transport: runtime.jsonTransport),
        initialEpisodeId: state.uri.queryParameters['episode'],
        onBack: () => _back(context),
        onNotifications: () => context.push('/notifications/settings'),
      );
    },
  ),
  GoRoute(
    path: '/notifications/settings',
    builder: (context, state) => NotificationSettingsPage(
      coordinator: NotificationScope.maybeOf(context),
    ),
  ),
  GoRoute(
    path: '/services/appointments/:appointmentId',
    builder: (context, state) {
      final runtime = MomCozyRuntimeScope.of(context);
      return AppointmentDetailPage(
        key: ValueKey(
          'appointment-${runtime.currentSession.userId}-${state.pathParameters['appointmentId']}',
        ),
        repository: AppointmentApiRepository(transport: runtime.jsonTransport),
        appointmentId: state.pathParameters['appointmentId']!,
      );
    },
  ),
  GoRoute(
    path: '/services/appointments/:appointmentId/summary',
    builder: (context, state) {
      final runtime = MomCozyRuntimeScope.of(context);
      final appointmentId = state.pathParameters['appointmentId']!;
      return ConsultationSummaryPage(
        key: ValueKey(
          'summary-${runtime.currentSession.userId}-$appointmentId',
        ),
        createController: () => CareSummaryController(
          repository: DocumentationApiRepository(
            transport: runtime.jsonTransport,
          ),
          appointmentId: appointmentId,
        ),
        onBack: () => _back(context),
        onProgress: (episode) =>
            context.push('/services/episodes/${episode.id}'),
        onPlan: () => context.push('/schedule'),
      );
    },
  ),
  GoRoute(
    path: '/services/appointments/:appointmentId/room',
    builder: (context, state) {
      final runtime = MomCozyRuntimeScope.of(context);
      final appointmentId = state.pathParameters['appointmentId']!;
      return ConsultationRoomPage(
        key: ValueKey('room-${runtime.currentSession.userId}-$appointmentId'),
        createController: () => ConsultationRoomController(
          repository: ConsultationRoomApiRepository(
            transport: runtime.jsonTransport,
          ),
          consents: IntakeApiRepository(transport: runtime.jsonTransport),
          appointmentId: appointmentId,
          media: LiveKitConsultationMedia(),
          now: runtime.now,
        ),
        onBack: () => _back(context),
        onIntake: () =>
            context.push('/services/appointments/$appointmentId/intake'),
        onHome: () => context.go('/me'),
        onProgress: (appointment) =>
            context.go('/services/appointments/${appointment.id}/summary'),
        onRebook: (appointment) =>
            context.go('/services/episodes/${appointment.episodeId}/booking'),
        onCancel: (appointment) async {
          final cancelled = await showAppointmentCancellation(
            context,
            repository: AppointmentApiRepository(
              transport: runtime.jsonTransport,
            ),
            appointment: appointment,
          );
          if (context.mounted && cancelled != null) context.go('/me');
        },
      );
    },
  ),
  GoRoute(
    path: '/services/episodes/:episodeId/booking',
    builder: (context, state) {
      final runtime = MomCozyRuntimeScope.of(context);
      return BookingPage(
        key: ValueKey(
          'booking-${runtime.currentSession.userId}-${state.pathParameters['episodeId']}',
        ),
        repository: AppointmentApiRepository(transport: runtime.jsonTransport),
        episodeId: state.pathParameters['episodeId']!,
        now: runtime.now,
        onBack: () => _back(context),
        onIntake: (appointment) =>
            context.push('/services/appointments/${appointment.id}/intake'),
        onConsultation: (appointment) =>
            context.push('/services/appointments/${appointment.id}/room'),
      );
    },
  ),
  GoRoute(
    path: '/services/appointments/:appointmentId/intake',
    builder: (context, state) {
      final runtime = MomCozyRuntimeScope.of(context);
      return IntakePage(
        key: ValueKey(
          'intake-${runtime.currentSession.userId}-${state.pathParameters['appointmentId']}',
        ),
        repository: IntakeApiRepository(transport: runtime.jsonTransport),
        appointmentId: state.pathParameters['appointmentId']!,
        now: runtime.now,
        onBack: () => _back(context),
        onManageBabies: () => context.push('/baby'),
        onPreconsult: (intake) => context.go(
          '/',
          extra: {'agentPrefill': '我已完成咨询的信息采集，希望继续梳理这次咨询重点。'},
        ),
      );
    },
  ),
  GoRoute(
    path: '/me/diary',
    builder: (context, state) {
      final runtime = MomCozyRuntimeScope.of(context);
      final section = DiarySection.values
          .where((value) => value.name == state.uri.queryParameters['section'])
          .firstOrNull;
      return MotherDiaryPage(
        key: ValueKey(
          'mother-diary-${runtime.currentSession.userId}-${(section ?? DiarySection.rest).name}',
        ),
        repository: MotherDiaryApiRepository(transport: runtime.jsonTransport),
        date: LocalDate.fromDateTime(runtime.now().toLocal()),
        section: section ?? DiarySection.rest,
        onClose: () => _back(context),
      );
    },
  ),
  GoRoute(
    path: '/me/lactation',
    builder: (context, state) {
      final runtime = MomCozyRuntimeScope.of(context);
      return LactationPage(
        key: ValueKey('lactation-${runtime.currentSession.userId}'),
        repository: LactationApiRepository(transport: runtime.jsonTransport),
        ownerUserId: runtime.currentSession.userId,
        date: LocalDate.fromDateTime(runtime.now().toLocal()),
        now: runtime.now,
        create: state.uri.queryParameters['create'] == '1',
        onClose: () => _back(context),
      );
    },
  ),
  GoRoute(
    path: '/services',
    builder: (context, state) => ServiceCatalogPage(
      repository: CareApiRepository(
        transport: MomCozyRuntimeScope.of(context).jsonTransport,
      ),
      onBack: () => _back(context),
      onSelect: (package) => context.push('/services/${package.id}'),
    ),
  ),
  GoRoute(
    path: '/services/episodes/:episodeId',
    builder: (context, state) {
      final runtime = MomCozyRuntimeScope.of(context);
      return ServiceProgressPage(
        repository: CareApiRepository(transport: runtime.jsonTransport),
        appointmentRepository: AppointmentApiRepository(
          transport: runtime.jsonTransport,
        ),
        episodeId: state.pathParameters['episodeId']!,
        onBack: () => _back(context),
        onBook: (episode) =>
            context.push('/services/episodes/${episode.id}/booking'),
        onRenew: () => context.push(
          '/services/episodes/${state.pathParameters['episodeId']!}/renew',
        ),
        onOpenAppointment: (appointment) => context.push(
          appointment.status == AppointmentStatus.completed
              ? '/services/appointments/${appointment.id}/summary'
              : '/services/appointments/${appointment.id}/room',
        ),
      );
    },
  ),
  GoRoute(
    path: '/services/renew',
    builder: (context, state) => _renewPage(context, state),
  ),
  GoRoute(
    path: '/services/episodes/:episodeId/renew',
    builder: (context, state) => _renewPage(context, state),
  ),
  GoRoute(
    path: '/services/:packageId',
    builder: (context, state) => ServicePackagePage(
      repository: CareApiRepository(
        transport: MomCozyRuntimeScope.of(context).jsonTransport,
      ),
      packageId: state.pathParameters['packageId']!,
      onBack: () => _back(context),
      onBook: (episode) =>
          context.push('/services/episodes/${episode.id}/booking'),
      onProgress: (episode) => context.push('/services/episodes/${episode.id}'),
    ),
  ),
];

Widget _renewPage(BuildContext context, GoRouterState state) =>
    ServiceRenewPage(
      repository: CareApiRepository(
        transport: MomCozyRuntimeScope.of(context).jsonTransport,
      ),
      episodeId: state.pathParameters['episodeId'],
      onBack: () => _back(context),
      onBook: (episode) =>
          context.push('/services/episodes/${episode.id}/booking'),
      onProgress: (episode) => context.push('/services/episodes/${episode.id}'),
    );
