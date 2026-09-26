import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/account_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

Map<String, Object?> _profile() => {
  'email': 'mia.catherine.chen.with.a.long.email@example.test',
  'email_verified': false,
  'account_status': 'deletion_pending',
  'auth_providers': ['email'],
};

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final size in [(393.0, 1.0), (320.0, 2.0)]) {
    final suffix = '${size.$1.toInt()}-${size.$2.toInt()}x';

    Future<void> mount(WidgetTester tester, _Transport transport) async {
      tester.view.physicalSize = Size(size.$1, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = MomCozyRuntimeController(
        MomCozyApiRuntime(jsonTransport: transport),
      );
      addTearDown(runtime.dispose);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: momCozyTheme(),
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Previous page')),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(size.$2)),
            child: child!,
          ),
          onGenerateInitialRoutes: (_) => [
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Previous page')),
            ),
            MaterialPageRoute<void>(
              builder: (_) => MomCozyAccountPage(
                runtimeController: runtime,
                sessionStore: MemoryMomCozySessionStore(),
              ),
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
    }

    Future<void> capture(WidgetTester tester, String state) async {
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/ui_refactor/account-$state-$suffix.png',
        ),
      );
    }

    Future<void> tap(WidgetTester tester, Finder target) async {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('account loading, retry and long identity $suffix', (
      tester,
    ) async {
      final transport = _Transport(_profile())..readGate = Completer<void>();
      await mount(tester, transport);
      expect(find.text('Loading account…'), findsOneWidget);
      await capture(tester, 'loading');
      transport.response.addAll({
        'http_status': 503,
        'body': {
          'error': {'code': 'unavailable'},
        },
      });
      transport.readGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Account unavailable'), findsOneWidget);
      await capture(tester, 'load-error');
      transport.response
        ..clear()
        ..addAll(_profile());
      await tap(tester, find.text('Retry'));
      expect(find.text('Deletion requested'), findsOneWidget);
      await capture(tester, 'long-identity');
      expect(find.byKey(const ValueKey('account-delete')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('account-sign-out')),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'long-bottom');
      await tap(tester, find.byTooltip('Back'));
      expect(find.text('Previous page'), findsOneWidget);
      expect(transport.mutationPaths, isEmpty);
    });

    testWidgets('legacy account recovery guidance $suffix', (tester) async {
      final transport = _Transport(
        _profile()..addAll({
          'auth_providers': ['google'],
          'account_status': 'active',
          'email_verified': true,
        }),
      );
      await mount(tester, transport);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('This account has no email password'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('account-link-google')), findsNothing);
      await capture(tester, 'legacy-password-recovery');
    });

    testWidgets('account disabled and missing providers $suffix', (
      tester,
    ) async {
      final transport = _Transport(
        _profile()..addAll({
          'email': null,
          'account_status': 'disabled',
          'auth_providers': <String>[],
        }),
      );
      await mount(tester, transport);
      await tester.pumpAndSettle();
      expect(find.text('Internal test account'), findsOneWidget);
      expect(find.text('Disabled'), findsOneWidget);
      expect(find.byKey(const ValueKey('account-link-google')), findsNothing);
      await capture(tester, 'no-providers');
    });
  }
}

class _Transport extends FixtureApiJsonTransport {
  _Transport(super.response);
  Completer<void>? readGate;
  Completer<void>? writeGate;
  bool deleteFails = false;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    await readGate?.future;
    readGate = null;
    return super.getJson(path, query: query);
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    await writeGate?.future;
    writeGate = null;
    return super.postJson(path, body: body, headers: headers);
  }

  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    final result = await super.deleteJson(path, headers: headers);
    if (deleteFails) {
      throw const ApiHttpException(
        statusCode: 503,
        statusText: 'Service unavailable',
        body: {
          'error': {'code': 'unavailable'},
        },
      );
    }
    return result;
  }
}
