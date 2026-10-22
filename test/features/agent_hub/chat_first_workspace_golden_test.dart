@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/chat_first_workspace.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/chat_first_onboarding.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('compact room keeps the real-date board and figure at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = MomCozyApiRuntime(
        jsonTransport: FixtureApiJsonTransportByPath(const {
          '/v1/profile/me': {'preferred_name': null},
          '/v1/babies': {'items': <Object>[]},
          '/v1/profile/lactation': {'actual_delivery_date': '2026-10-12'},
        }),
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'workspace-visual-owner',
          babyId: '',
          locale: 'zh-CN',
          accessToken: 'test-token',
        ),
        now: () => DateTime.utc(2026, 10, 16, 4),
        timezoneProvider: () async => 'Asia/Shanghai',
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: momCozyTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: Column(
                  children: [
                    RepaintBoundary(
                      key: const ValueKey('chat-first-workspace-golden'),
                      child: ChatFirstWorkspace(
                        runtime: runtime,
                        role: FamilyRole.mother,
                        onOpenDrawer: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/chat_first/momcozy-ai-room.png'),
          tester.element(find.byType(ChatFirstWorkspace)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('宝宝出生 4 天'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-first-daily-advice')), findsOneWidget);
      final workspace = tester.getRect(
        find.byKey(const ValueKey('chat-first-workspace')),
      );
      final figure = tester.getRect(
        find.byKey(const ValueKey('chat-first-figure-scene')),
      );
      final board = tester.getRect(
        find.byKey(const ValueKey('chat-first-board-crop')),
      );
      final greet = tester.getRect(
        find.byKey(const ValueKey('chat-first-avatar-greet')),
      );
      expect(workspace.height, (width * .49).clamp(174.0, 184.0));
      expect(figure.left - workspace.left, closeTo(width * .23, .1));
      expect(figure.width, closeTo(width * .8, .1));
      expect(board.width, closeTo(width * .64, .1));
      expect(greet.left - workspace.left, closeTo(width * .68, .1));
      expect(greet.height, greaterThanOrEqualTo(44));
      expect(find.byTooltip('语音播放暂不可用'), findsOneWidget);
      final voiceIcon = find.byIcon(Icons.volume_off_outlined);
      expect(voiceIcon, findsOneWidget);
      final voiceButton = find.ancestor(
        of: voiceIcon,
        matching: find.byType(IconButton),
      );
      expect(tester.widget<IconButton>(voiceButton).onPressed, isNull);
      await expectLater(
        find.byKey(const ValueKey('chat-first-workspace-golden')),
        matchesGoldenFile(
          '../../goldens/chat_first/workspace-${width.toInt()}.png',
        ),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
