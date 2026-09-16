import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/shared/widgets/date_time_picker.dart';
import 'package:momcozy_flutter_app/shared/widgets/zoned_datetime_field.dart';

void main() {
  testWidgets('large 12-hour picker preserves midnight and noon', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TimeOfDay? value;
    await tester.pumpWidget(
      MaterialApp(
        theme: momCozyTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => value = await showMomCozyTimePicker(
                context: context,
                initialTime: const TimeOfDay(hour: 0, minute: 15),
              ),
              child: const Text('Time'),
            ),
          ),
        ),
      ),
    );
    for (final period in ['AM', 'PM']) {
      await tester.tap(find.text('Time'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '12',
      );
      await tester.ensureVisible(find.text(period));
      await tester.pumpAndSettle();
      await tester.tap(find.text(period));
      await tester.ensureVisible(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(value, TimeOfDay(hour: period == 'AM' ? 0 : 12, minute: 15));
      expect(tester.takeException(), isNull);
    }
  });
  for (final locale in [const Locale('en', 'US'), const Locale('zh', 'CN')]) {
    testWidgets('large picker bounds, locale and time validation $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      DateTime? date;
      TimeOfDay? time;
      await tester.pumpWidget(
        MaterialApp(
          theme: momCozyTheme().copyWith(
            datePickerTheme: DatePickerThemeData(locale: locale),
          ),
          supportedLocales: const [Locale('en', 'US'), Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () async => date = await showMomCozyDatePicker(
                      context: context,
                      initialDate: DateTime(2026, 9, 12),
                      firstDate: DateTime(2026, 9, 1),
                      lastDate: DateTime(2026, 9, 30),
                    ),
                    child: const Text('Date'),
                  ),
                  TextButton(
                    onPressed: () async => time = await showMomCozyTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 14, minute: 15),
                      builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(alwaysUse24HourFormat: true),
                        child: child!,
                      ),
                    ),
                    child: const Text('Time'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDatePicker), findsNothing);
      final strings = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      );
      final dateInput = find.byType(TextFormField);
      await tester.enterText(
        dateInput,
        strings.formatCompactDate(DateTime(2026, 10, 1)),
      );
      await tester.tap(find.text(strings.okButtonLabel));
      await tester.pumpAndSettle();
      expect(find.text(strings.dateOutOfRangeLabel), findsOneWidget);
      expect(date, isNull);
      await tester.enterText(
        dateInput,
        strings.formatCompactDate(DateTime(2026, 9, 30)),
      );
      await tester.tap(find.text(strings.okButtonLabel));
      await tester.pumpAndSettle();
      expect(date, DateTime(2026, 9, 30));
      await tester.tap(find.text('Time'));
      await tester.pumpAndSettle();
      final timeInputs = find.byType(TextFormField);
      expect(timeInputs, findsNWidgets(2));
      await tester.enterText(timeInputs.first, '25');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('momcozy-time-picker')), findsOneWidget);
      expect(time, isNull);
      await tester.enterText(timeInputs.first, '23');
      await tester.enterText(timeInputs.last, '45');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(time, const TimeOfDay(hour: 23, minute: 45));
      await tester.tap(find.text('Time'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(time, isNull);
      expect(tester.takeException(), isNull);
    });
  }
  for (final momStyle in [false, true]) {
    testWidgets(
      'date and time dialogs settle without elapsed motion mom=$momStyle',
      (tester) async {
        DateTime? selected;
        final value = DateTime.utc(2026, 9, 12, 6, 15);
        await tester.pumpWidget(
          MaterialApp(
            theme: momCozyTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: ZonedDateTimeField(
                useMomStyle: momStyle,
                label: 'Record time',
                value: value,
                timezone: 'Asia/Shanghai',
                now: () => value,
                onChanged: (next) => selected = next,
              ),
            ),
          ),
        );
        await tester.tap(
          momStyle ? find.byType(OutlinedButton) : find.byType(ListTile),
        );
        await tester.pump();
        await tester.pump();
        expect(
          ModalRoute.of(
            tester.element(find.byType(DatePickerDialog)),
          )!.animation!.value,
          1,
        );
        await tester.tap(find.text('OK'));
        await tester.pump();
        await tester.pump();
        expect(
          ModalRoute.of(
            tester.element(find.byKey(const ValueKey('momcozy-time-picker'))),
          )!.animation!.value,
          1,
        );
        await tester.tap(find.text('OK'));
        await tester.pump();
        await tester.pump();
        expect(selected, value);
      },
    );
  }
}
