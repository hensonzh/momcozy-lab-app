import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/avatar_task_banner.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/avatar_task_controller.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'fixture_api_transport.dart';

Future<void> verifyMotionPreference(
  WidgetTester tester, {
  required double scale,
  required Future<void> Function(String) capture,
}) async {
  final responses = {'/v1/onboarding/me': _avatarState('failed')};
  final transport = FixtureApiJsonTransportByPath(responses);
  final runtime = MomCozyRuntimeController(
    MomCozyApiRuntime(
      jsonTransport: transport,
      multipartTransport: FixtureApiMultipartTransport({}),
      session: const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'motion-fixture',
        babyId: '',
        locale: 'en-US',
        accessToken: 'fixture',
      ),
    ),
  );
  final onboarding = OnboardingController(runtimeController: runtime);
  await onboarding.load();
  final task = AvatarTaskController(onboardingController: onboarding)
    ..setForeground(false);
  final body = ValueNotifier<Widget>(const SizedBox());
  final scroll = ScrollController();
  var opened = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: momCozyTheme(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SafeArea(
          child: ValueListenableBuilder<Widget>(
            valueListenable: body,
            builder: (_, value, _) => value,
          ),
        ),
      ),
    ),
  );
  body.value = AvatarTaskBanner(controller: task, onOpen: () => opened++);
  await tester.pumpAndSettle();
  expect(find.text('We couldn’t create your companion'), findsOneWidget);
  responses['/v1/onboarding/me'] = _avatarState('review');
  await onboarding.load();
  await tester.pump();
  await tester.pump();
  expect(find.text('We couldn’t create your companion'), findsNothing);
  expect(find.text('Your 4 companion options are ready'), findsOneWidget);
  await capture('banner');
  await tester.tap(find.byKey(const ValueKey('avatar-task-banner')));
  expect(opened, 1);

  final portrait = (await rootBundle.load(
    'assets/images/me_baby_overview/postpartum_avatar.png',
  )).buffer.asUint8List();
  body.value = OnboardingPage(
    controller: onboarding,
    pickPortrait: (_) async => null,
    avatarThumbnailLoader: (_) async => portrait,
  );
  await tester.pump();
  await tester.runAsync(() async {
    await precacheImage(
      MemoryImage(portrait),
      tester.element(find.byType(OnboardingPage)),
    );
  });
  await tester.pumpAndSettle();
  final candidate = find.byKey(const ValueKey('onboarding-avatar-candidate-1'));
  await tester.ensureVisible(candidate);
  await tester.pumpAndSettle();
  await tester.tap(candidate);
  await tester.pump();
  await tester.pump();
  expect(onboarding.selectedAvatarCandidateId, 'candidate-1');
  final animated = find.descendant(
    of: candidate,
    matching: find.byType(AnimatedContainer),
  );
  final surface = tester.widget<DecoratedBox>(
    find.descendant(of: animated, matching: find.byType(DecoratedBox)).first,
  );
  expect(
    ((surface.decoration as BoxDecoration).border! as Border).top.width,
    2.5,
  );
  await capture('selected');

  body.value = Builder(
    builder: (context) => Column(
      children: [
        FilledButton(
          onPressed: () => MomCozyMotion.scrollTo(
            context,
            scroll,
            scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          ),
          child: const Text('查看填写反馈'),
        ),
        Expanded(
          child: ListView(
            controller: scroll,
            children: const [
              SizedBox(height: 1200, child: Text('记录内容')),
              Padding(padding: EdgeInsets.all(16), child: Text('这次填写的内容仍然保留。')),
            ],
          ),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('查看填写反馈'));
  await tester.pump();
  await tester.pump();
  expect(scroll.offset, scroll.position.maxScrollExtent);
  expect(scroll.position.isScrollingNotifier.value, isFalse);
  await capture('feedback');

  expect(transport.mutationPaths, isEmpty);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  scroll.dispose();
  body.dispose();
  task.dispose();
  onboarding.dispose();
  runtime.dispose();
}

Map<String, Object?> _avatarState(String status) => {
  'status': 'avatar_$status',
  'current_step': 'avatar',
  'profile_confirmed': true,
  'can_enter_app': true,
  'can_continue_with_default': true,
  'avatar': {
    'id': 'generation',
    'stage': 'postpartum',
    'status': status == 'review' ? 'succeeded' : 'failed',
    'created_at': '2026-09-12T00:00:00Z',
    'error_code': '',
    'candidates': [
      if (status == 'review')
        for (var i = 1; i <= 4; i++)
          {'id': 'candidate-$i', 'file_id': 'file-$i', 'position': i},
    ],
  },
};
