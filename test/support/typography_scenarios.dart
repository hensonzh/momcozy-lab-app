import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/shared/widgets/confirm_discard.dart';

Future<void> verifyTypography(
  WidgetTester tester, {
  required double scale,
  required Future<void> Function(String) capture,
}) async {
  final draft = TextEditingController(text: 'Daily notes');
  bool? discard;
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
      home: Builder(
        builder: (context) {
          final text = Theme.of(context).textTheme;
          return Scaffold(
            appBar: AppBar(title: const Text('Account')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Welcome back', style: text.headlineMedium),
                  const SizedBox(height: 16),
                  Text('Daily care', style: text.headlineSmall),
                  const SizedBox(height: 16),
                  Text('Care plan', style: text.titleLarge),
                  const SizedBox(height: 16),
                  Text('Today\'s notes', style: text.titleMedium),
                  const SizedBox(height: 16),
                  TextField(
                    controller: draft,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async =>
                        discard = await confirmDiscard(context),
                    child: const Text('Close draft'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  await capture('headings');
  final field = find.byType(TextField);
  await tester.ensureVisible(field);
  await tester.enterText(field, 'Keep this draft');
  await tester.ensureVisible(find.text('Close draft'));
  await tester.pumpAndSettle();
  await capture('form');
  await tester.tap(find.text('Close draft'));
  await tester.pumpAndSettle();
  await capture('confirm');
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(discard, false);
  expect(draft.text, 'Keep this draft');
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  draft.dispose();
}
