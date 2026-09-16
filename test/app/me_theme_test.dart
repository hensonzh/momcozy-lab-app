import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

void main() {
  test('workbench retains its existing typography', () {
    final theme = momCozyTheme(isWorkbench: true);
    expect(theme.textTheme.headlineMedium?.fontSize, 26);
    expect(theme.textTheme.headlineMedium?.fontFamily, 'DMSans');
    expect(theme.textTheme.headlineMedium?.height, 1.43);
    expect(theme.appBarTheme.titleTextStyle?.fontSize, 22);
    expect(theme.dialogTheme.titleTextStyle?.fontSize, 22);
  });
  test(
    'all native control families inherit the current Me visual language',
    () {
      final theme = momCozyTheme();
      expect(theme.colorScheme.error, MomCozyColors.danger);
      expect(theme.appBarTheme.backgroundColor, MomCozyColors.background);
      expect(theme.appBarTheme.titleTextStyle?.fontSize, 21);
      expect(theme.textTheme.headlineMedium?.fontSize, 28);
      expect(theme.textTheme.headlineMedium?.fontFamily, 'Manrope');
      expect(theme.textTheme.headlineMedium?.height, 1.1);
      expect(theme.textTheme.headlineSmall?.fontSize, 21);
      expect(theme.textTheme.headlineSmall?.height, 1.2);
      expect(theme.textTheme.titleLarge?.fontSize, 18);
      expect(theme.textTheme.titleLarge?.height, 1.2);
      expect(theme.textTheme.titleMedium?.fontSize, 16);
      expect(theme.textTheme.titleMedium?.fontFamily, 'DMSans');
      expect(theme.textTheme.titleMedium?.fontWeight, FontWeight.w600);
      expect(theme.textTheme.bodyMedium?.fontFamily, 'DMSans');
      expect(theme.dialogTheme.backgroundColor, MomCozyColors.background);
      expect(theme.bottomSheetTheme.backgroundColor, MomCozyColors.background);
      expect(theme.snackBarTheme.backgroundColor, MomCozyColors.foreground);
      expect(
        theme.filledButtonTheme.style!.minimumSize!.resolve({})!.height,
        greaterThanOrEqualTo(MomCozyTapTargets.minimum),
      );
      expect(
        theme.outlinedButtonTheme.style!.minimumSize!.resolve({})!.height,
        greaterThanOrEqualTo(MomCozyTapTargets.minimum),
      );
      expect(theme.inputDecorationTheme.errorBorder, isA<OutlineInputBorder>());
      expect(theme.chipTheme.selectedColor, MomCozyColors.roseSoft);
    },
  );

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'Me-themed form remains usable at $width with large text and keyboard',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final text = TextEditingController();
        addTearDown(text.dispose);
        var saves = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: momCozyTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                viewInsets: const EdgeInsets.only(bottom: 280),
                padding: const EdgeInsets.only(top: 44, bottom: 34),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '今天的记录 · Daily notes',
                        style: momCozyTheme().textTheme.headlineMedium,
                      ),
                      TextFormField(
                        controller: text,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: '补充感受 / Your notes',
                          helperText: '保留这次填写的内容',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => saves++,
                        child: const Text('保存这次记录 / Save this entry'),
                      ),
                      const OutlinedButton(
                        onPressed: null,
                        child: Text('暂不可用 / Unavailable'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.enterText(
          find.byType(TextFormField),
          'A longer note · 保留原内容',
        );
        await tester.ensureVisible(find.byType(FilledButton));
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        expect(saves, 1);
        expect(text.text, 'A longer note · 保留原内容');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
