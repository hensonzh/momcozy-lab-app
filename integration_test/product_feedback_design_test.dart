import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/shared/widgets/product_feedback.dart';

// Component rendering and callbacks only. Record values are in-memory fixtures;
// saving/deleting records and permission/provider requests never run here.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android shared feedback at 1x and 2x',
    (tester) async {
      var retries = 0;
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
