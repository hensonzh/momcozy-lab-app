import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

void main() {
  test(
    'all native control families inherit the current Me visual language',
    () {
      final theme = momCozyTheme();
      expect(theme.colorScheme.error, MomCozyColors.danger);
      expect(theme.appBarTheme.backgroundColor, MomCozyColors.background);
      expect(theme.appBarTheme.titleTextStyle?.fontSize, 22);
      expect(theme.textTheme.headlineMedium?.fontSize, 26);
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
