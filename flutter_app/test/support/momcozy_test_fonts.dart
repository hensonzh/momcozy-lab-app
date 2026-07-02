import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadMomCozyTestFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final quicksand = FontLoader('Quicksand')
    ..addFont(rootBundle.load('assets/fonts/Quicksand-VF.ttf'));
  final notoSansSc = FontLoader('NotoSansSC')
    ..addFont(rootBundle.load('assets/fonts/NotoSansCJKsc-Regular.otf'));

  await Future.wait([quicksand.load(), notoSansSc.load()]);
}
