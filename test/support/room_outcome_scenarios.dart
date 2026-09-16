import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/modules/consultation/presentation/room_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../modules/consultation/room_test_support.dart';

Future<void> verifyRoomOutcomes(
  WidgetTester tester, {
  required Map<String, Object?> fixture,
  required double scale,
  required Future<void> Function(String) capture,
}) async {
  for (final technical in [false, true]) {
    final repository =
        TestRoomRepository(
            fixture: Map<String, Object?>.from(
              jsonDecode(jsonEncode(fixture)) as Map,
            ),
          )
          ..ready()
          ..room(
            status: technical ? 'failed' : 'no_show',
            roomStatus: 'closed',
          );
    (repository.json['consultation'] as Map)['end_reason'] = technical
        ? 'technical_failure'
        : 'user_no_show';
    final media = TestConsultationMedia();
    var rebook = 0, home = 0, summary = 0, back = 0;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: momCozyTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: ConsultationRoomPage(
          key: ValueKey(technical),
          createController: () => testController(repository, media),
          onBack: () => back++,
          onHome: () => home++,
          onIntake: () async {},
          onProgress: (_) => summary++,
          onRebook: (appointment) {
            expect(appointment.id, repository.context.appointment.id);
            expect(
              appointment.episodeId,
              repository.context.appointment.episodeId,
            );
            rebook++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(technical ? '视频连接未能继续' : '这次咨询未能开始'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '重新预约'), findsOneWidget);
    expect(find.text('查看咨询总结'), findsNothing);
    expect(find.textContaining('本次未扣减咨询次数'), findsOneWidget);
    await capture(technical ? 'technical-failure' : 'no-show');
    await tester.ensureVisible(find.text('重新预约'));
    await tester.tap(find.text('重新预约'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('返回妈妈主页'));
    await tester.tap(find.text('返回妈妈主页'));
    await tester.pumpAndSettle();
    expect(rebook, 1);
    expect(home, 1);
    expect(back, 0);
    expect(summary, 0);
    expect(repository.endCalls, 0);
    expect(repository.keys, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }
}
