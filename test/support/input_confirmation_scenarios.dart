import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/shared/widgets/choice_field.dart';
import 'package:momcozy_flutter_app/shared/widgets/confirm_discard.dart';
import 'package:momcozy_flutter_app/shared/widgets/zoned_datetime_field.dart';

enum InputChoice { baby, sleep, unsure }

// Shared component fixture: no repositories, network, or persistent record writes.
Future<void> verifyInputConfirmation(
  WidgetTester tester, {
  required double scale,
  bool reducedMotion = false,
  required Future<void> Function(String) capture,
}) async {
  final body = ValueNotifier<Widget>(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      theme: momCozyTheme(),
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'US'),
      supportedLocales: const [Locale('en', 'US')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reducedMotion,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SafeArea(
          child: ValueListenableBuilder<Widget>(
            valueListenable: body,
            builder: (_, child, _) => child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  Future<void> click(String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump();
    final timePicker = find.byKey(const ValueKey('momcozy-time-picker'));
    if (reducedMotion && timePicker.evaluate().isNotEmpty) {
      expect(ModalRoute.of(tester.element(timePicker))!.animation!.value, 1);
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  for (final style in ChoiceFieldStyle.values) {
    var selected = <InputChoice>{InputChoice.baby};
    body.value = StatefulBuilder(
      builder: (_, update) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ChoiceField<InputChoice>(
          title: 'What matters to you',
          hint: 'Select all that apply',
          style: style,
          options: const {
            InputChoice.baby: 'Baby',
            InputChoice.sleep: 'Rest',
            InputChoice.unsure: 'Not sure',
          },
          selected: selected,
          multiple: true,
          exclusiveValue: InputChoice.unsure,
          onChanged: (next) => update(() => selected = next),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await click('Rest');
    expect(selected, {InputChoice.baby, InputChoice.sleep});
    await capture('choices-${style.name}');
    await click('Not sure');
    expect(selected, {InputChoice.unsure});
    await click('Not sure');
    expect(selected, isEmpty);
  }

  var changes = 0;
  DateTime? value = DateTime.utc(2026, 9, 12, 2, 30);
  final original = value;
  var enabled = false;
  late StateSetter setField;
  body.value = StatefulBuilder(
    builder: (_, update) {
      setField = update;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ZonedDateTimeField(
          label: 'Record time',
          value: value,
          timezone: 'Asia/Shanghai',
          now: () => DateTime.utc(2026, 9, 12, 6),
          warm: true,
          enabled: enabled,
          clearable: true,
          onChanged: (next) {
            changes++;
            update(() => value = next);
          },
        ),
      );
    },
  );
  await tester.pumpAndSettle();
  expect(
    tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
    isNull,
  );
  expect(
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Clear time'))
        .onPressed,
    isNull,
  );
  setField(() => enabled = true);
  await tester.pumpAndSettle();
  Future<void> openDate() async {
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    await tester.pump();
    if (reducedMotion) {
      expect(
        ModalRoute.of(
          tester.element(find.byType(DatePickerDialog)),
        )!.animation!.value,
        1,
      );
    }
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(
      tester
          .widget<DatePickerDialog>(find.byType(DatePickerDialog))
          .currentDate,
      DateTime(2026, 9, 12),
    );
    expect(tester.takeException(), isNull);
  }

  await openDate();
  await capture('date');
  if (scale == 2) {
    await tester.enterText(find.byType(TextFormField), 'not a date');
    await click('OK');
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(changes, 0);
    final strings = MaterialLocalizations.of(
      tester.element(find.byType(DatePickerDialog)),
    );
    expect(find.text(strings.invalidDateFormatLabel), findsOneWidget);
  }
  await click('Cancel');
  expect(changes, 0);
  expect(value, original);
  await openDate();
  await click('OK');
  expect(find.byKey(const ValueKey('momcozy-time-picker')), findsOneWidget);
  expect(
    Localizations.localeOf(
      tester.element(find.byKey(const ValueKey('momcozy-time-picker'))),
    ),
    const Locale('en', 'US'),
  );
  expect(find.text('上午'), findsNothing);
  await capture('time');
  if (scale == 2) {
    await tester.enterText(find.byType(TextFormField).first, '25');
    await click('OK');
    expect(find.byKey(const ValueKey('momcozy-time-picker')), findsOneWidget);
    expect(changes, 0);
    await capture('time-invalid');
    // On short screens above a keyboard, the second field must remain reachable.
    final minute = find.byType(TextFormField).last;
    await tester.ensureVisible(minute);
    await tester.pumpAndSettle();
    await tester.tap(minute);
    await tester.enterText(minute, '31');
    await tester.pumpAndSettle();
    await capture('time-minute');
  }
  await click('Cancel');
  expect(changes, 0);
  expect(value, original);
  await openDate();
  await click('OK');
  await click('OK');
  expect(changes, 1);
  expect(value, original);
  await click('Clear time');
  expect(value, isNull);
  expect(changes, 2);
  expect(find.text('Not set'), findsOneWidget);

  final draft = TextEditingController(text: 'I would like to rest today.');
  var results = <bool>[];
  var uncertain = false;
  body.value = Builder(
    builder: (context) => SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: draft,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              results.add(
                await confirmDiscard(
                  context,
                  uncertainSave: uncertain,
                  confirmLabel: 'Discard changes',
                ),
              );
            },
            child: const Text('Close record'),
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  await click('Close record');
  await tester.ensureVisible(find.text('Your unsaved changes will be lost.'));
  await tester.pumpAndSettle();
  await capture('confirm');
  await click('Keep editing');
  expect(results, [false]);
  expect(draft.text, 'I would like to rest today.');
  await click('Close record');
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(results, [false, false]);
  expect(draft.text, 'I would like to rest today.');
  uncertain = true;
  await click('Close record');
  expect(
    find.text(
      'Your save has not been confirmed. Refresh your records before trying again to avoid duplicates.',
    ),
    findsOneWidget,
  );
  await capture('uncertain');
  await click('Discard changes');
  expect(results, [false, false, true]);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  draft.dispose();
  body.dispose();
}
