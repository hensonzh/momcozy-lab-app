import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadMomCozyTestFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final quicksand = FontLoader('Quicksand')
    ..addFont(rootBundle.load('assets/fonts/Quicksand-VF.ttf'));
  final notoSansSc = FontLoader('NotoSansSC')
    ..addFont(rootBundle.load('assets/fonts/NotoSansCJKsc-Regular.otf'));
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  final cupertinoIcons = FontLoader('CupertinoIcons')
    ..addFont(
      rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
    );

  await Future.wait([
    quicksand.load(),
    notoSansSc.load(),
    materialIcons.load(),
    cupertinoIcons.load(),
  ]);
}
