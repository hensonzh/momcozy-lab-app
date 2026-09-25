import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/shared/widgets/choice_field.dart';

enum _Choice { baby, sleep, unsure }

void main() {
  for (final style in ChoiceFieldStyle.values) {
    testWidgets('exclusive selection and toggling work with ${style.name}', (
      tester,
    ) async {
      var selected = <_Choice>{};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => ChoiceField(
                title: '关注的事情',
                style: style,
                options: const {
                  _Choice.baby: 'Baby',
                  _Choice.sleep: '休息',
                  _Choice.unsure: 'Not sure',
                },
                selected: selected,
                multiple: true,
                exclusiveValue: _Choice.unsure,
                onChanged: (next) => update(() => selected = next),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Baby'));
      await tester.pump();
      await tester.tap(find.text('休息'));
      await tester.pump();
      expect(selected, {_Choice.baby, _Choice.sleep});
      await tester.tap(find.text('Not sure'));
      await tester.pump();
      expect(selected, {_Choice.unsure});
      await tester.tap(find.text('Baby'));
      await tester.pump();
      expect(selected, {_Choice.baby});
      await tester.tap(find.text('Baby'));
      await tester.pump();
      expect(selected, isEmpty);
    });
  }
}
