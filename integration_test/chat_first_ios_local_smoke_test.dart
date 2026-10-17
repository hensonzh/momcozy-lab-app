import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:momcozy_flutter_app/core/auth/flutter_secure_momcozy_session_store.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_profile_editor.dart';

import 'package:momcozy_flutter_app/main.dart' as app_entry;

const _email = String.fromEnvironment('MOMCOZY_IOS_SMOKE_EMAIL');
const _password = String.fromEnvironment('MOMCOZY_IOS_SMOKE_PASSWORD');
const _role = String.fromEnvironment(
  'MOMCOZY_IOS_SMOKE_ROLE',
  defaultValue: 'father',
);
const _babyRecords = bool.fromEnvironment('MOMCOZY_IOS_SMOKE_BABY_RECORDS');
const _savedStatus = bool.fromEnvironment('MOMCOZY_IOS_SMOKE_SAVED_STATUS');
const _statusInApp = bool.fromEnvironment('MOMCOZY_IOS_SMOKE_STATUS_IN_APP');
const _hasSavedStatus = _savedStatus || _statusInApp;

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder,
  String description,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.byKey(const ValueKey('startup-error')).evaluate().isNotEmpty) {
      fail('$description blocked by an app startup error');
    }
  }
  expect(finder, findsWidgets, reason: '$description did not become visible');
}

Future<void> _waitUntilAbsent(
  WidgetTester tester,
  Finder finder,
  String description,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (finder.evaluate().isNotEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(finder, findsNothing, reason: '$description did not finish');
}

Future<void> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  await tester.pump(const Duration(milliseconds: 350));
  final bytes = await binding.takeScreenshot(name);
  expect(bytes, isNotEmpty);
  final directory = await getApplicationDocumentsDirectory();
  await File('${directory.path}/$name.png').writeAsBytes(bytes);
}

Future<void> _completeMotherFlow(WidgetTester tester) async {
  await _tap(tester, 'role-mother');
  await _waitFor(
    tester,
    find.byKey(const ValueKey('stage-postpartum')),
    'mother stage',
  );
  await _tap(tester, 'stage-postpartum');
  await _waitFor(tester, find.byKey(const ValueKey('age-30')), 'mother age');
  await _tap(tester, 'age-30');
  await _tap(tester, 'delivery-count-2');
  await _tap(tester, 'setup-continue');
  await _waitFor(
    tester,
    find.byKey(const ValueKey('delivery-date')),
    'mother delivery',
  );
  await _tap(tester, 'delivery-date');
  await _waitFor(tester, find.byType(DatePickerDialog), 'delivery date picker');
  // The date picker opens on the simulator's current date. Confirm that
  // explicit choice instead of injecting a profile or a fixed sample date.
  final today = DateTime.now();
  await tester.tap(
    find.text('OK').evaluate().isNotEmpty ? find.text('OK') : find.text('确定'),
  );
  await tester.pump(const Duration(milliseconds: 200));
  final directory = await getApplicationDocumentsDirectory();
  await File(
    '${directory.path}/ios-chat-first-delivery-date.txt',
  ).writeAsString(
    '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
  );
  await _tap(tester, 'weeks-39');
  await _tap(tester, 'baby-count-1');
  await _tap(tester, 'setup-continue');
  await _waitFor(
    tester,
    find.byKey(const ValueKey('concern-milk-supply')),
    'mother concerns',
  );
  await _tap(tester, 'concern-milk-supply');
  await _tap(tester, 'setup-continue');
  await _waitFor(
    tester,
    find.byKey(const ValueKey('recommend-record')),
    'recommended services',
  );
  await _tap(tester, 'enter-home');
}

