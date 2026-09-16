import '../../modules/ibclc/schedule/application/calendar_controller.dart';
import '../../modules/ibclc/schedule/presentation/calendar_page.dart';
import '../../modules/ibclc/reminders/application/reminders_controller.dart';
import '../../modules/ibclc/reminders/presentation/reminders_page.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../domain/ibclc/workbench.dart';
import '../../domain/ibclc/workbench_followup.dart';
import '../../domain/shared/local_date.dart';
import '../../modules/ibclc/followup/application/followups_controller.dart';
import '../../modules/ibclc/followup/presentation/followups_page.dart';
import '../../modules/ibclc/reports/application/report_controller.dart';
import '../../modules/ibclc/reports/presentation/report_page.dart';
import '../../services/reports/reports_api_repository.dart';
import '../../domain/care/clinical_note.dart';
import '../../modules/consultation/application/room_controller.dart';
import '../../modules/consultation/presentation/room_page.dart';
import '../../modules/ibclc/appointments/application/appointment_presentation.dart';
import '../../modules/ibclc/appointments/application/appointments_controller.dart';
import '../../modules/ibclc/appointments/presentation/appointments_page.dart';
import '../../modules/ibclc/appointments/presentation/intake_review_page.dart';
import '../../modules/ibclc/auth/presentation/workbench_login_page.dart';
import '../../modules/ibclc/documentation/application/documentation_controller.dart';
import '../../modules/ibclc/documentation/presentation/documentation_page.dart';
import '../../modules/ibclc/users/application/clients_controller.dart';
import '../../modules/ibclc/users/presentation/clients_page.dart';
import '../../services/consultations/intake_api_repository.dart';
import '../../services/consultations/livekit_consultation_media.dart';
import '../../services/consultations/room_api_repository.dart';
import '../../services/documentation/documentation_api_repository.dart';
import '../../shared/design_system/momcozy_theme.dart';
import '../../shared/widgets/product_feedback.dart';
import 'workbench_runtime.dart';
import 'workbench_shell.dart';

class MomCozyWorkbenchApp extends StatefulWidget {
  const MomCozyWorkbenchApp({
    super.key,
    required this.runtime,
    this.initialLocation,
  });
  final WorkbenchRuntime runtime;
  final String? initialLocation;
  @override
  State<MomCozyWorkbenchApp> createState() => _MomCozyWorkbenchAppState();
}

