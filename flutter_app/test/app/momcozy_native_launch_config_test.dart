import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';

void main() {
  test(
    'app display name is Momcozy Lab across Flutter and Android flavors',
    () {
      final appSource = File('lib/app/momcozy_app.dart').readAsStringSync();
      expect(appSource, contains("title: 'Momcozy Lab'"));

      for (final path in [
        'android/app/src/main/res/values/strings.xml',
        'android/app/src/local/res/values/strings.xml',
        'android/app/src/staging/res/values/strings.xml',
        'android/app/src/production/res/values/strings.xml',
      ]) {
        final strings = File(path).readAsStringSync();
        expect(
          strings,
          contains('<string name="app_name">Momcozy Lab</string>'),
          reason: path,
        );
      }
    },
  );

  test('Android main activity uses a neutral starting window', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:theme="@style/NormalTheme"'));
    expect(manifest, isNot(contains('@style/LaunchTheme')));

    for (final path in [
      'android/app/src/main/res/values/styles.xml',
      'android/app/src/main/res/values-night/styles.xml',
    ]) {
      final styles = File(path).readAsStringSync();
      expect(styles, isNot(contains('LaunchTheme')), reason: path);
      expect(styles, isNot(contains('launch_background')), reason: path);
      expect(styles, isNot(contains('Theme.SplashScreen')), reason: path);
    }

    expect(
      File(
        'android/app/src/main/res/drawable/launch_background.xml',
      ).existsSync(),
      isFalse,
    );
    expect(
      File(
        'android/app/src/main/res/drawable-v21/launch_background.xml',
      ).existsSync(),
      isFalse,
    );

    final android12Styles = File(
      'android/app/src/main/res/values-v31/styles.xml',
    ).readAsStringSync();
    expect(android12Styles, isNot(contains('LaunchTheme')));
    expect(android12Styles, isNot(contains('Theme.SplashScreen')));
    expect(android12Styles, contains('android:windowSplashScreenBackground'));
    expect(
      android12Styles,
      contains(
        'android:windowSplashScreenAnimatedIcon">@drawable/transparent_splash_icon',
      ),
    );
    expect(
      File(
        'android/app/src/main/res/drawable/transparent_splash_icon.xml',
      ).existsSync(),
      isTrue,
    );
  });

  test('app logo assets stay byte-aligned with the legacy web app', () {
    expect(
      File(MomCozyAssets.momcozyLogo).readAsBytesSync(),
      orderedEquals(
        File('../legacy_web/src/assets/momcozy_logo.png').readAsBytesSync(),
      ),
    );

    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      for (final name in [
        'ic_launcher.png',
        'ic_launcher_foreground.png',
        'ic_launcher_round.png',
      ]) {
        final relativePath = 'res/mipmap-$density/$name';
        expect(
          File('android/app/src/main/$relativePath').readAsBytesSync(),
          orderedEquals(
            File(
              '../legacy_web/android/app/src/main/$relativePath',
            ).readAsBytesSync(),
          ),
          reason: relativePath,
        );
      }
    }
  });
}
