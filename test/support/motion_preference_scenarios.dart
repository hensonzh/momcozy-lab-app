import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

Future<void> verifyMotionPreference(
  WidgetTester tester, {
  required double scale,
  required Future<void> Function(String) capture,
}) async {
  final scroll = ScrollController();
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
          child: Builder(
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
                  child: const Text('Review your answers'),
                ),
                Expanded(
                  child: ListView(
                    controller: scroll,
                    children: const [
                      SizedBox(height: 1200, child: Text('Your setup')),
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Your answers will still be here if saving fails.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Review your answers'));
  await tester.pumpAndSettle();
  expect(scroll.offset, scroll.position.maxScrollExtent);
  expect(scroll.position.isScrollingNotifier.value, isFalse);
  await capture('feedback');
  await tester.pumpWidget(const SizedBox());
  scroll.dispose();
}
