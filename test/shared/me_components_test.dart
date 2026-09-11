import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/shared/widgets/momcozy_components.dart';
import 'package:momcozy_flutter_app/shared/widgets/product_feedback.dart';
import '../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('shared Me surfaces and controls at $width / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var presses = 0;
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
            home: Scaffold(
              body: MomCozyPageBody(
                child: ListView(
                  padding: MomCozyInsets.page,
                  children: [
                    const MomCozyPageHeader(
                      title: '今天的记录',
                      subtitle: 'Daily care, one step at a time',
                    ),
                    const SizedBox(height: MomCozySpacing.section),
                    MomCozySectionHeading(
                      title: '我的状态',
                      icon: Icons.favorite_border_rounded,
                      action: TextButton(
                        onPressed: () => presses++,
                        child: const Text('查看全部'),
                      ),
                    ),
                    const MomCozySurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('日常记录与服务进度', style: MomCozyTypography.title),
                          SizedBox(height: MomCozySpacing.compact),
                          Text('记录自己的感受，按原有流程保存和查看。'),
                          SizedBox(height: MomCozySpacing.content),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              MomCozyBadge(
                                '已保存',
                                color: MomCozyColors.care,
                                background: MomCozyColors.careSoft,
                              ),
                              MomCozyBadge(
                                '待确认',
                                color: MomCozyColors.amber,
                                background: MomCozyColors.amberSoft,
                              ),
                              MomCozyBadge('暂不可用'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: MomCozySpacing.section),
                    const TextField(
                      decoration: InputDecoration(
                        labelText: '补充感受',
                        hintText: '选填',
                      ),
                    ),
                    const SizedBox(height: MomCozySpacing.content),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('有恢复'),
                          selected: true,
                          onSelected: (_) {},
                        ),
                        ChoiceChip(
                          label: const Text('勉强能撑'),
                          selected: false,
                          onSelected: (_) {},
                        ),
                      ],
                    ),
                    const SizedBox(height: MomCozySpacing.section),
                    MomCozyPrimaryButton(
                      onPressed: () => presses++,
                      child: const Text('保存这次记录'),
                    ),
                    const SizedBox(height: MomCozySpacing.compact),
                    OutlinedButton(
                      onPressed: () => presses++,
                      child: const Text('返回查看'),
                    ),
                    const SizedBox(height: MomCozySpacing.compact),
                    const MomCozyPrimaryButton(
                      onPressed: null,
                      child: Text('暂不可用'),
                    ),
                    const SizedBox(height: MomCozySpacing.section),
                    const ProductEmptyView(
                      title: '还没有更多记录',
                      description: '已填写内容会继续保留。',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../goldens/design_system/components-${width.toInt()}.png',
            ),
          );
        }
        await tester.ensureVisible(find.byType(MomCozyPrimaryButton).first);
        await tester.tap(find.byType(MomCozyPrimaryButton).first);
        await tester.pump();
        expect(presses, 1);
        await tester.ensureVisible(find.text('暂不可用').last);
        await tester.tap(find.text('暂不可用').last);
        expect(presses, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'shared primary loading state preserves label and prevents duplicate action',
    (tester) async {
      var presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: momCozyTheme(),
          home: Scaffold(
            body: MomCozyPrimaryButton(
              loading: true,
              onPressed: () => presses++,
              child: const Text('保存中'),
            ),
          ),
        ),
      );
      expect(find.text('保存中'), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      expect(presses, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'long dialog and keyboard sheet remain scrollable and dismissible',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: momCozyTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 280),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        scrollable: true,
                        title: const Text('查看完整说明'),
                        content: Text(List.filled(12, '这是一段较长的说明文字。').join()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('关闭说明'),
                          ),
                        ],
                      ),
                    ),
                    child: const Text('打开说明'),
                  ),
                  TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (context) => FractionallySizedBox(
                        heightFactor: .85,
                        child: Padding(
                          padding: MediaQuery.viewInsetsOf(context),
                          child: SingleChildScrollView(
                            padding: MomCozyInsets.dialog,
                            child: Column(
                              children: [
                                const Text(
                                  '补充记录',
                                  style: MomCozyTypography.heading,
                                ),
                                const TextField(
                                  decoration: InputDecoration(
                                    labelText: '记录内容',
                                  ),
                                ),
                                Text(List.filled(6, '已填写内容保持不变。').join()),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('关闭记录'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('打开记录'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开说明'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('关闭说明'));
      await tester.tap(find.text('关闭说明'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开记录'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '保留记录');
      await tester.ensureVisible(find.text('关闭记录'));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('关闭记录'));
      await tester.pumpAndSettle();
      expect(find.text('补充记录'), findsNothing);
    },
  );
}
