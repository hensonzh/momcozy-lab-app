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
    (FontLoader('NotoSansSCHome')
          ..addFont(rootBundle.load('assets/fonts/NotoSansCJKsc-Regular.otf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSansCJKsc-Bold.otf')))
        .load(),
    (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load(),
    (FontLoader('LibreCaslonDisplay')..addFont(
          rootBundle.load('assets/fonts/LibreCaslonDisplay-Regular.ttf'),
        ))
        .load(),
    (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load(),
    (FontLoader(
      'DMSans',
    )..addFont(rootBundle.load('assets/fonts/DMSans.ttf'))).load(),
    figtree.load(),
    rubik.load(),
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
