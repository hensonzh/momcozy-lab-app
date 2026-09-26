import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/data/onboarding_api_repository.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_page.dart';
import 'package:momcozy_flutter_app/shared/widgets/product_feedback.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  testWidgets('onboarding uses shared loading and retry states', (
    tester,
  ) async {
    final transport = _DelayedOnboardingTransport({
      onboardingMeEndpoint: {
        'http_status': 503,
        'body': {
          'error': {'code': 'unavailable', 'message': 'Try again shortly.'},
        },
      },
    });
    final runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'retry-user',
          babyId: '',
          locale: 'en-US',
          accessToken: 'access',
        ),
      ),
    );
    final controller = OnboardingController(runtimeController: runtime);
    addTearDown(controller.dispose);
    addTearDown(runtime.dispose);

    await tester.pumpWidget(
      MaterialApp(home: OnboardingPage(controller: controller)),
    );
    expect(find.byType(ProductLoadingView), findsOneWidget);
    expect(find.text('Preparing your setup'), findsNothing);

    transport.releaseFirstLoad.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ProductErrorView), findsOneWidget);
    expect(
      find.text('Could not load right now. Please try again later.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text("We couldn't load your setup"), findsNothing);

    transport.responsesByPath[onboardingMeEndpoint] = {
      'status': 'required',
      'profile_confirmed': false,
    };
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(transport.getPaths, [onboardingMeEndpoint, onboardingMeEndpoint]);
    expect(find.text('A few basics first'), findsOneWidget);
    expect(find.byType(ProductErrorView), findsNothing);
  });
}

class _DelayedOnboardingTransport extends FixtureApiJsonTransportByPath {
  _DelayedOnboardingTransport(super.responsesByPath);

  final Completer<void> releaseFirstLoad = Completer<void>();
  bool _firstLoad = true;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (_firstLoad) {
      _firstLoad = false;
      await releaseFirstLoad.future;
    }
    return super.getJson(path, query: query);
  }
}
