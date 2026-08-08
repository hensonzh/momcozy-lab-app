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

  await Future.wait([
    quicksand.load(),
    notoSansSc.load(),
    materialIcons.load(),
  ]);
}

Future<void> loadMomCozyPlanTestFonts() async {
  await loadMomCozyTestFonts();

  final rubik = FontLoader('Rubik')
    ..addFont(rootBundle.load('assets/fonts/Rubik-Bold.ttf'));
  final figtree = FontLoader('Figtree')
    ..addFont(rootBundle.load('assets/fonts/Figtree-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Figtree-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Figtree-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Figtree-Bold.ttf'));

  await Future.wait([rubik.load(), figtree.load()]);
}