class _MomCozyWorkbenchAppState extends State<MomCozyWorkbenchApp> {
  late final WorkbenchRuntime runtime = widget.runtime;
  late final GoRouter router;
  late final bool _previousUrlReflection;
  static const destinations = [
    WorkbenchDestination(
      '/ibclc/appointments',
      '今日预约',
      Icons.event_available_outlined,
    ),
    WorkbenchDestination('/ibclc/followups', '今日跟进', Icons.fact_check_outlined),
    WorkbenchDestination(
      '/ibclc/calendar',
      '我的日程',
      Icons.calendar_month_outlined,
    ),
    WorkbenchDestination(
      '/ibclc/clients',
      '我的客户',
      Icons.people_outline_rounded,
    ),
    WorkbenchDestination(
      '/ibclc/reminders',
      '工作提醒',
      Icons.notifications_none_rounded,
    ),
  ];
  @override
  void initState() {
    super.initState();
    // Every workbench route reloads its data by URL identifiers and needs no
    // in-memory extras, so a pushed page is a valid standalone deep link.
    _previousUrlReflection = GoRouter.optionURLReflectsImperativeAPIs;
    GoRouter.optionURLReflectsImperativeAPIs = true;
    router = GoRouter(
      initialLocation: widget.initialLocation,
      refreshListenable: runtime.auth,
      redirect: (context, state) {
        final login = state.uri.path == '/ibclc/login';
        if (!runtime.auth.authenticated) {
          if (login) return null;
          return Uri(
            path: '/ibclc/login',
            queryParameters: {'next': state.uri.toString()},
          ).toString();
        }
        if (login) return _next(state.uri.queryParameters['next']);
        if (state.uri.path == '/' || state.uri.path == '/ibclc') {
          return '/ibclc/appointments';
        }
        return null;
      },
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: ProductEmptyView(
            title: '没有找到这个页面',
            action: FilledButton(
              onPressed: () => context.go('/ibclc/appointments'),
              child: const Text('返回工作台'),
            ),
          ),
        ),
      ),
      routes: [
        GoRoute(path: '/', redirect: (_, _) => '/ibclc/appointments'),
        GoRoute(path: '/ibclc', redirect: (_, _) => '/ibclc/appointments'),
        GoRoute(
          path: '/ibclc/login',
          builder: (_, _) => WorkbenchLoginPage(controller: runtime.auth),
        ),
        // The room and editors own their back/unsaved-change flow and use the
        // full workspace. List navigation cannot discard a clinical draft.
        GoRoute(
          path: '/ibclc/appointments/:appointmentId/room',
          builder: (context, state) {
            final id = state.pathParameters['appointmentId']!;
            return ConsultationRoomPage(
              key: ValueKey('room-${runtime.auth.generation}-$id'),
              createController: () => ConsultationRoomController(
                repository: ConsultationRoomApiRepository(
                  transport: runtime.transport,
                ),
                consents: IntakeApiRepository(transport: runtime.transport),
                appointmentId: id,
                media: LiveKitConsultationMedia(),
              ),
              onBack: () => _back(context),
              onIntake: () async {
                await context.push('/ibclc/appointments/$id/intake');
              },
              onProgress: (_) =>
                  context.pushReplacement('/ibclc/appointments/$id/note'),
              onRebook: (_) => context.go('/ibclc/appointments'),
            );
          },
        ),
        GoRoute(
          path: '/ibclc/appointments/:appointmentId/:document(note|plan)',
          builder: (context, state) {
            final id = state.pathParameters['appointmentId']!;
            return DocumentationPage(
              key: ValueKey('documentation-${runtime.auth.generation}-$id'),
              createController: () => DocumentationController(
                repository: DocumentationApiRepository(
                  transport: runtime.transport,
                ),
                appointmentId: id,
              ),
              initialTab: state.pathParameters['document'] == 'plan'
                  ? DocumentationTab.plan
                  : DocumentationTab.note,
              onBack: () => _back(context),
            );
          },
        ),
        ShellRoute(
          builder: (context, state, child) {
            final identity = runtime.auth.identity;
            if (identity == null) {
              return WorkbenchLoginPage(controller: runtime.auth);
            }
            return WorkbenchShell(
              key: ValueKey(runtime.auth.generation),
              identity: identity,
              destinations: destinations,
              location: state.uri.path,
              onNavigate: context.go,
              onLogout: () => unawaited(runtime.auth.logout()),
              child: child,
            );
          },
          routes: [
            GoRoute(
              path: '/ibclc/followups',
              builder: (context, state) => WorkbenchFollowupsPage(
                key: ValueKey('followups-${runtime.auth.generation}'),
                createController: () => WorkbenchFollowupsController(
                  runtime.repository,
                  query: state.uri.queryParameters['q'] ?? '',
                  filter:
                      WorkbenchFollowupFilter.values
                          .where(
                            (value) =>
                                value.name ==
                                state.uri.queryParameters['status'],
                          )
                          .firstOrNull ??
                      WorkbenchFollowupFilter.all,
                ),
                onFilters: (query, filter) => context.replace(
                  Uri(
                    path: '/ibclc/followups',
                    queryParameters: {
                      if (query.isNotEmpty) 'q': query,
                      if (filter != WorkbenchFollowupFilter.all)
                        'status': filter.name,
                    },
                  ).toString(),
                ),
                onOpen: (id) async {
                  await context.push('/ibclc/followups/$id');
                },
              ),
            ),
            GoRoute(
              path: '/ibclc/followups/:patientRef',
              builder: (context, state) {
                final id = state.pathParameters['patientRef']!;
                return WorkbenchReportPage(
                  key: ValueKey(
                    'report-${runtime.auth.generation}-$id-${state.uri.queryParameters['episode']}-${state.uri.queryParameters['date']}',
                  ),
                  createController: () => WorkbenchReportController(
                    clients: runtime.repository,
                    reports: CareReportsApiRepository(
                      transport: runtime.transport,
                    ),
                    patientRef: id,
                    episodeId: state.uri.queryParameters['episode'],
                    date: _reportDate(state.uri.queryParameters['date']),
                  ),
                  onBack: () => _back(context, fallback: '/ibclc/followups'),
                  onClient: () => context.push('/ibclc/clients/$id'),
                  onSelection: (episode, date) => context.replace(
                    Uri(
                      path: '/ibclc/followups/$id',
                      queryParameters: {
                        'episode': episode,
                        if (date != null) 'date': date.toString(),
                      },
                    ).toString(),
                  ),
                );
              },
            ),
            GoRoute(
              path: '/ibclc/reminders',
              builder: (context, state) => WorkbenchRemindersPage(
                key: ValueKey('reminders-${runtime.auth.generation}'),
                createController: () =>
                    WorkbenchRemindersController(runtime.repository),
                timezone: runtime.auth.identity!.provider.timezone,
                onOpen: (route) async {
                  await context.push(route);
                },
              ),
            ),
            GoRoute(
              path: '/ibclc/appointments',
              builder: (context, state) => WorkbenchAppointmentsPage(
                key: ValueKey('appointments-${runtime.auth.generation}'),
                createController: () =>
                    WorkbenchAppointmentsController(runtime.repository),
                onOpen: (item, action) => _open(context, item, action),
                onClient: (id) async {
                  await context.push('/ibclc/clients/$id');
                },
              ),
            ),
            GoRoute(
              path: '/ibclc/calendar',
              builder: (context, state) => WorkbenchCalendarPage(
                key: ValueKey('calendar-${runtime.auth.generation}'),
                createController: () =>
                    WorkbenchCalendarController(runtime.repository),
                onOpen: (item, action) => _open(context, item, action),
                onClient: (id) async {
                  await context.push('/ibclc/clients/$id');
                },
              ),
            ),
            GoRoute(
              path: '/ibclc/clients',
              builder: (context, state) => WorkbenchClientsPage(
                key: ValueKey('clients-${runtime.auth.generation}'),
                createController: () =>
                    WorkbenchClientsController(runtime.repository),
                onClient: (id) async {
                  await context.push('/ibclc/clients/$id');
                },
              ),
            ),
            GoRoute(
              path: '/ibclc/clients/:patientRef',
              builder: (context, state) {
                final id = state.pathParameters['patientRef']!;
                return WorkbenchClientPage(
                  key: ValueKey('client-${runtime.auth.generation}-$id'),
                  createController: () =>
                      WorkbenchClientController(runtime.repository, id),
                  timezone: runtime.auth.identity!.provider.timezone,
                  onBack: () => _back(context, fallback: '/ibclc/clients'),
                  onReport: (episodeId) => context.push(
                    Uri(
                      path: '/ibclc/followups/$id',
                      queryParameters: {'episode': episodeId},
                    ).toString(),
                  ),
                  onOpen: (item, action) => _open(context, item, action),
                );
              },
            ),
            GoRoute(
              path: '/ibclc/appointments/:appointmentId/intake',
              builder: (context, state) {
                final id = state.pathParameters['appointmentId']!;
                return IntakeReviewPage(
                  key: ValueKey('intake-${runtime.auth.generation}-$id'),
                  repository: runtime.repository,
                  appointmentId: id,
                  onBack: () => _back(context),
                  onRoom: () => context.push('/ibclc/appointments/$id/room'),
                );
              },
            ),
          ],
        ),
      ],
    );
    unawaited(runtime.auth.restore());
  }

  Future<void> _open(
    BuildContext context,
    WorkbenchAppointment item,
    WorkbenchAppointmentAction action,
  ) async {
    final page = switch (action) {
      WorkbenchAppointmentAction.prepare => 'intake',
      WorkbenchAppointmentAction.room => 'room',
      WorkbenchAppointmentAction.note =>
        item.noteStatus == ClinicalNoteStatus.signed &&
                item.publishedRevision == 0
            ? 'plan'
            : 'note',
    };
    await context.push('/ibclc/appointments/${item.appointment.id}/$page');
  }

  void _back(BuildContext context, {String fallback = '/ibclc/appointments'}) =>
      context.canPop() ? context.pop() : context.go(fallback);
  LocalDate? _reportDate(String? value) {
    if (value == null) return null;
    try {
      return LocalDate.parse(value);
    } on FormatException {
      return null;
    }
  }

  String _next(String? next) {
    final uri = next == null ? null : Uri.tryParse(next);
    if (uri == null ||
        uri.hasAuthority ||
        uri.hasScheme ||
        !uri.path.startsWith('/ibclc/') ||
        uri.path == '/ibclc/login') {
      return '/ibclc/appointments';
    }
    return uri.toString();
  }

  @override
  void dispose() {
    router.dispose();
    GoRouter.optionURLReflectsImperativeAPIs = _previousUrlReflection;
    runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Momcozy · IBCLC 工作台',
    debugShowCheckedModeBanner: false,
    theme: momCozyTheme(isWorkbench: true),
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: router,
  );
}
