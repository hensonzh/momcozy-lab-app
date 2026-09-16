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
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
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
          title: '关注的事情',
          hint: '可多选',
          style: style,
          options: const {
            InputChoice.baby: '宝宝',
            InputChoice.sleep: '休息',
            InputChoice.unsure: '说不清楚',
          },
          selected: selected,
          multiple: true,
          exclusiveValue: InputChoice.unsure,
          onChanged: (next) => update(() => selected = next),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await click('休息');
    expect(selected, {InputChoice.baby, InputChoice.sleep});
    await capture('choices-${style.name}');
    await click('说不清楚');
    expect(selected, {InputChoice.unsure});
    await click('说不清楚');
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
          label: '记录时间',
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
        .widget<TextButton>(find.widgetWithText(TextButton, '清除时间'))
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
    await click('确定');
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(changes, 0);
    final strings = MaterialLocalizations.of(
      tester.element(find.byType(DatePickerDialog)),
    );
    expect(find.text(strings.invalidDateFormatLabel), findsOneWidget);
  }
  await click('取消');
  expect(changes, 0);
  expect(value, original);
  await openDate();
  await click('确定');
  expect(find.byKey(const ValueKey('momcozy-time-picker')), findsOneWidget);
  expect(find.text('上午'), findsNothing);
  expect(find.text('下午'), findsNothing);
  await capture('time');
  if (scale == 2) {
    await tester.enterText(find.byType(TextFormField).first, '25');
    await click('确定');
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
  await click('取消');
  expect(changes, 0);
  expect(value, original);
  await openDate();
  await click('确定');
  await click('确定');
  expect(changes, 1);
  expect(value, original);
  await click('清除时间');
  expect(value, isNull);
  expect(changes, 2);
  expect(find.text('尚未填写'), findsOneWidget);

  final draft = TextEditingController(text: '今天想先休息一下');
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
            decoration: const InputDecoration(labelText: '备注'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              results.add(
                await confirmDiscard(
                  context,
                  uncertainSave: uncertain,
                  confirmLabel: '放弃修改',
                ),
              );
            },
            child: const Text('关闭记录'),
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  await click('关闭记录');
  await tester.ensureVisible(find.text('还未保存的修改会被放弃。'));
  await tester.pumpAndSettle();
  await capture('confirm');
  await click('继续填写');
  expect(results, [false]);
  expect(draft.text, '今天想先休息一下');
  await click('关闭记录');
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(results, [false, false]);
  expect(draft.text, '今天想先休息一下');
  uncertain = true;
  await click('关闭记录');
  expect(find.text('保存结果还未确认。返回后请先刷新记录，避免重复填写。'), findsOneWidget);
  await capture('uncertain');
  await click('放弃修改');
  expect(results, [false, false, true]);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  draft.dispose();
  body.dispose();
}
