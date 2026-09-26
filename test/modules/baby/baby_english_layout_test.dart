import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_profile_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_home_page.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_profile_editor.dart';

import 'baby_test_repositories.dart';

void main() {
  testWidgets('switcher fits long English names at 320px and 2x', (
    tester,
  ) async {
    const currentName = 'Luna Catherine Chen With A Long Display Name';
    const secondName = 'Alexander Benjamin Taylor With A Long Name';
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final profiles = BabyTestProfiles()
      ..values = [
        BabyProfile(
          id: 'current',
          name: currentName,
          birthDate: babyTestProfile.birthDate,
          sex: babyTestProfile.sex,
        ),
        BabyProfile(
          id: 'second',
          name: secondName,
          birthDate: babyTestProfile.birthDate,
          sex: babyTestProfile.sex,
        ),
      ];
    final home = BabyHomeController(
      profileRepository: profiles,
      recordRepository: BabyTestRecords(),
      timezoneProvider: () async => 'America/Los_Angeles',
      now: () => babyTestNow,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BabyHomePage(controller: home, onAsk: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(currentName));
    await tester.pumpAndSettle();

    final selectedName = find.text('$currentName  · Current');
    expect(selectedName, findsOneWidget);
    final selectedParagraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: selectedName, matching: find.byType(RichText)),
    );
    expect(selectedParagraph.didExceedMaxLines, isFalse);
    expect(
      selectedParagraph.size.height,
      greaterThanOrEqualTo(
        selectedParagraph.getMaxIntrinsicHeight(selectedParagraph.size.width) -
            1,
      ),
    );
    final otherName = find.text(secondName);
    expect(otherName, findsOneWidget);
    await tester.ensureVisible(otherName);
    final otherParagraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: otherName, matching: find.byType(RichText)),
    );
    expect(otherParagraph.didExceedMaxLines, isFalse);
    expect(
      otherParagraph.size.height,
      greaterThanOrEqualTo(
        otherParagraph.getMaxIntrinsicHeight(otherParagraph.size.width) - 1,
      ),
    );
    await tester.tap(otherName);
    await tester.pumpAndSettle();
    expect(find.text(secondName), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long baby names remain readable at 320px and 2x', (
    tester,
  ) async {
    const name = 'Luna Catherine Chen With A Long Display Name';
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final profile = BabyProfile(
      id: babyTestProfile.id,
      name: name,
      birthDate: babyTestProfile.birthDate,
      sex: babyTestProfile.sex,
    );
    final profiles = BabyTestProfiles()..values = [profile];
    final home = BabyHomeController(
      profileRepository: profiles,
      recordRepository: BabyTestRecords(),
      timezoneProvider: () async => 'America/Los_Angeles',
      now: () => babyTestNow,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BabyHomePage(controller: home, onAsk: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nameFinder = find.text(name);
    expect(nameFinder, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: nameFinder, matching: find.byType(RichText)),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);

    final editor = BabyProfileController(
      repository: profiles,
      timezone: 'America/Los_Angeles',
      now: () => babyTestNow,
      initial: profile,
    );
    addTearDown(editor.dispose);
    await tester.pumpWidget(
      MaterialApp(home: BabyProfileEditor(controller: editor)),
    );
    await tester.pumpAndSettle();
    final title = find.text('Baby profile');
    final titleParagraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: title, matching: find.byType(RichText)),
    );
    expect(titleParagraph.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });
}