Future<void> _openRecord(WidgetTester tester, String kind) async {
  await _tap(tester, 'chat-first-action-record');
  final picker = find.byKey(const ValueKey('chat-first-record-picker'));
  await _waitFor(tester, picker, 'record type picker');
  final target = find.byKey(ValueKey('record-type-$kind'));
  if (target.evaluate().isEmpty) {
    final strip = find.descendant(of: picker, matching: find.byType(ListView));
    await tester.drag(strip, const Offset(-500, 0));
    await tester.pump(const Duration(milliseconds: 250));
  }
  await _tap(tester, 'record-type-$kind');
  await _waitFor(
    tester,
    find.byKey(const ValueKey('chat-first-record-sheet')),
    '$kind record sheet',
  );
}

Future<void> _checkMotherRecords(WidgetTester tester) async {
  await _tap(tester, 'section-back-chat');
  await _waitFor(
    tester,
    find.byKey(const ValueKey('chat-first-action-record')),
    'record shortcut',
  );
  for (final kind in const [
    'nursing',
    'formula',
    'expressed',
    'pumping',
    'growth',
  ]) {
    await _openRecord(tester, kind);
    switch (kind) {
      case 'nursing':
        await _tap(tester, 'record-side-left');
        await tester.enterText(
          find.byKey(const ValueKey('record-duration')),
          '12',
        );
      case 'formula':
        await tester.enterText(
          find.byKey(const ValueKey('record-volume')),
          '60',
        );
      case 'expressed':
        await tester.enterText(
          find.byKey(const ValueKey('record-volume')),
          '75',
        );
      case 'pumping':
        await tester.enterText(
          find.byKey(const ValueKey('record-volume')),
          '45',
        );
      case 'growth':
        await tester.enterText(
          find.byKey(const ValueKey('record-weight')),
          '3.4',
        );
        await tester.enterText(
          find.byKey(const ValueKey('record-height')),
          '50.5',
        );
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await _tap(tester, 'record-save');
    await _waitUntilAbsent(
      tester,
      find.byKey(const ValueKey('chat-first-record-sheet')),
      '$kind backend save',
    );
  }
  for (final kind in const ['diaper', 'sleep']) {
    await _openRecord(tester, kind);
    expect(find.byKey(const ValueKey('record-save')), findsNothing);
    expect(find.byKey(const ValueKey('record-create-baby')), findsOneWidget);
    await _tap(tester, 'record-close');
    await _waitUntilAbsent(
      tester,
      find.byKey(const ValueKey('chat-first-record-sheet')),
      '$kind unsaved sheet',
    );
  }
}

Future<void> _checkMotherPumpingAfterSave(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
) async {
  await _tap(tester, 'chat-first-menu');
  await _tap(tester, 'drawer-mother');
  await _waitFor(
    tester,
    find.byKey(const ValueKey('mother-pumping-refresh')),
    'mother pumping overview',
  );
  await _tap(tester, 'mother-pumping-refresh');
  await _waitFor(tester, find.text('45 ml · 1 次'), 'saved pumping total');
  await _capture(binding, tester, 'ios-chat-first-mother-pumping');
  await _tap(tester, 'mother-pumping-details');
  await _waitFor(tester, find.text('45 ml'), 'saved pumping detail');
  await _tap(tester, 'mother-pumping-close');

  await _waitFor(
    tester,
    find.text('近 7 天有 1 天保存吸奶记录'),
    'saved seven-day milk trend',
  );
  if (_statusInApp) {
    await _waitFor(
      tester,
      find.text('最近 2 天没有已保存状态记录'),
      'empty status before App write',
    );
    await _tap(tester, 'mother-status-add');
    await _waitFor(
      tester,
      find.byKey(const ValueKey('mother-status-sheet')),
      'status editor',
    );
    await _tap(tester, 'mother-status-kind-mood');
    await _tap(tester, 'mother-status-value-一般');
    await _capture(binding, tester, 'ios-chat-first-mother-status-editor');
    await _tap(tester, 'mother-status-save');
    await _waitUntilAbsent(
      tester,
      find.byKey(const ValueKey('mother-status-sheet')),
      'owner-scoped status save',
    );
    await _waitFor(
      tester,
      find.text('最近 2 天有 1 条已保存状态记录'),
      'App status backend readback',
    );
    await _capture(binding, tester, 'ios-chat-first-mother-status-saved');
  }
  await _waitFor(
    tester,
    find.text(_hasSavedStatus ? '最近 2 天有 1 条已保存状态记录' : '最近 2 天没有已保存状态记录'),
    _hasSavedStatus ? 'saved owner status' : 'fresh account status empty state',
  );
  await tester.ensureVisible(find.byKey(const ValueKey('mother-milk-trend')));
  await _capture(binding, tester, 'ios-chat-first-mother-trend');
  await _tap(tester, 'mother-milk-trend');
  await _waitFor(tester, find.text('近 7 天记录奶量'), 'seven-day trend detail');
  final today = DateTime.now();
  final sheet = find.byType(BottomSheet);
  final savedDay = find.descendant(
    of: sheet,
    matching: find.text('${today.month}月${today.day}日'),
  );
  final savedAmount = find.descendant(
    of: sheet,
    matching: find.text('45 ml · 1 次'),
  );
  expect(savedDay, findsOneWidget);
  expect(savedAmount, findsOneWidget);
  expect(
    tester.getRect(sheet).contains(tester.getCenter(savedAmount)),
    isTrue,
    reason: 'The real saved amount must be visible without scrolling.',
  );
  await _capture(binding, tester, 'ios-chat-first-mother-trend-details');
  await _tap(tester, 'mother-milk-trend-close');

  await _tap(tester, 'mother-wellbeing');
  await _waitFor(tester, find.text('最近 2 天身体与状态'), 'status detail');
  expect(find.textContaining('不推断健康状况'), findsOneWidget);
  expect(find.text('当天没有状态记录'), findsWidgets);
  if (_hasSavedStatus) {
    expect(find.text('心情'), findsOneWidget);
    expect(find.text('一般'), findsOneWidget);
  }
  await _capture(
    binding,
    tester,
    _hasSavedStatus
        ? 'ios-chat-first-mother-wellbeing-saved'
        : 'ios-chat-first-mother-wellbeing-empty',
  );
  await _tap(tester, 'mother-wellbeing-close');
  await _tap(tester, 'section-back-chat');
}

Future<void> _createBabyAndSaveCare(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
) async {
  await _tap(tester, 'chat-first-menu');
  await _tap(tester, 'drawer-baby');
  await _waitFor(tester, find.text('添加宝宝资料'), 'empty baby page');
  await tester.tap(find.text('添加宝宝资料'));
  await _waitFor(tester, find.byType(BabyProfileEditor), 'baby profile editor');
  final name = find.descendant(
    of: find.byType(BabyProfileEditor),
    matching: find.byType(TextField),
  );
  await tester.enterText(name, 'Local Test Baby');
  await tester.tap(find.text('女孩'));
  await tester.pump();
  final editor = tester.widget<BabyProfileEditor>(
    find.byType(BabyProfileEditor),
  );
  if (editor.controller.birthDate == null) {
    await tester.tap(find.text('选择出生日期'));
    await _waitFor(tester, find.byType(DatePickerDialog), 'baby birth date');
    await tester.tap(find.text('确定').last);
    await _waitUntilAbsent(tester, find.byType(DatePickerDialog), 'birth date');
  }
  expect(editor.controller.name, 'Local Test Baby');
  expect(editor.controller.birthDate, isNotNull);
  expect(editor.controller.sex.name, 'female');
  expect(editor.controller.canSave, isTrue);
  await tester.ensureVisible(find.text('保存宝宝资料'));
  await tester.tap(find.text('保存宝宝资料'));
  await _waitUntilAbsent(
    tester,
    find.byType(BabyProfileEditor),
    'baby profile editor',
  );
  await _waitFor(
    tester,
    find.textContaining('Local Test Baby'),
    'selected baby',
  );
  await _capture(binding, tester, 'ios-chat-first-baby-profile');
  await _tap(tester, 'section-back-chat');

  await _openRecord(tester, 'diaper');
  await _waitFor(
    tester,
    find.byKey(const ValueKey('record-save')),
    'verified baby',
  );
  await _tap(tester, 'record-diaper-wet');
  await _tap(tester, 'record-save');
  await _waitUntilAbsent(
    tester,
    find.byKey(const ValueKey('chat-first-record-sheet')),
    'diaper backend save',
  );

  await _openRecord(tester, 'sleep');
  await _waitFor(
    tester,
    find.byKey(const ValueKey('record-save')),
    'verified baby',
  );
  await _tap(tester, 'record-start');
  await _waitFor(tester, find.byType(DatePickerDialog), 'sleep start date');
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));
  final picker = find.byType(DatePickerDialog);
  if (yesterday.month != now.month) {
    await tester.tap(
      find.descendant(of: picker, matching: find.byTooltip('Previous month')),
    );
    await tester.pump(const Duration(milliseconds: 250));
  }
  await tester.tap(
    find.descendant(of: picker, matching: find.text('${yesterday.day}')).last,
  );
  await tester.tap(find.text('OK').last);
  await _waitFor(tester, find.byType(TimePickerDialog), 'sleep start time');
  await tester.tap(find.text('OK').last);
  await _waitUntilAbsent(tester, find.byType(TimePickerDialog), 'start time');

  await _tap(tester, 'record-end');
  await _waitFor(tester, find.byType(DatePickerDialog), 'sleep end date');
  await tester.tap(find.text('OK').last);
  await _waitFor(tester, find.byType(TimePickerDialog), 'sleep end time');
  await tester.tap(find.text('OK').last);
  await _waitUntilAbsent(tester, find.byType(TimePickerDialog), 'end time');
  await _tap(tester, 'record-save');
  await _waitUntilAbsent(
    tester,
    find.byKey(const ValueKey('chat-first-record-sheet')),
    'sleep backend save',
  );
  await _capture(binding, tester, 'ios-chat-first-baby-records');
  await _tap(tester, 'chat-first-menu');
  await _tap(tester, 'drawer-baby');
  await _waitFor(
    tester,
    find.byKey(const ValueKey('baby-full-details')),
    'baby overview',
  );
  await _tap(tester, 'baby-full-details');
  await _waitFor(
    tester,
    find.byKey(const ValueKey('chat-first-baby-details-page')),
    'real baby details',
  );
  final details = find.byKey(const ValueKey('chat-first-baby-details-page'));
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (tester.getTopLeft(details).dx.abs() < 1) break;
  }
  expect(
    tester.getTopLeft(details).dx.abs(),
    lessThan(1),
    reason: 'Do not capture a partially transitioned details page.',
  );
  await _waitUntilAbsent(tester, find.byType(SnackBar), 'previous save notice');
  await _waitFor(tester, find.text('今日湿尿布 1 次'), 'saved diaper summary');
  expect(find.text('Add your baby to get started'), findsNothing);
  await _capture(binding, tester, 'ios-chat-first-baby-details');
  await _tap(tester, 'baby-details-mood');
  await _waitFor(tester, find.text('记录喂养后状态'), 'baby mood editor');
  await tester.tap(find.text('平静满足'));
  await tester.pump(const Duration(milliseconds: 200));
  await _tap(tester, 'baby-save');
  await _waitFor(tester, find.text('平静满足'), 'saved baby mood');
  await _capture(binding, tester, 'ios-chat-first-baby-details-saved');
  await _tap(tester, 'baby-details-sleep');
  await _waitFor(tester, find.text('记录睡眠'), 'baby details sleep form');
  await _tap(tester, 'record-close');
  await _waitUntilAbsent(
    tester,
    find.byKey(const ValueKey('chat-first-record-sheet')),
    'closed baby sleep form',
  );
  final detailScroll = find.descendant(
    of: details,
    matching: find.byType(Scrollable),
  );
  tester.state<ScrollableState>(detailScroll).position.jumpTo(0);
  await tester.pump(const Duration(milliseconds: 250));
  await _waitFor(
    tester,
    find.byKey(const ValueKey('baby-details-knowledge')),
    'baby knowledge entry after returning to top',
  );
  await _tap(tester, 'baby-details-knowledge');
  await _waitFor(tester, find.text('照护知识'), 'general baby knowledge');
  await _tap(tester, 'baby-knowledge-topic-sleep');
  await _waitFor(
    tester,
    find.textContaining('每次睡眠都让宝宝仰卧'),
    'general safe-sleep guidance',
  );
  expect(find.textContaining('不依据当前宝宝的记录评估健康'), findsWidgets);
  await _capture(binding, tester, 'ios-chat-first-baby-knowledge');
  await _tap(tester, 'baby-knowledge-ask');
  await _waitUntilAbsent(tester, find.byType(BottomSheet), 'baby knowledge');
  await _waitFor(
    tester,
    find.byKey(const ValueKey('agent-composer-input')),
    'chat draft from baby knowledge',
  );
  expect(
    tester
        .widget<TextField>(find.byKey(const ValueKey('agent-composer-input')))
        .controller
        ?.text,
    '关于宝宝安全睡眠，我想了解哪些基本注意事项？',
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;

  testWidgets(
    'fresh local account signs in and renders chat-first iOS surfaces',
    (tester) async {
      // Reinstalling an iOS app does not necessarily erase its Keychain entry.
      // Only this local smoke test clears the previous simulator session.
      await const FlutterSecureMomCozySessionStore().clearSession();
      await app_entry.main();
      await _waitFor(
        tester,
        find.byKey(const ValueKey('auth-email-field')),
        'sign-in form',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-email-field')),
        _email,
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password-field')),
        _password,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-submit-button')),
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
      await _waitFor(
        tester,
        find.byKey(const ValueKey('role-father')),
        'fresh-account role selection',
      );
      await _capture(binding, tester, 'ios-chat-first-role');

      if (_role == 'mother') {
        await _completeMotherFlow(tester);
      } else {
        await _tap(tester, 'role-father');
      }
      await _waitFor(
        tester,
        find.byKey(const ValueKey('chat-first-workspace')),
        'chat-first home',
      );
      expect(find.byKey(const ValueKey('chat-first-menu')), findsOneWidget);
      await _capture(binding, tester, 'ios-chat-first-home');

      await tester.tap(find.byKey(const ValueKey('chat-first-menu')));
      await _waitFor(
        tester,
        find.byKey(const ValueKey('drawer-devices')),
        'three-destination drawer',
      );
      expect(find.byKey(const ValueKey('drawer-baby')), findsOneWidget);
      expect(find.byKey(const ValueKey('drawer-mother')), findsOneWidget);
      await _capture(binding, tester, 'ios-chat-first-drawer');
      if (_role == 'mother') {
        await _tap(tester, 'drawer-mother');
        await _waitFor(tester, find.text('30 岁'), 'saved mother profile');
        expect(find.text('Mia'), findsNothing);
        await _capture(binding, tester, 'ios-chat-first-mother-profile');
        await _checkMotherRecords(tester);
        await _capture(binding, tester, 'ios-chat-first-records');
        await _checkMotherPumpingAfterSave(binding, tester);
        if (_babyRecords) await _createBabyAndSaveCare(binding, tester);
      }
    },
    skip:
        _email.isEmpty ||
        _password.isEmpty ||
        !const {'father', 'mother'}.contains(_role) ||
        (_babyRecords && _role != 'mother'),
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
