import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_saved_feedback.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/shared/widgets/product_feedback.dart';

// Component rendering and callbacks only. Record values are in-memory fixtures;
// saving/deleting records and permission/provider requests never run here.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android shared feedback at 1x and 2x',
    (tester) async {
      var retries = 0, undos = 0, dismissals = 0;
      for (final scale in [1.0, 2.0]) {
        final body = ValueNotifier<Widget>(
          const ProductLoadingView(label: '正在载入记录'),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: momCozyTheme(),
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              appBar: AppBar(title: const Text('记录')),
              body: SafeArea(
                child: ValueListenableBuilder<Widget>(
                  valueListenable: body,
                  builder: (_, child, _) => child,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        if (scale == 1) await binding.convertFlutterSurfaceToImage();
        await tester.pump();
        await _capture(binding, 'native-feedback-loading-${scale.toInt()}x');
        body.value = ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ProductErrorView(
              failure: const ProductFailure(ProductFailureKind.offline),
              preserveDraft: true,
              onRetry: () => retries++,
            ),
            const ProductErrorView(
              failure: ProductFailure(ProductFailureKind.conflict),
              preserveDraft: true,
            ),
          ],
        );
        await tester.pumpAndSettle();
        await _capture(binding, 'native-feedback-error-${scale.toInt()}x');
        await tester.tap(find.text('重试'));
        expect(retries, scale.toInt());
        body.value = const SingleChildScrollView(
          child: ProductEmptyView(
            textAlign: TextAlign.start,
            title: '还没有记录',
            description: '记录会显示在这里。',
          ),
        );
        await tester.pumpAndSettle();
        await _capture(binding, 'native-feedback-empty-${scale.toInt()}x');
        final feedback = BabySavedFeedback([
          BabyFeedingRecord(
            id: 'fixture-record',
            babyId: 'fixture-baby',
            version: 1,
            occurredAt: DateTime.utc(2026, 9, 12),
            method: BabyFeedingMethod.expressedMilk,
            volumeMl: 60,
          ),
        ], allowUndo: true);
        Widget saved() => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BabySavedFeedbackView(
              feedback: feedback,
              onUndo: () {
                undos++;
                feedback.undone = true;
                body.value = saved();
              },
              onDismiss: () {
                dismissals++;
                body.value = const SizedBox();
              },
              onHistory: () {},
            ),
          ],
        );
        body.value = saved();
        await tester.pumpAndSettle();
        await _capture(binding, 'native-feedback-saved-${scale.toInt()}x');
        await tester.tap(find.text('撤销'));
        await tester.pumpAndSettle();
        expect(undos, scale.toInt());
        expect(find.text('撤销'), findsNothing);
        expect(find.text('已撤销这次记录。'), findsOneWidget);
        await _capture(binding, 'native-feedback-undone-${scale.toInt()}x');
        await tester.tap(find.byTooltip('关闭保存提示'));
        await tester.pumpAndSettle();
        expect(dismissals, scale.toInt());
        expect(find.byType(BabySavedFeedbackView), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        body.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  final bytes = await binding.takeScreenshot(name);
  final directory = await getApplicationDocumentsDirectory();
  await File('${directory.path}/$name.png').writeAsBytes(bytes);
}
