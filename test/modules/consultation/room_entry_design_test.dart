import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/care/consultation_room.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/consultation/presentation/room_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'room_test_support.dart';

class _Rooms extends TestRoomRepository {
  Completer<ConsultationRoomContext> response = Completer();
  int loads = 0;
  @override
  Future<ConsultationRoomContext> load(String id) {
    loads++;
    return response.future;
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Rooms repo,
  TestConsultationMedia media, {
  required bool home,
  double width = 390,
  double scale = 1,
  double height = 844,
  VoidCallback? onBack,
}) async {
  await loadMomCozyTestFonts();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: momCozyTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFFFBF8F4))),
          ConsultationRoomPage(
            overHome: home,
            createController: () => testController(repo, media),
            onBack: onBack ?? () {},
            onIntake: () async {},
            onProgress: (_) {},
            onRebook: (_) {},
          ),
        ],
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> _shot(
  WidgetTester tester,
  String state,
  bool home,
  double width,
  double scale, {
  bool short = false,
}) async {
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(
      '../../goldens/design_system/room-entry-${home ? 'modal' : 'page'}-$state-${width.toInt()}${scale == 2 ? '-2x' : ''}${short ? '-short' : ''}.png',
    ),
  );
}

void main() {
  for (final home in [false, true]) {
    for (final width in [320.0, 390.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'entry loads, retries one request and recovers $home/$width/$scale',
          (tester) async {
            final repo = _Rooms();
            final media = TestConsultationMedia();
            await _mount(
              tester,
              repo,
              media,
              home: home,
              width: width,
              scale: scale,
            );
            expect(find.text('正在读取咨询信息'), findsOneWidget);
            expect(repo.loads, 1);
            await _shot(tester, 'loading', home, width, scale);
            repo.response.completeError(
              const ProductFailure(ProductFailureKind.unavailable),
            );
            await tester.pumpAndSettle();
            expect(find.text('暂时无法载入，请稍后重试'), findsOneWidget);
            await _shot(tester, 'error', home, width, scale);
            repo.response = Completer();
            await tester.ensureVisible(find.text('重试'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('重试'));
            await tester.pump(const Duration(milliseconds: 20));
            expect(find.text('正在读取咨询信息'), findsOneWidget);
            expect(find.text('重试'), findsNothing);
            expect(repo.loads, 2);
            expect(repo.prepareCalls, 0);
            expect(repo.keys, isEmpty);
            expect(media.connectCalls, 0);
            repo.response.complete(repo.context);
            await tester.pumpAndSettle();
            expect(find.text('开始前准备'), findsOneWidget);
            expect(find.text('预约详情'), findsOneWidget);
            expect(find.text('正在读取咨询信息'), findsNothing);
            expect(repo.loads, 2);
            expect(media.connectCalls, 0);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
    testWidgets(
      'short large entry closes while loading and ignores late response $home',
      (tester) async {
        final repo = _Rooms();
        final media = TestConsultationMedia();
        var backs = 0;
        await _mount(
          tester,
          repo,
          media,
          home: home,
          width: 320,
          scale: 2,
          height: 568,
          onBack: () => backs++,
        );
        await _shot(tester, 'loading', home, 320, 2, short: true);
        await tester.tap(find.byTooltip(home ? '关闭预约详情' : '返回'));
        await tester.pump(const Duration(milliseconds: 50));
        expect(backs, 1);
        expect(media.disconnectCalls, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        repo.response.complete(repo.context);
        await tester.pump();
        expect(media.connectCalls, 0);
        expect(repo.prepareCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'short large offline error remains retryable and closable $home',
      (tester) async {
        final repo = _Rooms();
        var backs = 0;
        await _mount(
          tester,
          repo,
          TestConsultationMedia(),
          home: home,
          width: 320,
          scale: 2,
          height: 568,
          onBack: () => backs++,
        );
        repo.response.completeError(
          const ProductFailure(ProductFailureKind.offline),
        );
        await tester.pumpAndSettle();
        expect(find.text('网络未连接，请连接后重试'), findsOneWidget);
        await tester.ensureVisible(find.text('重试'));
        await tester.pumpAndSettle();
        await _shot(tester, 'offline', home, 320, 2, short: true);
        await tester.tap(find.byTooltip(home ? '关闭预约详情' : '返回'));
        await tester.pumpAndSettle();
        expect(backs, 1);
      },
    );
  }
}
