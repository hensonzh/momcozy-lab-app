import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadMomCozyTestFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final figtree = FontLoader('Figtree')
    ..addFont(rootBundle.load('assets/fonts/Figtree-VF.ttf'));
  final rubik = FontLoader('Rubik')
    ..addFont(rootBundle.load('assets/fonts/Rubik-VF.ttf'));
  final quicksand = FontLoader('Quicksand')
    ..addFont(rootBundle.load('assets/fonts/Quicksand-VF.ttf'));
  final notoSansSc = FontLoader('NotoSansSC')
    ..addFont(rootBundle.load('assets/fonts/NotoSansCJKsc-Regular.otf'));
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));

  await Future.wait([
    figtree.load(),
    rubik.load(),
    quicksand.load(),
    notoSansSc.load(),
    materialIcons.load(),
  ]);
}
